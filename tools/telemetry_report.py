"""Rogue Dealership play metrics -> one HTML report.

Reads the `events` table the game fills (docs/telemetry_setup.sql) and writes a
self-contained page: where players drop off, where they stall, what the rules
refuse them, how each shift and boss goes, and which cards they use.

    set SUPABASE_SERVICE_KEY=...        (Settings -> API -> service_role; never commit it)
    python tools/telemetry_report.py --since 2026-10-14 --out telemetry_report.html
    python tools/telemetry_report.py --build "#205" ...      (one build only)
    python tools/telemetry_report.py --from-json events.json ...   (no network)

Standard library only.
"""

import argparse
import collections
import datetime as dt
import html
import json
import os
import statistics
import sys
import urllib.parse
import urllib.request

PROJECT_URL = "https://tmiauedyfphaytwfbsde.supabase.co"
PAGE = 1000


# --- fetching ------------------------------------------------------------------

def fetch(since, build, key):
    rows, offset = [], 0
    while True:
        query = {"select": "*", "order": "id.asc", "limit": str(PAGE), "offset": str(offset)}
        if since:
            query["created_at"] = "gte." + since
        if build:
            query["build"] = "like." + build + "*"
        url = PROJECT_URL + "/rest/v1/events?" + urllib.parse.urlencode(query)
        req = urllib.request.Request(url, headers={"apikey": key, "Authorization": "Bearer " + key})
        with urllib.request.urlopen(req, timeout=60) as r:
            page = json.loads(r.read().decode("utf-8"))
        rows.extend(page)
        if len(page) < PAGE:
            return rows
        offset += PAGE


# --- the numbers ---------------------------------------------------------------

def pct(n, d):
    return 0.0 if not d else 100.0 * n / d


def quantile(values, q):
    if not values:
        return 0
    values = sorted(values)
    i = min(len(values) - 1, max(0, int(round(q * (len(values) - 1)))))
    return values[i]


def situation(e):
    """What a floor move was, in words a designer would group it by."""
    d = e.get("data") or {}
    cmd = d.get("cmd", "?")
    bits = [cmd]
    if d.get("demand"):
        bits.append("demand live")
    if d.get("budget_left") is not None:
        bits.append("boss")
    if cmd == "offer" and d.get("ok") is False:
        bits.append("refused")
    return " / ".join(bits)


def analyse(rows):
    out = {}
    sessions = collections.defaultdict(list)
    for r in rows:
        sessions[r["session"]].append(r)
    for evs in sessions.values():
        evs.sort(key=lambda r: r["seq"])
    out["rows"] = len(rows)
    out["sessions"] = len(sessions)
    out["installs"] = len({r["install"] for r in rows})
    out["builds"] = collections.Counter(r["build"] for r in rows).most_common(8)
    out["platforms"] = collections.Counter(
        (r.get("data") or {}).get("platform", "?") for r in rows if r["kind"] == "session_start").most_common()

    by_kind = collections.defaultdict(list)
    for r in rows:
        by_kind[r["kind"]].append(r)

    # Funnel: per install, the furthest they got.
    furthest = {}
    for r in rows:
        k, d, who = r["kind"], r.get("data") or {}, r["install"]
        f = furthest.setdefault(who, {"session": True})
        if k == "tutorial_start":
            f["tutorial started"] = True
        if k == "tutorial_end" and d.get("completed"):
            f["tutorial finished"] = True
        if k == "run_start":
            f["run started"] = True
        if k == "shift_end":
            f["day"] = max(f.get("day", 0), int(d.get("day", 0) or 0))
        if k == "run_end":
            f["run finished"] = True
    n = len(furthest)
    funnel = [("Opened the game", n)]
    for step in ["tutorial started", "tutorial finished", "run started"]:
        funnel.append((step.capitalize(), sum(1 for f in furthest.values() if f.get(step))))
    max_day = max([f.get("day", 0) for f in furthest.values()] + [0])
    for day in range(1, max_day + 1):
        funnel.append(("Finished day %d" % day, sum(1 for f in furthest.values() if f.get("day", 0) >= day)))
    funnel.append(("Finished a run", sum(1 for f in furthest.values() if f.get("run finished"))))
    out["funnel"] = funnel

    quits = collections.Counter("day %s, %s" % ((r.get("data") or {}).get("day"), (r.get("data") or {}).get("in"))
                                for r in by_kind["run_quit"])
    out["quits"] = quits.most_common(12)

    tut = collections.defaultdict(list)
    for r in by_kind["tutorial_step"]:
        d = r.get("data") or {}
        tut[(d.get("index", 0), d.get("step", "?"))].append(float(d.get("seconds", 0)))
    exits = collections.Counter((r.get("data") or {}).get("step", "?")
                                for r in by_kind["tutorial_end"] if not (r.get("data") or {}).get("completed"))
    out["tutorial"] = [(step, len(v), statistics.median(v), quantile(v, 0.9), exits.get(step, 0))
                       for (i, step), v in sorted(tut.items())]

    # Stall points: think time by situation, and the slowest single moments.
    think = collections.defaultdict(list)
    for r in by_kind["action"]:
        if r.get("think_ms") is not None:
            think[situation(r)].append(r["think_ms"] / 1000.0)
    for r in by_kind["shop"]:
        if r.get("think_ms") is not None:
            think["store: " + (r.get("data") or {}).get("cmd", "?")].append(r["think_ms"] / 1000.0)
    for r in by_kind["shift_pick"]:
        if r.get("think_ms") is not None:
            think["calendar: pick a shift"].append(r["think_ms"] / 1000.0)
    out["think"] = sorted(((k, len(v), statistics.median(v), quantile(v, 0.9)) for k, v in think.items() if len(v) >= 3),
                          key=lambda t: -t[2])
    slow = sorted((r for r in by_kind["action"] if r.get("think_ms")), key=lambda r: -r["think_ms"])[:15]
    out["slowest"] = [(r["think_ms"] / 1000.0, situation(r), (r.get("data") or {}).get("card", ""),
                       (r.get("data") or {}).get("archetype", ""), (r.get("data") or {}).get("day", ""),
                       (r.get("data") or {}).get("tick", "")) for r in slow]

    # Confusion: refusals, and the same refusal twice in a row.
    refusals = collections.defaultdict(lambda: {"times": 0, "players": set(), "repeats": 0})
    for evs in sessions.values():
        last = None
        for r in evs:
            if r["kind"] != "action":
                continue
            d = r.get("data") or {}
            if d.get("ok") is False:
                key = (d.get("cmd", "?"), d.get("refused", ""))
                refusals[key]["times"] += 1
                refusals[key]["players"].add(r["install"])
                if last == key:
                    refusals[key]["repeats"] += 1
                last = key
            else:
                last = None
    out["refusals"] = sorted(((cmd, msg, v["times"], len(v["players"]), v["repeats"])
                              for (cmd, msg), v in refusals.items()), key=lambda t: -t[2])[:25]

    # Balance: shifts by profile, bosses, archetypes, demands.
    shifts = collections.defaultdict(lambda: {"n": 0, "made": 0, "walked": 0, "standing": 0, "banked": 0})
    for r in by_kind["shift_end"]:
        d = r.get("data") or {}
        s = shifts[d.get("profile", "?")]
        s["n"] += 1
        s["made"] += 1 if d.get("made_quota") else 0
        s["walked"] += int(d.get("customers_walked", 0) or 0)
        s["standing"] += int(d.get("standing_delta", 0) or 0)
        s["banked"] += int(d.get("margin_banked", 0) or 0)
    out["shifts"] = sorted(((p, v["n"], pct(v["made"], v["n"]), v["walked"] / v["n"], v["standing"] / v["n"],
                             v["banked"] / v["n"]) for p, v in shifts.items()), key=lambda t: -t[1])

    seen = collections.Counter()
    walked = collections.Counter()
    signed = collections.Counter()
    for r in by_kind["walkout"] + by_kind["walked"]:
        walked[(r.get("data") or {}).get("archetype", "?")] += 1
    for r in by_kind["signed"]:
        signed[(r.get("data") or {}).get("archetype", "?")] += 1
    for a in set(walked) | set(signed):
        seen[a] = walked[a] + signed[a]
    out["archetypes"] = sorted(((a, seen[a], signed[a], walked[a], pct(walked[a], seen[a])) for a in seen),
                               key=lambda t: -t[4])

    demands = collections.defaultdict(lambda: {"raised": 0, "answered": 0, "missed": 0})
    for r in by_kind["customer"]:
        name = (r.get("data") or {}).get("name", "")
        if " - " in name:
            base, how = name.rsplit(" - ", 1)
            if how in ("answered", "handled"):
                demands[base]["answered"] += 1
            elif how in ("lands", "IGNORED"):
                demands[base]["missed"] += 1
    out["demands"] = sorted(((k, v["answered"], v["missed"], pct(v["missed"], v["answered"] + v["missed"]))
                             for k, v in demands.items()), key=lambda t: -t[3])

    # Cards.
    cards = collections.defaultdict(collections.Counter)
    for r in by_kind["action"]:
        d = r.get("data") or {}
        if d.get("card") and d.get("ok"):
            cards[d["card"]][d.get("cmd", "?")] += 1
    for r in by_kind["shop"]:
        d = r.get("data") or {}
        card = d.get("card") or d.get("id")
        if card and d.get("ok"):
            cards[card]["shop:" + d.get("cmd", "?")] += 1
    out["cards"] = sorted(((c, v["play_card"] + v["place"], v["dig"], v["shop:buy"], v["shop:upgrade"],
                            v["shop:remove"], v["shop:take_free"]) for c, v in cards.items()), key=lambda t: -t[1])

    shop_end = by_kind["shop_end"]
    out["store"] = {
        "visits": len(shop_end),
        "median_seconds": statistics.median([float((r.get("data") or {}).get("seconds", 0)) for r in shop_end]) if shop_end else 0,
        "median_money_left": statistics.median([int((r.get("data") or {}).get("money_left", 0)) for r in shop_end]) if shop_end else 0,
    }

    # Runs.
    ends = by_kind["run_end"]
    out["runs"] = {"started": len(by_kind["run_start"]), "finished": len(ends),
                   "fired": sum(1 for r in ends if (r.get("data") or {}).get("fired")),
                   "quit": len(by_kind["run_quit"]),
                   "median_score": statistics.median([int((r.get("data") or {}).get("score", 0)) for r in ends]) if ends else 0}

    # A few sessions to read move by move.
    out["timelines"] = {}
    for sid, evs in sorted(sessions.items(), key=lambda kv: -len(kv[1]))[:12]:
        out["timelines"][sid[:8]] = [[r["t_ms"] / 1000.0, r["kind"], r.get("think_ms"), describe(r)] for r in evs]
    return out


def describe(r):
    d = r.get("data") or {}
    k = r["kind"]
    if k == "action":
        s = d.get("cmd", "")
        if d.get("card"):
            s += " " + d["card"]
        if d.get("archetype"):
            s += " on " + d["archetype"]
        if d.get("ok") is False:
            s += " - REFUSED: " + str(d.get("refused", ""))
        elif d.get("sold_for"):
            s += " - sold for $%s" % d["sold_for"]
        return s
    if k == "customer":
        return "%s: %s %s" % (d.get("archetype", ""), d.get("name", ""), json.dumps(d.get("fx", {})))
    if k in ("shift_pick",):
        return "%s (%s, quota %s)" % (d.get("id"), d.get("slot"), d.get("quota"))
    if k == "shift_end":
        return "%s: banked %s of %s, %s walked" % (d.get("profile"), d.get("margin_banked"), d.get("quota"), d.get("customers_walked"))
    if k == "shop":
        return "%s %s%s" % (d.get("cmd"), d.get("card") or d.get("id") or "", "" if d.get("ok") else " - REFUSED")
    keep = {key: v for key, v in d.items() if not isinstance(v, (list, dict))}
    return ", ".join("%s %s" % (key, v) for key, v in list(keep.items())[:6])


# --- the page -----------------------------------------------------------------

def esc(v):
    return html.escape(str(v))


def table(headers, rows, numeric=()):
    head = "".join("<th%s>%s</th>" % (' class="n"' if i in numeric else "", esc(h)) for i, h in enumerate(headers))
    body = []
    for row in rows:
        cells = []
        for i, v in enumerate(row):
            if isinstance(v, float):
                v = "%.1f" % v
            cells.append("<td%s>%s</td>" % (' class="n"' if i in numeric else "", esc(v)))
        body.append("<tr>%s</tr>" % "".join(cells))
    if not body:
        return '<p class="empty">Nothing recorded yet.</p>'
    return '<div class="scroll"><table><thead><tr>%s</tr></thead><tbody>%s</tbody></table></div>' % (head, "".join(body))


def bars(rows):
    if not rows:
        return '<p class="empty">Nothing recorded yet.</p>'
    top = max(v for _, v in rows) or 1
    out = []
    for label, v in rows:
        out.append('<div class="bar"><span class="lbl">%s</span><span class="track"><span class="fill" style="width:%.1f%%"></span></span><span class="val">%s</span></div>'
                   % (esc(label), 100.0 * v / top, esc(v)))
    return "".join(out)


def page(a, title):
    sections = []
    sections.append(("Who played", "<p>%d installs, %d sessions, %d events. Builds: %s. Platforms: %s.</p>" % (
        a["installs"], a["sessions"], a["rows"],
        esc(", ".join("%s (%d)" % b for b in a["builds"])) or "-",
        esc(", ".join("%s (%d)" % p for p in a["platforms"])) or "-")))
    r = a["runs"]
    sections.append(("Funnel - where players stop", bars(a["funnel"]) + "<p>Runs: %d started, %d finished (%d fired), %d quit. Median final score %s.</p>" % (
        r["started"], r["finished"], r["fired"], r["quit"], r["median_score"])
        + "<h3>Where runs were quit</h3>" + table(["Day, screen", "Quits"], a["quits"], (1,))))
    sections.append(("Tutorial", table(["Step", "Seen", "Median s", "90th pct s", "Left here"], a["tutorial"], (1, 2, 3, 4))))
    sections.append(("Stall points - think time by situation", table(["Situation", "Moves", "Median s", "90th pct s"], a["think"], (1, 2, 3))
                     + "<h3>The slowest single moves</h3>" + table(["Seconds", "Situation", "Card", "Customer", "Day", "Tick"], a["slowest"], (0, 4, 5))))
    sections.append(("Confusion - what the rules refused", table(["Move", "Refusal", "Times", "Players", "Same one twice in a row"], a["refusals"], (2, 3, 4))))
    sections.append(("Shifts", table(["Shift", "Worked", "Made quota %", "Walkouts", "Standing change", "Banked"], a["shifts"], (1, 2, 3, 4, 5))))
    sections.append(("Customers", table(["Archetype", "Left the floor", "Signed", "Walked out", "Walkout %"], a["archetypes"], (1, 2, 3, 4))
                     + "<h3>Demands and boss moves</h3>" + table(["Demand / move", "Answered", "Missed", "Missed %"], a["demands"], (1, 2, 3))))
    s = a["store"]
    sections.append(("Cards", table(["Card", "Played", "Dug", "Bought", "Upgraded", "Removed", "Free pick"], a["cards"], (1, 2, 3, 4, 5, 6))
                     + "<p>Store: %d visits, median %.0f s, median $%s left unspent.</p>" % (s["visits"], s["median_seconds"], s["median_money_left"])))
    options = "".join('<option value="%s">%s (%d events)</option>' % (esc(k), esc(k), len(v)) for k, v in a["timelines"].items())
    sections.append(("Session timeline", '<select id="pick">%s</select><div id="timeline"></div>' % options))

    nav = "".join('<a href="#s%d">%s</a>' % (i, esc(t.split(" - ")[0])) for i, (t, _) in enumerate(sections))
    body = "".join('<section id="s%d"><h2>%s</h2>%s</section>' % (i, esc(t), c) for i, (t, c) in enumerate(sections))
    return TEMPLATE.replace("{{title}}", esc(title)).replace("{{nav}}", nav).replace("{{body}}", body) \
        .replace("{{timelines}}", json.dumps(a["timelines"]).replace("</", "<\\/"))


TEMPLATE = """<title>Rogue Dealership Play Metrics</title>
<style>
:root { --bg:#f6f4ef; --card:#fffdf8; --fg:#23211d; --dim:#6b665c; --line:#e3ddd0; --accent:#c25b1f; --fill:#d98a4e; color-scheme: light }
@media (prefers-color-scheme: dark) { :root:not([data-theme="light"]) { --bg:#191816; --card:#22201d; --fg:#ece7dc; --dim:#a39c8e; --line:#36322c; --accent:#f08a4b; --fill:#c8763c; color-scheme: dark } }
:root[data-theme="dark"] { --bg:#191816; --card:#22201d; --fg:#ece7dc; --dim:#a39c8e; --line:#36322c; --accent:#f08a4b; --fill:#c8763c; color-scheme: dark }
body { background:var(--bg); color:var(--fg); font:15px/1.5 system-ui, -apple-system, Segoe UI, sans-serif; margin:0; padding-inline:16px; padding-block:24px }
main { max-width:1100px; margin:0 auto }
h1 { font-size:28px; margin:0 0 4px; text-wrap:balance } h2 { font-size:20px; margin:0 0 12px } h3 { font-size:15px; margin:18px 0 8px; color:var(--dim); text-transform:uppercase; letter-spacing:.06em }
.sub { color:var(--dim); margin:0 0 16px }
nav { display:flex; flex-wrap:wrap; gap:6px 14px; margin-bottom:20px } nav a { color:var(--accent); text-decoration:none }
section { background:var(--card); border:1px solid var(--line); border-radius:10px; padding:18px; margin-bottom:16px; min-width:0 }
.scroll { overflow-x:auto } table { border-collapse:collapse; width:100%; font-variant-numeric:tabular-nums }
th, td { text-align:left; padding:6px 10px; border-bottom:1px solid var(--line); vertical-align:top } th { color:var(--dim); font-weight:600; font-size:13px }
.n { text-align:right } .empty { color:var(--dim) }
.bar { display:grid; grid-template-columns:minmax(120px, 220px) 1fr 60px; gap:10px; align-items:center; margin:4px 0 }
.track { background:var(--line); border-radius:4px; height:14px; overflow:hidden } .fill { display:block; height:100%; background:var(--fill) }
.val { text-align:right; font-variant-numeric:tabular-nums } .lbl { overflow:hidden; text-overflow:ellipsis; white-space:nowrap }
select { font:inherit; padding:6px; margin-bottom:10px; max-width:100% }
#timeline div { display:grid; grid-template-columns:70px 110px 60px 1fr; gap:8px; padding:3px 0; border-bottom:1px solid var(--line); font-size:13px; font-variant-numeric:tabular-nums }
#timeline .slow { color:var(--accent); font-weight:600 }
@media (max-width:600px) { #timeline div { grid-template-columns:56px 1fr; } }
</style>
<main>
<h1>Play metrics</h1>
<p class="sub">{{title}}</p>
<nav>{{nav}}</nav>
{{body}}
</main>
<script>
const timelines = {{timelines}};
const pick = document.getElementById('pick'), box = document.getElementById('timeline');
function show(id) {
  box.innerHTML = '';
  for (const [t, kind, think, what] of (timelines[id] || [])) {
    const row = document.createElement('div');
    const thinkS = think == null ? '' : (think / 1000).toFixed(1) + 's';
    if (think != null && think > 20000) row.className = 'slow';
    for (const v of [t.toFixed(1) + 's', kind, thinkS, what]) { const c = document.createElement('span'); c.textContent = v; row.appendChild(c); }
    box.appendChild(row);
  }
}
if (pick) { pick.addEventListener('change', () => show(pick.value)); show(pick.value); }
</script>
"""


def service_key():
    """The key from this terminal's environment - or, on Windows, from where setx
    saved it: setx only reaches terminals opened after it ran."""
    key = os.environ.get("SUPABASE_SERVICE_KEY", "")
    if key or os.name != "nt":
        return key
    try:
        import winreg
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, "Environment") as k:
            return str(winreg.QueryValueEx(k, "SUPABASE_SERVICE_KEY")[0])
    except OSError:
        return ""


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--since", help="only events on or after this date (YYYY-MM-DD)")
    ap.add_argument("--build", help="only events from builds starting with this label, e.g. '#205'")
    ap.add_argument("--from-json", help="read events from this file instead of Supabase")
    ap.add_argument("--save-json", help="also write the fetched events here")
    ap.add_argument("--out", default="telemetry_report.html")
    args = ap.parse_args()
    if args.from_json:
        with open(args.from_json, encoding="utf-8") as f:
            rows = json.load(f)
    else:
        key = service_key()
        if not key:
            sys.exit("Set SUPABASE_SERVICE_KEY (Supabase -> Settings -> API -> service_role) first.")
        rows = fetch(args.since, args.build, key)
    if args.save_json:
        with open(args.save_json, "w", encoding="utf-8") as f:
            json.dump(rows, f)
    a = analyse(rows)
    scope = "All events" if not (args.since or args.build) else "Events %s%s" % (
        "since " + args.since if args.since else "", " from build " + args.build if args.build else "")
    title = "%s - made %s" % (scope, dt.datetime.now().strftime("%Y-%m-%d %H:%M"))
    with open(args.out, "w", encoding="utf-8") as f:
        f.write(page(a, title))
    print("wrote %s: %d events, %d sessions" % (args.out, a["rows"], a["sessions"]))


if __name__ == "__main__":
    main()
