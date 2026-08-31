# -*- coding: utf-8 -*-
"""
Auto Sales Executive - M0 playable prototype.

    python play.py
    python play.py --customer "Tech Enthusiast" --seed 7
    python play.py --no-color

Drives engine.py, exactly like sim.py does, so what you play is what the simulator
measured. Buy-In is how close they are to yes. Pitching raises it, charging more
lowers it, and their number is hidden - go find it.
"""
import argparse
import os
import random
import sys

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
    def dim(cls, s): return cls._w("2", s)
    @classmethod
    def bold(cls, s): return cls._w("1", s)
    @classmethod
    def red(cls, s): return cls._w("91", s)
    @classmethod
    def green(cls, s): return cls._w("92", s)
    @classmethod
    def yellow(cls, s): return cls._w("93", s)
    @classmethod
    def blue(cls, s): return cls._w("96", s)
    @classmethod
    def mag(cls, s): return cls._w("95", s)
    @classmethod
    def grey(cls, s): return cls._w("90", s)


LANE_COL = {"vehicle": C.blue, "protection": C.green, "financing": C.mag}


def money(v):
    return "$%s" % format(int(round(v)), ",")


def bar(frac, width=16, fill="#", empty="-"):
    frac = max(0.0, min(1.0, frac))
    n = int(round(width * frac))
    return fill * n + empty * (width - n)


def rider_desc(o):
    if not o or not o.get("rider"):
        return C.dim("no rider - just patience damage")
    r, amt, ln = o.get("rider"), o.get("amount", 1), o.get("line")
    return {
        "raise_threshold": "pushes their %s number UP by %d" % (ln, amt),
        "lock_line": "LOCKS the %s line next turn" % ln,
        "drain_energy": "costs you %d energy next turn" % amt,
        "knock_buyin": "knocks %d buy-in off %s" % (amt, ln),
    }.get(r, r)


class Game(engine.Encounter):
    def __init__(self, *a, **kw):
        engine.Encounter.__init__(self, *a, **kw)
        self.msgs = []
        self._obj = None
        self._dmg = 0

    # ------------------------------------------------------------ display
    def bracket_line(self, line):
        if line.known is not None:
            return C.green(C.bold("their number is EXACTLY %d" % line.known))
        lo, hi = line.lo, line.hi
        wide = hi >= self.cfg["max_buyin"] and lo <= 0
        if wide:
            return C.dim("their number: no idea yet")
        parts = []
        if lo > 0:
            parts.append("more than %d" % lo)
        if hi < self.cfg["max_buyin"]:
            parts.append("%d or less" % hi)
        return C.yellow("their number: " + " and ".join(parts))

    def card_line(self, i, card):
        afford = card.cost <= self.energy and card.get("rapport_cost", 0) <= self.rapport
        num = "%2d)" % i
        name = "%-20s" % card.name
        if not afford:
            why = "need %d rapport" % card.get("rapport_cost") if card.get("rapport_cost", 0) > self.rapport else "no energy"
            return C.grey("%s %s %de  (%s)" % (num, name, card.cost, why))
        bits = []
        if card.get("buyin"):
            tag = " on %s" % card.get("line") if card.get("line") else ""
            bits.append(C.bold("+%d buy-in" % card.get("buyin")) + tag)
        if card.get("rapport"):
            bits.append(C.yellow("+%d rapport" % card.get("rapport")))
        if card.get("knowledge"):
            bits.append(C.green(C.bold("ASK A KEY QUESTION")) + C.dim(" (-%d rapport)" % card.get("rapport_cost", 0)))
        if card.get("counters"):
            hot = self._obj is not None and self.counters_it(card, self._obj)
            t = "answers %s objections" % card.get("counters")
            bits.append(C.green(C.bold(t)) if hot else C.dim(t))
        if card.get("narrow"):
            bits.append(C.yellow("narrow their number down"))
        if card.get("draw"):
            bits.append("draw %d" % card.get("draw"))
        if card.get("markup"):
            bits.append("price %+d%%" % int(card.get("markup") * 100))
        if card.get("patience_cost"):
            bits.append(C.red("-%d patience" % card.get("patience_cost")))
        return "%s %s %s  %s" % (num, name, C.bold("%de" % card.cost), C.dim(" | ").join(bits))

    def show(self):
        os.system("cls" if os.name == "nt" else "clear")
        c = self.c
        print(C.bold("=" * 84))
        pf = self.patience / float(c.patience)
        pc = C.green if pf > .5 else (C.yellow if pf > .25 else C.red)
        print(C.bold("  " + c.name.upper()) +
              "      patience " + pc(bar(pf) + " %d" % max(0, self.patience)) +
              "   rapport " + C.yellow(str(self.rapport)) +
              C.dim("   balks %.1fx" % c.balk))
        banked, wallet = self.revenue(), int(self.c.budget)
        left = self.remaining_budget()
        pct = (100.0 * banked / wallet) if wallet else 0
        lc = C.green if left > wallet * .5 else (C.yellow if left > wallet * .2 else C.red)
        print("  banked " + C.bold(C.green(money(banked))) +
              "   their wallet " + lc(money(left) + " left") +
              C.dim(" of %s" % money(wallet)) +
              "   " + C.bold("%.0f%%" % pct) +
              C.dim("   commission %s" % money(self.commission())))
        print(C.bold("=" * 84))

        for name in engine.LINES:
            line = self.lines[name]
            col = LANE_COL[name]
            tally = C.dim("  [%d sold, %d lost]" % (len(line.sold), len(line.lost)))
            if line.done:
                print("  %-12s %s%s" % (col(name.upper()), C.dim("stack finished"), tally))
                continue
            p = line.product
            mk = ("  %+d%%" % int(round(line.markup * 100))) if line.markup else ""
            lock = C.red("  LOCKED THIS TURN") if self.locked(line) else ""
            print("  %-12s %s %-20s %s%s%s"
                  % (col(name.upper()), C.dim(">"), p.name,
                     C.bold(money(self.price(line))), C.yellow(mk), lock))
            print("               buy-in %s   %s%s%s"
                  % (C.bold("%2d" % self.buyin(line)), self.bracket_line(line), tally,
                     C.dim("  %s left in this stack" % money(line.remaining()))))
        print(C.dim("-" * 84))

        head = C.bold("  TURN %d" % self.turn) + "   energy " + C.yellow("*" * self.energy)
        print(head)
        if self.severity == "quiet" or self._obj is None:
            print("  " + C.green(C.bold("THEY'RE JUST LISTENING.")) +
                  C.dim("  Nothing coming this turn - a free one."))
        else:
            resid = max(0, self._dmg - self.rapport)
            tag = {"heavy": C.red(C.bold("  [HEAVY]")),
                   "rider": C.red(C.bold("  [AND A RIDER]"))}.get(self.severity, "")
            print("  " + C.red(C.bold('THEY WILL SAY: "%s"' % self._obj.name)) +
                  C.dim("   %d damage" % round(self._dmg)) + tag)
            if self.severity == "rider":
                print("     " + C.red(rider_desc(self._obj)))
            print("     " + (C.green("your %d rapport absorbs it" % self.rapport) if resid <= 0
                             else C.red("%d will get through to patience" % resid)))
        print(C.dim("-" * 84))
        for i, card in enumerate(self.hand, 1):
            print("  " + self.card_line(i, card))
        print(C.dim("     deck %d  discard %d" % (len(self.deck), len(self.discard))))
        for m in self.msgs:
            print("  " + m)
        self.msgs = []

    # -------------------------------------------------------------- input
    def pick_line(self, prompt, only_open=True):
        opts = [n for n in engine.LINES if (self.workable(self.lines[n]) or not only_open)]
        if not opts:
            self.msgs.append(C.red("No line is available."))
            return None
        print()
        for i, n in enumerate(opts, 1):
            l = self.lines[n]
            print("     %d) %-11s %-20s buy-in %2d   %s"
                  % (i, LANE_COL[n](n), l.product.name if l.product else "-",
                     self.buyin(l), self.bracket_line(l)))
        raw = input("     %s > " % prompt).strip()
        if raw.isdigit() and 1 <= int(raw) <= len(opts):
            return opts[int(raw) - 1]
        return None

    def choose_action(self, objection, damage):
        self._obj, self._dmg = objection, damage
        while True:
            self.show()
            print()
            opts = ["[1-%d] play" % len(self.hand), C.bold("[o#] OFFER"),
                    "[k] skip", "[e] end turn", C.dim("[q] quit")]
            raw = input("  " + "  ".join(opts) + "\n  > ").strip().lower()

            if raw in ("q", "quit"):
                raise Quit()
            if raw in ("", "e"):
                return ("end", None)
            if raw.startswith("o"):
                # 'o2' offers line 2 outright; bare 'o' asks which
                rest = raw[1:].strip()
                names = [n for n in engine.LINES if self.workable(self.lines[n])]
                if rest.isdigit() and 1 <= int(rest) <= len(names):
                    return ("offer", names[int(rest) - 1])
                ln = self.pick_line("offer which line?")
                if ln:
                    return ("offer", ln)
                continue
            if raw == "k":
                ln = self.pick_line("give up on which line?")
                if ln:
                    return ("skip", ln)
                continue
            if not raw.isdigit():
                continue
            i = int(raw)
            if not (1 <= i <= len(self.hand)):
                continue
            card = self.hand[i - 1]
            ln = None
            if self.needs_target(card):
                ln = card.get("line") or self.pick_line("on which line?")
                if ln is None:
                    continue
            if not self.can_play(card, ln):
                self.msgs.append(C.red("Cannot play %s right now." % card.name))
                continue
            return ("card", card, ln)

    # --------------------------------------------------------------- hooks
    def on_turn_start(self, objection, damage):
        self._obj, self._dmg = objection, damage

    def on_action(self, action, card, line_name, note):
        if card is not None and card.get("knowledge") and note is not None:
            self.msgs.append(C.green(C.bold("  YOU LEARN: %s" % note.name)) +
                             C.dim("  \"%s\"" % note.flavour))
            self.msgs.append(C.green("  +%d buy-in on %s - knowledge ignores the pitch ceiling"
                                     % (note.buyin, note.line)))
        elif card is not None and card.get("narrow") and note is not None:
            self.msgs.append(C.yellow("  You read them: their number is %s %d" % note))

    def on_offer_result(self, line, result, product, price, buyin, threshold):
        if result == "PERFECT":
            self.msgs.append(C.green(C.bold(
                "  PERFECT PITCH on %s for %s - their number was exactly %d."
                % (product.name, money(price), threshold))))
        elif result == "SOLD":
            self.msgs.append(C.green("  SOLD %s for %s." % (product.name, money(price))) +
                             C.dim("  (buy-in %d cleared it - you know it is %d or less)"
                                   % (buyin, buyin)))
        else:
            self.msgs.append(C.red("  REFUSED. %s is gone." % product.name) +
                             C.dim("  (buy-in %d was not enough - their number is above %d)"
                                   % (buyin, buyin)))

    def on_turn_end(self, objection, damage, absorbed, taken, countered):
        if not objection:
            return
        print()
        print("  " + C.dim('"%s"' % objection.name))
        if countered:
            print("  " + C.green("You answered it - the rider never landed."))
        if taken <= 0:
            print("  " + C.green("Rapport absorbed the whole thing."))
        else:
            print("  " + C.red("They lose patience: -%d" % round(taken)))
            if objection.get("rider") and not countered:
                print("  " + C.red("RIDER LANDS: " + rider_desc(objection)))
        if self.patience > 0 and not self.all_done():
            input(C.dim("\n  [enter] next turn "))


def summary(res, g):
    print()
    print(C.bold("=" * 84))
    if res["outcome"] == "WALKED":
        print(C.red(C.bold("  THEY WALKED OUT.")))
    elif res["outcome"] == "MAXED_OUT":
        print(C.green(C.bold("  TAPPED OUT - you got every dollar they had.")))
        if res["revenue"] > g.c.budget:
            print(C.green("  And then some: %s out of a %s wallet."
                          % (money(res["revenue"]), money(g.c.budget))))
    elif res["outcome"] == "CLEARED":
        print(C.green(C.bold("  EVERY LINE RESOLVED.")))
    else:
        print(C.yellow(C.bold("  TIME'S UP - they had to go.")))
    print("  Sold %d of %d products   revenue %s   commission %s"
          % (res["sold"], res["total"], money(res["revenue"]),
             C.bold(money(res["commission"]))))
    print("  Perfect pitches %d   refused %d   average markup %+.0f%%"
          % (res["perfect"], res["refusals"], 100 * res["markup"]))
    for n in engine.LINES:
        line = g.lines[n]
        T = g.threshold(line)
        got = ", ".join(p.name for p, _, _ in line.sold) or "nothing"
        print("  %-11s %s" % (LANE_COL[n](n), C.dim("their number was %d  |  sold: %s" % (T, got))))
    print(C.bold("=" * 84))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--customer")
    ap.add_argument("--seed", type=int)
    ap.add_argument("--no-color", action="store_true")
    args = ap.parse_args()

    C.on = (not args.no_color) and _enable_ansi()
    data = engine.load_data()
    deck = engine.starter_deck(data["cards"], 2)

    while True:
        cust = None
        if args.customer:
            for c in data["customers"]:
                if c.name.lower() == args.customer.lower():
                    cust = c
        if cust is None:
            os.system("cls" if os.name == "nt" else "clear")
            print(C.bold("\n  AUTO SALES EXECUTIVE") + C.dim("   M0 prototype\n"))
            print(C.dim("  Buy-In is how close they are to yes. Pitching raises it,"))
            print(C.dim("  charging more lowers it. Their number is hidden.\n"))
            for i, c in enumerate(data["customers"], 1):
                print("  %d) %-17s patience %-4s balks %.1fx" % (i, c.name, int(c.patience), c.balk))
                print(C.dim("     %s" % c.flavour))
            raw = input("\n  who walks in? [1-%d, q] > " % len(data["customers"])).strip().lower()
            if raw in ("q", "quit"):
                return
            if not (raw.isdigit() and 1 <= int(raw) <= len(data["customers"])):
                continue
            cust = data["customers"][int(raw) - 1]

        seed = args.seed if args.seed is not None else random.randrange(1 << 30)
        g = Game(cust, deck, data, rng=random.Random(seed))
        try:
            res = g.run()
        except Quit:
            print(C.dim("\n  you walked off the floor. fair enough.\n"))
            return
        except (KeyboardInterrupt, EOFError):
            print()
            return
        summary(res, g)
        print(C.dim("  seed %d" % seed))
        if input("\n  another? [y/N] > ").strip().lower() != "y":
            return
        args.customer = None


if __name__ == "__main__":
    main()
