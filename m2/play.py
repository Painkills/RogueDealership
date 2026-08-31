# -*- coding: utf-8 -*-
"""
Rogue Dealership - M2 playable prototype. The negotiation model. The fun test.

    python m2/play.py
    python m2/play.py --seed 7
    python m2/play.py --floor hawk,karen,kicker
    python m2/play.py --set shift_ticks=12 --set quota=1500
    python m2/play.py --no-color

Drives engine.py, exactly as a simulator would, so what you play is what the
rules actually say. Place a product to see how they take it, build it up, then
ask - asking is free, but it is also what provokes them.
"""
import argparse
import json
import os
import random
import re
import sys
import textwrap

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import engine  # noqa: E402

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

money = engine._money


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
    "close": C.green,
    "miss": C.yellow,
    "place": C.blue,
    "reveal": C.blue,
    "support": C.mag,
    "drop": C.grey,
    "dig": C.grey,
    "move": C.grey,
}

BAND_COLOR = {
    "ALMOST": C.green,
    "WARM": C.yellow,
    "COOL": C.mag,
    "COLD": C.red,
}

ANSI = re.compile(r"\033\[[0-9;]*m")
ORDINALS = ["", "1st", "2nd", "3rd", "4th", "5th", "6th", "7th", "8th", "9th"]


def pad(s, n):
    """Left-justify to a VISIBLE width - colour codes must not count."""
    return s + " " * max(0, n - len(ANSI.sub("", s)))


def bar(cur, top, width=10):
    top = max(1, top)
    frac = max(0.0, min(1.0, float(cur) / top))
    n = int(round(width * frac))
    body = "#" * n + "-" * (width - n)
    paint = C.green if frac > 0.5 else (C.yellow if frac > 0.25 else C.red)
    return paint(body)


WIDTH = 26


def _bar_body(fill_char, fill, mark, width=WIDTH):
    out = []
    for i in range(width):
        if i == mark:
            out.append("|")
        elif i < fill:
            out.append(fill_char)
        elif mark is not None and i < mark:
            out.append("-")
        else:
            out.append(".")
    return "".join(out)


def appeal_row(g, cust, scale):
    """A PERMANENT row on the customer sheet, not something that only exists
    while an offer happens to be short. Fixed scale on purpose: a Lay-Down's
    marker sits early and a Hawk's sits late, so you can read how hard someone
    is at a glance without reading a number."""
    o = cust.offer
    label = C.grey("APPEAL")

    if not cust.known_threshold:
        return "    %s  [%s]  %s" % (
            label, C.grey("?" * WIDTH),
            C.grey("you don't know their line yet - place something, or read "
                   "the room"))

    mark = min(WIDTH - 1,
               int(round(WIDTH * min(1.0, float(cust.threshold) / scale))))

    if o is None:
        return "    %s  [%s]  %s" % (
            label, C.blue(_bar_body("#", 0, mark)),
            C.grey("their line is ") + C.bold(str(cust.threshold)))

    if not o.revealed:
        return "    %s  [%s]  %s" % (
            label, C.blue(_bar_body("?", mark, mark)),
            C.grey("ask them to see where you stand"))

    fill = int(round(WIDTH * max(0.0, min(1.0, float(o.appeal) / scale))))
    gap = cust.threshold - o.appeal
    body = _bar_body("#", fill, mark)
    if gap <= 0:
        return "    %s  [%s]  %s" % (label, C.green(body),
                                     C.bold(C.green("READY - ask them")))
    band = g.cat.objection_for(gap)["label"]
    return "    %s  [%s]  %s" % (
        label, C.blue(body),
        C.bold(BAND_COLOR.get(band, C.yellow)("%d SHORT" % gap)))


def describe_effect(eff):
    """Plain words for what just happened to you."""
    bits = []
    if eff.get("threshold"):
        n = eff["threshold"]
        bits.append("the line moves %s%d" % ("+" if n > 0 else "-", abs(n)))
    if eff.get("appeal"):
        bits.append("the offer sours by %d" % abs(eff["appeal"]))
    if eff.get("margin"):
        n = eff["margin"]
        bits.append("$%s %s the table" % (money(abs(n)),
                                          "onto" if n > 0 else "off"))
    if eff.get("patience_self"):
        n = eff["patience_self"]
        bits.append("they %s %d patience" % ("gain" if n > 0 else "lose",
                                             abs(n)))
    if eff.get("patience_floor"):
        n = eff["patience_floor"]
        bits.append("EVERYONE ELSE on the floor %s %d patience"
                    % ("gains" if n > 0 else "loses", abs(n)))
    if eff.get("discard_hand"):
        bits.append("you lose %d card(s) from hand" % abs(eff["discard_hand"]))
    if eff.get("margin_bonus"):
        bits.append("+$%s on the sale" % money(eff["margin_bonus"]))
    return ", ".join(bits) or "nothing you can see"


def render_actions(g, seen):
    """Loud. An action can fire while you are across the floor with someone
    else, and a floor-wide one has to be impossible to miss."""
    out = []
    for a in g.action_log[seen:]:
        floorwide = bool(a["effect"].get("patience_floor"))
        paint = C.red if floorwide else C.mag
        out.append(" %s %s" % (
            paint(C.bold(">>")),
            paint(C.bold("%s (%s) - %s" % (a["customer"], a["key"], a["name"])))))
        if a["line"]:
            out.append("    %s" % paint(a["line"]))
        out.append("    %s" % C.bold(paint(describe_effect(a["effect"]))))
    return "\n".join(out)


def rule(ch="="):
    return ch * 78


# --------------------------------------------------------------------------
# Flavour. Presentation only, and it gets its own RNG so that reading a line
# of dialogue can never shift what the RULES roll next.
# --------------------------------------------------------------------------
class Voice(object):
    def __init__(self, cat, seed):
        self.cat = cat
        self.rng = random.Random(seed)
        self.cache = {}

    def _key(self, cust):
        o = cust.offer
        return (cust.key, o.product["id"], o.appeal, cust.threshold, o.revealed)

    def band(self, cust):
        gap = cust.threshold - cust.offer.appeal
        return self.cat.objection_for(gap)["label"]

    def reaction(self, cust):
        """Stable for as long as the offer stays in the same state - a line
        that re-rolled on every redraw would read as a twitch."""
        key = self._key(cust)
        if key not in self.cache:
            label = self.band(cust)
            pool = (self.cat.objections["bands"] if cust.offer.revealed
                    else None)
            if pool is None:
                lines = self.cat.objections["placed"][label]
            else:
                lines = self.cat.objection_for(
                    cust.threshold - cust.offer.appeal)["lines"]
            self.cache[key] = (label, self.rng.choice(lines))
        return self.cache[key]

    def line(self, key):
        return self.rng.choice(self.cat.objections[key])


# --------------------------------------------------------------------------
# Rendering
# --------------------------------------------------------------------------
def cat_interest(g, product):
    return "%s . %s" % (g.cat.category_name(product["category"]),
                        g.cat.interest_name(product["interest"]))


def alert(cust):
    return C.red(C.bold("!! %d LEFT" % cust.patience))


def status_of(g, cust, voice):
    """The one line the FLOOR gets. Qualitative on purpose: the exact gap lives
    inside the customer view, so going back to check costs a tick."""
    if cust.offer is None:
        return C.grey("nothing on the table")
    label = voice.band(cust)
    return "%s %s" % (pad(cust.offer.product["name"], 30),
                      BAND_COLOR.get(label, C.grey)(label))


def render_floor(g, voice, debug=False):
    risk = g.margin_at_risk
    out = [rule()]
    out.append(" %s  %s  %s  %s" % (
        C.bold("ROGUE DEALERSHIP"),
        C.grey("tick ") + C.bold("%d/%d" % (g.tick, g.tick_budget)),
        C.grey("banked ") + C.bold(C.green("$%s/$%s" % (money(g.margin_banked),
                                                        money(g.quota)))),
        C.yellow("$%s unsigned" % money(risk)) if risk else C.grey("")))
    out.append(rule())

    for i, cust in enumerate(g.chairs):
        key = engine.CHAIR_KEYS[i]
        if cust is None:
            out.append(" %s %s" % (
                C.grey(pad("[%s] --- empty ---" % key, 34)),
                C.grey("someone walks up in %d" % max(0, g.walk_up[i]))))
            out.append("")
            continue

        tail = (alert(cust) if cust.leaving_soon else
                (C.yellow("$%s unsigned" % money(cust.unsigned_margin))
                 if cust.unsigned else ""))
        out.append(" %s %s %s %s %s" % (
            C.bold(pad("[%s] %s" % (key, cust.name), 24)),
            pad(C.grey(cust.archetype["name"]), 17),
            bar(cust.patience, cust.max_patience),
            pad("%2d/%d" % (cust.patience, cust.max_patience), 6), tail))
        line = "     %s" % status_of(g, cust, voice)
        if cust.demands:
            line += C.mag("   wants %s protection"
                          % g.cat.category_name(cust.demands))
        out.append(line)
        if debug:
            order = sorted(cust.ranks.items(), key=lambda kv: kv[1])
            out.append("     " + C.mag("line %d | %s" % (
                cust.threshold,
                " > ".join(g.cat.interest_name(k) for k, _ in order[:4]))))
        out.append("")
    return "\n".join(out)


def render_customer(g, voice, debug=False):
    cust = g.chairs[g.at]
    cat = g.cat
    scale = max(45, cust.threshold + 5)
    out = [rule()]
    line = (C.grey("line ") + C.bold(str(cust.threshold))
            if cust.known_threshold else C.grey("line ") + C.bold("?"))
    out.append(" %s  %s  %s %s   %s" % (
        C.bold("[%s] %s" % (cust.key, cust.name)),
        C.grey(cust.archetype["name"]),
        bar(cust.patience, cust.max_patience),
        C.bold("%d/%d" % (cust.patience, cust.max_patience)), line))
    out.append(rule())
    out.append(" " + C.grey("\"%s\"" % cust.archetype["tell"]))

    if cust.demands:
        out.append(" " + C.mag(C.bold(
            "They came in for %s protection and will not sign without it."
            % cat.category_name(cust.demands))))

    out.append("")
    out.append(" " + C.mag("---- ") + C.bold(C.mag("WHAT THEY DO")) +
               C.mag(" " + "-" * 59))
    if cust.archetype.get("actions"):
        for act in cust.archetype["actions"]:
            out.append("   %s %s" % (C.mag("*"), C.bold(C.mag(act["name"]))))
            out.append("       %s" % C.mag(act["tell"]))
    else:
        out.append("   %s %s" % (C.mag("*"),
                                 C.grey("Nothing. They just sit and listen.")))
    out.append(" " + C.mag("-" * 77))

    if cust.unsigned:
        out.append("")
        items = " . ".join("%s %s" % (u["product"]["name"],
                                      C.yellow("$" + money(u["margin"])))
                           for u in cust.unsigned)
        out.append(" %s   %s" % (C.bold("UNSIGNED"), items))
        out.append("            %s" % C.yellow(
            "$%s at risk - they walk, it goes with them"
            % money(cust.unsigned_margin)))

    o = cust.offer
    out.append("")
    if o is not None:
        out.append(" %s   %s %s %s" % (
            C.bold("ON THE TABLE"), pad(o.product["name"], 28),
            pad(C.grey(cat_interest(g, o.product)), 26),
            C.yellow("$" + money(o.margin))))
        label, line = voice.reaction(cust)
        rank = cust.ranks[o.product["interest"]]
        knows_rank = o.product["interest"] in cust.known_ranks
        out.append("    %s %s" % (
            pad(BAND_COLOR.get(label, C.grey)(line), 48),
            C.grey("their %s of 9" % ORDINALS[rank]) if knows_rank else ""))
    else:
        out.append(" %s" % C.grey("NOTHING ON THE TABLE"))
    out.append(appeal_row(g, cust, scale))
    if o is not None and o.applied:
        out.append("    %s" % C.grey("you tried: " + ", ".join(o.applied)))

    out.append("")
    known = []
    for iid in sorted(cust.known_ranks, key=lambda x: cust.ranks[x]):
        known.append("%s %s" % (cat.interest_name(iid),
                                C.bold(ORDINALS[cust.ranks[iid]])))
    if cust.known_top_category:
        known.append("number one is a %s interest"
                     % C.bold(cat.category_name(cust.known_top_category)))
    out.append(" %s   %s" % (C.bold("YOU KNOW"), " . ".join(known) if known
                             else C.grey("nothing yet - place something, or "
                                         "read the room")))
    if debug:
        order = sorted(cust.ranks.items(), key=lambda kv: kv[1])
        out.append(" " + C.mag("ACTUAL     " + " > ".join(
            cat.interest_name(k) for k, _ in order)))

    others = [c for i, c in enumerate(g.chairs)
              if c is not None and i != g.at and c.leaving_soon]
    if others:
        out.append("")
        for c in others:
            out.append(" %s %s" % (alert(c), C.red("%s (%s) is about to walk"
                                                   % (c.name, c.key))))
    return "\n".join(out)


def render_hand(g):
    out = [" %s %s   %s" % (
        C.bold("HAND"), C.grey("(%d)" % len(g.hand)),
        C.grey("draw %d  discard %d" % (len(g.draw), len(g.discard))))]
    for i, card in enumerate(g.hand):
        n = C.bold(str(i + 1))
        if card["kind"] == "product":
            out.append("  %s %s %s %s %s" % (
                n, pad(card["name"], 28), C.green("PRODUCT"),
                pad(C.yellow("$" + money(card["margin"])), 17),
                C.blue(cat_interest(g, card))))
        else:
            out.append("  %s %s %s %s" % (
                n, pad(card["name"], 28),
                C.grey("%dt" % card.get("ticks", 1)), effect_of(card)))
    return "\n".join(out)


def effect_of(card):
    bits = []
    if card.get("appeal"):
        bits.append(C.blue("%+d Appeal" % card["appeal"]))
    if card.get("appeal_per_sale"):
        bits.append(C.blue("+%d Appeal per product taken"
                           % card["appeal_per_sale"]))
    if card.get("margin"):
        paint = C.green if card["margin"] > 0 else C.red
        bits.append(paint("%s$%s Margin" % ("+" if card["margin"] > 0 else "-",
                                            money(abs(card["margin"])))))
    if card.get("patience"):
        paint = C.green if card["patience"] > 0 else C.red
        bits.append(paint("%+d their Patience" % card["patience"]))
    if card.get("reveal"):
        bits.append(C.mag("reveals their line + top category"))
    return ", ".join(bits)


FLOOR_HELP = """
 On the floor
   A B C     go stand with that customer      [1 tick, free if you were
                                               already with them]
   x2        set hand card 2 aside and draw    [1 tick]
   card 2    read what hand card 2 does
   debug     show the hidden priority lists
   help  quit
"""

CUSTOMER_HELP = """
 With a customer
   2         play hand card 2 - a PRODUCT goes on the table   [1 tick]
             a SUPPORT card works on what is already there    [1 tick]
   offer     ask them.  FREE - and it is what sets them off
   drop      take the offer back off the table (concessions lost, free)
   close     SIGN - bank everything unsigned, they leave      [free]
   floor     step back out                                    [free]
   x2        set hand card 2 aside and draw                   [1 tick]
   card 2    read what hand card 2 does
   help  quit
"""

PRIMER = """
 ROGUE DEALERSHIP - m2

 You are the F&I desk. Every customer wants nine things in some private order
 and will not tell you what it is. Every product answers exactly one of them.

   PLACE       putting a product in front of someone costs a tick and shows
               you only how warm they look. What it is really worth depends
               on how highly they rank the thing it answers - their number
               one opens at 40, their last at 0. That is not a refusal. It
               is a price.
   BUILD       support cards push Appeal up, mostly by taking Margin out of
               your own pocket.
   THE LINE    how high Appeal has to climb before they say yes. It differs
               per customer, it rises every time they buy, and some of them
               move it when you ask and miss.
   OFFER       free, and it tells you the exact gap. It is also what makes
               them react - and every customer reacts differently. Read the
               WATCH FOR panel before you ask.
   TICKS       every card costs one, and a tick burns patience off EVERY
               customer on the floor at once.
   UNSIGNED    a customer who says yes has not paid you. Only `close` banks
               it. If their patience hits zero first, they walk out with the
               whole deal.

 Each sale makes most people a little harder to sell to, and a little more
 patient. Read them, close them, and know when to stop.
"""


def render_report(g, voice):
    rep = g.report()
    out = ["", rule(), " %s" % C.bold("CLOSING TIME"), rule()]
    verdict = (C.green("QUOTA MADE") if rep["made_quota"]
               else C.red("MISSED QUOTA"))
    out.append(" Banked          %s of $%s   %s"
               % (C.bold(C.green("$" + money(rep["margin_banked"]))),
                  money(rep["quota"]), verdict))
    out.append(" Customers       %d seen, %s signed, %s walked"
               % (rep["customers_seen"], C.green(str(rep["customers_signed"])),
                  C.red(str(rep["customers_walked"]))))
    out.append(" Asking          %d offers, %d closed (%.0f%%), %d fell short"
               % (rep["offers"], rep["sales"], 100.0 * rep["close_rate"],
                  rep["failed_offers"]))
    out.append(" Margin moved    %s conceded, %s padded on, %s in bonuses"
               % (C.red("$" + money(rep["margin_conceded"])),
                  C.green("$" + money(rep["margin_padded"])),
                  C.green("$" + money(rep["margin_bonus"]))))
    lost = rep["margin_lost_to_walks"] + rep["margin_lost_to_closing"]
    out.append(" Margin lost     %s   %s"
               % (C.bold(C.red("$" + money(lost))),
                  C.grey("($%s out the door, $%s unsigned at the bell)"
                         % (money(rep["margin_lost_to_walks"]),
                            money(rep["margin_lost_to_closing"])))))
    out.append(" They reacted    %s"
               % C.grey("%d times" % rep["actions_fired"]))
    out.append(" Where the day   %s"
               % C.grey("%d ticks placing, %d on cards, %d digging, %d walking"
                        % (rep["ticks_place"], rep["ticks_cards"],
                           rep["ticks_digs"], rep["ticks_approach"])))
    out.append(rule())
    out.append(C.grey(" Was it fun? That is the only question this build exists"
                      " to answer."))
    out.append(C.grey(" Retune m2/data/config.json and run it again."))
    return "\n".join(out)


# --------------------------------------------------------------------------
# Input
# --------------------------------------------------------------------------
DIG = re.compile(r"^x\s*(\d+)$", re.I)
NUM = re.compile(r"^(\d+)$")


def handle(g, raw, state, voice):
    """Returns a message to print, or None."""
    low = raw.strip().lower()
    inside = g.at is not None

    if low in ("q", "quit", "exit"):
        raise Quit()
    if low in ("h", "help", "?"):
        return CUSTOMER_HELP if inside else FLOOR_HELP
    if low == "debug":
        state["debug"] = not state["debug"]
        return C.mag(" debug %s" % ("ON - priority lists shown"
                                    if state["debug"] else "off"))
    if low.startswith("card"):
        try:
            card = g.hand[int(low.split()[1]) - 1]
        except (IndexError, ValueError):
            return C.red(" No such card.")
        body = textwrap.fill(card["text"], width=70,
                             initial_indent="   ", subsequent_indent="   ")
        return " %s\n%s" % (C.bold(card["name"]), C.grey(body))

    m = DIG.match(low)
    if m:
        return say(g.dig(int(m.group(1)) - 1))

    if inside:
        if low in ("f", "floor", "back", "out"):
            return say(g.leave())
        if low in ("drop", "d"):
            return say(g.drop_offer())
        if low in ("o", "offer", "ask"):
            return offered(g, voice)
        if low in ("close", "sign", "c"):
            res = g.close()
            if res.ok and res.data.get("margin"):
                return say(res) + "\n " + C.grey("\"%s\"" % voice.line("accept"))
            return say(res)
        m = NUM.match(low)
        if m:
            res = g.play_card(int(m.group(1)) - 1)
            if res.ok and res.kind == "place":
                return "%s  %s" % (say(res),
                                   BAND_COLOR.get(res.data["band"], C.grey)(
                                       res.data["band"]))
            return say(res)
        return C.red(" Try '2' (play a card), 'offer', 'drop', 'close',"
                     " 'floor', 'help'.")

    if len(low) == 1 and low.upper() in engine.CHAIR_KEYS:
        return say(g.approach(engine.CHAIR_KEYS.index(low.upper())))
    m = NUM.match(low)
    if m:
        return say(g.play_card(int(m.group(1)) - 1))
    return C.red(" Try 'A' (go talk to them), 'x2' (dig), 'help'.")


def offered(g, voice):
    cust = g.chairs[g.at] if g.at is not None else None
    res = g.offer()
    if not res.ok:
        return say(res)
    if res.kind == "sale":
        return " %s\n %s" % (C.green(res.msg),
                             C.grey("\"%s\"" % voice.line("accept")))
    label, line = voice.reaction(cust) if cust and cust.offer else ("COLD", "")
    return " %s  %s" % (BAND_COLOR.get(label, C.yellow)(line),
                        C.bold(C.yellow(res.msg)))


def say(res):
    paint = KIND_COLOR.get(res.kind, C.red)
    return " %s" % paint(res.msg)


def main():
    ap = argparse.ArgumentParser(description="Rogue Dealership - M2 prototype")
    ap.add_argument("--seed", type=int, default=None)
    ap.add_argument("--floor", default=None,
                    help="comma-separated archetype ids, e.g. hawk,karen,kicker")
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

    g = engine.Shift(catalog=cat, seed=args.seed, floor=floor)
    voice = Voice(cat, args.seed)
    state = {"debug": False}
    seen = 0
    seen_actions = 0

    print(PRIMER)
    print(FLOOR_HELP)
    try:
        while not g.over:
            if g.at is not None:
                print(render_customer(g, voice, state["debug"]))
            else:
                print(render_floor(g, voice, state["debug"]))
            print("")
            print(render_hand(g))
            for line in g.events[seen:]:
                print(C.grey("   . " + line))
            seen = len(g.events)
            if len(g.action_log) > seen_actions:
                print("")
                print(render_actions(g, seen_actions))
                seen_actions = len(g.action_log)
            print("")
            try:
                raw = input(C.bold("> "))
            except (EOFError, KeyboardInterrupt):
                raise Quit()
            msg = handle(g, raw, state, voice)
            if msg:
                print(msg)
            print("")
    except Quit:
        print(C.grey("\n You clock out early."))

    for line in g.events[seen:]:
        print(C.grey("   . " + line))
    print(render_report(g, voice))
    return 0


if __name__ == "__main__":
    sys.exit(main())
