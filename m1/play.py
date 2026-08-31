# -*- coding: utf-8 -*-
"""
Rogue Dealership - M1 playable prototype (v3). The fun test.

    python m1/play.py
    python m1/play.py --seed 7
    python m1/play.py --floor guarded,reserved,rushed
    python m1/play.py --set actions_per_round=4 --set hand_size=6
    python m1/play.py --no-color

Drives engine.py, exactly as a simulator would, so what you play is what the
rules actually say. Build Trust and their needs surface on their own; cash Trust
in for Patience when someone is about to walk; pitch what you know, or gamble.
"""
import argparse
import json
import os
import re
import sys
import textwrap

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import engine  # noqa: E402

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass


class Quit(Exception):
    pass


def _enable_ansi():
    if os.name != "nt":
        return sys.stdout.isatty()
    try:
        import ctypes
        k = ctypes.windll.kernel32
        h = k.GetStdHandle(-11)
        mode = ctypes.c_uint32()
        if not k.GetConsoleMode(h, ctypes.byref(mode)):
            return False
        k.SetConsoleMode(h, mode.value | 0x0004)
        return True
    except Exception:
        return False


class C(object):
    on = False

    @classmethod
    def _w(cls, code, s):
        return "\033[%sm%s\033[0m" % (code, s) if cls.on else s

    @classmethod
    def dim(cls, s):
        return cls._w("2", s)

    @classmethod
    def bold(cls, s):
        return cls._w("1", s)

    @classmethod
    def red(cls, s):
        return cls._w("91", s)

    @classmethod
    def green(cls, s):
        return cls._w("92", s)

    @classmethod
    def yellow(cls, s):
        return cls._w("93", s)

    @classmethod
    def blue(cls, s):
        return cls._w("96", s)

    @classmethod
    def mag(cls, s):
        return cls._w("95", s)

    @classmethod
    def grey(cls, s):
        return cls._w("90", s)


KIND_COLOR = {
    "sale": C.green,
    "miss": C.red,
    "reveal": C.blue,
    "rapport": C.mag,
    "round": C.grey,
}

ANSI = re.compile(r"\033\[[0-9;]*m")


def pad(s, n):
    """Left-justify to a VISIBLE width - colour codes must not count."""
    return s + " " * max(0, n - len(ANSI.sub("", s)))


def bar(cur, top, width=14):
    top = max(1, top)
    frac = max(0.0, min(1.0, float(cur) / top))
    n = int(round(width * frac))
    body = "#" * n + "-" * (width - n)
    paint = C.green if frac > 0.5 else (C.yellow if frac > 0.25 else C.red)
    return paint(body)


def rule(ch="="):
    return ch * 78


# --------------------------------------------------------------------------
# Rendering
# --------------------------------------------------------------------------
def render_floor(g, debug=False):
    cat = g.cat
    baseline = cat.base["decay"]
    out = [rule()]
    out.append(" %s   Round %-3d %s" % (
        C.bold("ROGUE DEALERSHIP"), g.round_no,
        C.bold("Margin banked: %d" % g.margin).rjust(30)))
    out.append(rule())

    for c in g.customers:
        if c.state == "gone":
            gone = (C.green("TAPPED OUT") if c.exit_reason == "tapped"
                    else C.red("LEFT THE FLOOR"))
            out.append(" %s %s%s" % (
                C.grey(pad("[%s] %s" % (c.key, c.name), 15)), gone,
                C.grey("   sold: " + ", ".join(cat.products[p]["name"] for p in c.sold))
                if c.sold else ""))
            out.append("")
            continue
        if c.state == "away":
            out.append(" %s %s" % (C.grey(pad("[%s] %s" % (c.key, c.name), 15)),
                                   C.yellow("STEPPED AWAY - may come back")))
            out.append("")
            continue

        # The burn RATE is the triage information. It has to be readable at a
        # glance, or "starts high, burns fast" is a gotcha instead of a trap.
        rate = "-%d/rnd" % c.decay
        rate = C.red(rate) if c.decay > baseline else C.grey(rate)
        eta = "~%dr" % c.rounds_left
        eta = C.red(eta) if c.rounds_left <= 3 else C.grey(eta)

        nxt = c.next_threshold
        if nxt is None:
            trust_txt = "%s %s" % (C.blue("Trust %d" % c.trust), C.green("fully read"))
        else:
            trust_txt = "%s %s" % (C.blue("Trust %d" % c.trust),
                                   C.grey("reveal at %d (+%d)"
                                          % (nxt, max(0, nxt - c.trust))))

        # Budget is a triage input, not a surprise: it reads directly as "the
        # most this customer is worth to you", so it has to be visible before
        # you spend an action on them.
        rich = c.budget >= max(p["margin"] for p in cat.tray)
        wallet = (C.yellow if rich else C.grey)("Budget %d" % c.budget)

        out.append(" %s%s %s %s %s %s" % (
            C.bold(pad("[%s] %s" % (c.key, c.name), 14)),
            bar(c.patience, c.max_patience, width=12),
            pad("%d/%d" % (c.patience, c.max_patience), 6),
            pad(rate, 7), pad(eta, 5), wallet))

        slots = []
        for i in (0, 1):
            if debug:
                slots.append(C.mag(cat.need_name(c.needs[i])))
            elif c.revealed[i]:
                slots.append(C.green(cat.need_name(c.needs[i])))
            else:
                slots.append(C.grey("???"))
        line = "     %s%s" % (pad(trust_txt, 27),
                              pad("%s | %s" % (slots[0], slots[1]), 30))
        if c.eliminated:
            line += C.grey("not: " + ", ".join(
                sorted(cat.need_name(n) for n in c.eliminated)))
        out.append(line.rstrip())
        if c.sold:
            out.append("     %s %s" % (C.green("sold"), C.green(", ".join(
                cat.products[p]["name"] for p in c.sold))))
        out.append("")
    return "\n".join(out)


def render_tray(g):
    """Always visible, always playable. Products are never in the deck."""
    out = [" %s  %s" % (C.bold("PRODUCTS"), C.grey("always available"))]
    for i, p in enumerate(g.cat.tray):
        out.append("  %s %s %s  %s" % (
            C.bold("P%d" % (i + 1)), pad(p["name"], 34),
            C.yellow("m%d" % p["margin"]), g.cat.need_name(p["needs"][0])))
    return "\n".join(out)


def render_hand(g):
    out = [" %s   %s   %s" % (
        C.bold("HAND"),
        C.bold("Actions %d/%d" % (g.actions_left, g.cfg["actions_per_round"])),
        C.grey("draw %d  discard %d" % (len(g.draw_pile), len(g.discard_pile))))]
    for i, card in enumerate(g.hand):
        if card["type"] == "convert":
            eff = "%d Trust -> %d Patience" % (g.cfg["reassure_trust_cost"],
                                               g.cfg["reassure_patience_gain"])
        elif card["targets"] == "floor":
            eff = "+%d Trust to EVERYONE on the floor" % card["trust"]
        else:
            eff = "+%d Trust" % card["trust"]
        free = C.green("FREE") if card.get("actions", 1) == 0 else "    "
        out.append("  %s  %s %s %s" % (C.bold(str(i + 1)), pad(card["name"], 20),
                                       free, eff))
    return "\n".join(out)


HELP = """
 Commands
   1A      play hand card 1 on customer A
   1       play a floor-wide card (Common Ground) - it needs no target
   P3A     pitch product 3 at customer A
   end     end the round (everyone on the floor burns Patience)
   card 3  read what hand card 3 actually does
   debug   reveal the hidden needs (for checking the model)
   help    this
   quit    give up on the shift

 How it works
   TRUST has two jobs. Build it and their needs SURFACE ON THEIR OWN at
   thresholds - there is no "ask" action. Or spend it with Reassure to buy
   Patience. Building Trust is asking.
   PATIENCE is the whole clock, and it burns at a DIFFERENT RATE per customer.
   Watch the -N/rnd figure, not just the bar: someone can start comfortable
   and still be the one you have to deal with first.
   A REVEAL IS PERMANENT. Reassure drops your Trust below a threshold you
   already crossed, but never un-teaches you - it only costs you progress
   toward the NEXT reveal.
   PITCHING IS ALWAYS LEGAL, even at zero Trust and knowing nothing. Two needs
   out of six is a 1-in-3 blind guess; every miss costs 4 Patience but rules a
   need out, so the odds climb as you burn the clock. That is the gamble.
   BUDGET is their wallet, and it reads as what they are WORTH to you - a sale
   draws it down by that product's margin. It never blocks an offer: a sale
   bigger than what is left goes through and they stretched for it. But an
   empty wallet ends them, TAPPED OUT, which is the good way to lose someone.
   A thin wallet means one sale no matter how well you read them, so check it
   before you spend three actions diagnosing.
   Some cards are FREE - no action. Never a question of whether, only of who.
"""


def render_report(g):
    rep = g.report()
    out = ["", rule(), " %s" % C.bold("END OF SHIFT"), rule()]
    out.append(" Margin banked   %s" % C.bold(C.green(str(rep["margin"]))))
    out.append(" Sales           %d in %d offers (%.0f%% close rate), %d taken blind"
               % (rep["sales"], rep["offers"], 100.0 * rep["close_rate"],
                  rep["blind_offers"]))
    if rep["first_margin_action"]:
        out.append(" First margin    on action %d" % rep["first_margin_action"])
    out.append(" Rounds          %d" % rep["rounds"])
    out.append(" How they left   %s tapped out, %s walked"
               % (C.green(str(rep["tapped_out"])), C.red(str(rep["walked"]))))
    out.append(" %s %.1f actions and %.1f cards left unused per round"
               % (C.grey("Decision density"), rep["actions_unspent_per_round"],
                  rep["cards_unplayed_per_round"]))
    out.append("")
    for rc in rep["customers"]:
        how = {"tapped": C.green("tapped out"), "walked": C.red("walked")}.get(
            rc["exit_reason"], C.grey("still there"))
        spent = rc["start_budget"] - rc["budget"]
        wallet = ("wallet %d, stretched to %d" % (rc["start_budget"], spent)
                  if spent > rc["start_budget"]
                  else "wallet %d, spent %d" % (rc["start_budget"], spent))
        out.append(" [%s] %s  %s  %s" % (
            rc["key"], pad(rc["name"], 11), pad(how, 11),
            C.grey("burned %d/rnd, %s" % (rc["decay"], wallet))))
        out.append("      actually needed  %s" % C.mag(" and ".join(rc["needs"])))
        out.append("      you diagnosed    %d of 2" % rc["diagnosed"])
        out.append("      sold             %s"
                   % (", ".join(rc["sold"]) or C.grey("nothing")))
        if rc["missed"]:
            out.append("      refused          %s" % C.red(", ".join(rc["missed"])))
    out.append(rule())
    out.append(C.grey(" Was it fun? That is the only question this build exists to"
                      " answer."))
    out.append(C.grey(" Retune m1/data/config.json and run it again."))
    return "\n".join(out)


# --------------------------------------------------------------------------
# Input
# --------------------------------------------------------------------------
PITCH = re.compile(r"^p\s*(\d+)\s*([a-z])$", re.I)
CARD = re.compile(r"^(\d+)\s*([a-z])?$", re.I)


def handle(g, raw, state):
    """Returns a message to print, or None."""
    low = raw.strip().lower()
    if low in ("q", "quit", "exit"):
        raise Quit()
    if low in ("h", "help", "?"):
        return HELP
    if low in ("e", "end", ""):
        g.end_round()
        return None
    if low == "debug":
        state["debug"] = not state["debug"]
        return C.mag(" debug %s" % ("ON - hidden needs shown" if state["debug"]
                                    else "off"))
    if low.startswith("card"):
        try:
            card = g.hand[int(low.split()[1]) - 1]
        except (IndexError, ValueError):
            return C.red(" No such card.")
        body = textwrap.fill(card["text"], width=72,
                             initial_indent="   ", subsequent_indent="   ")
        return " %s\n%s" % (C.bold(card["name"]), C.grey(body))

    m = PITCH.match(low)
    if m:
        res = g.pitch(int(m.group(1)) - 1, ord(m.group(2)) - ord("a"))
        return " %s" % KIND_COLOR.get(res.kind, C.red)(res.msg)

    m = CARD.match(low)
    if m:
        ci = int(m.group(1)) - 1
        ki = ord(m.group(2)) - ord("a") if m.group(2) else None
        res = g.play_card(ci, ki)
        return " %s" % KIND_COLOR.get(res.kind, C.red)(res.msg)

    return C.red(" Try '1A' (card on customer), 'P3A' (pitch), 'end', 'help'.")


def main():
    ap = argparse.ArgumentParser(description="Rogue Dealership - M1 prototype")
    ap.add_argument("--seed", type=int, default=None)
    ap.add_argument("--floor", default=None,
                    help="comma-separated archetype ids, e.g. guarded,reserved,rushed")
    ap.add_argument("--set", action="append", default=[], metavar="KEY=VALUE",
                    help="override a config value for this run (repeatable)")
    ap.add_argument("--no-color", action="store_true")
    args = ap.parse_args()

    C.on = (not args.no_color) and _enable_ansi()

    cat = engine.Catalog()
    for kv in args.set:
        if "=" not in kv:
            print("bad --set %r, expected KEY=VALUE" % kv)
            return 2
        k, v = kv.split("=", 1)
        if k not in cat.config:
            print("unknown config key %r. Known keys:\n  %s"
                  % (k, "\n  ".join(sorted(x for x in cat.config
                                           if not x.startswith("_")))))
            return 2
        try:
            cat.config[k] = json.loads(v)
        except ValueError:
            cat.config[k] = v
        print(C.grey("config: %s = %r" % (k, cat.config[k])))

    floor = args.floor.split(",") if args.floor else None
    if floor:
        for a in floor:
            if a not in cat.archetypes:
                print("unknown archetype %r. Known: %s"
                      % (a, ", ".join(sorted(cat.archetypes))))
                return 2

    g = engine.Game(catalog=cat, seed=args.seed, floor=floor)
    state = {"debug": False}
    seen = 0

    print(HELP)
    try:
        while not g.over:
            print(render_floor(g, state["debug"]))
            print(render_tray(g))
            print("")
            print(render_hand(g))
            for line in g.events[seen:]:
                print(C.grey("   . " + line))
            seen = len(g.events)
            print("")
            try:
                raw = input(C.bold("> "))
            except (EOFError, KeyboardInterrupt):
                raise Quit()
            msg = handle(g, raw, state)
            if msg:
                print(msg)
            print("")
    except Quit:
        print(C.grey("\n You walk off the floor."))

    for line in g.events[seen:]:
        print(C.grey("   . " + line))
    print(render_report(g))
    return 0


if __name__ == "__main__":
    sys.exit(main())
