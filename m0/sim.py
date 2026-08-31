# -*- coding: utf-8 -*-
"""
Auto Sales Executive - M0 Monte Carlo simulator.

Drives engine.py with a transparent greedy policy, so the rules measured here are
exactly the rules play.py runs.

    python sim.py                  # 2000 encounters per archetype
    python sim.py -n 5000
    python sim.py --no-bracket     # CONTROL: policy is blindfolded to what it learned
    python sim.py --risk 0.3       # how close to the known floor it dares aim
    python sim.py --verbose        # narrate one encounter per archetype

THE POLICY, in order of priority each action:
  1. counter the telegraphed objection's rider if we hold the answer
  2. keep enough Rapport banked to absorb the incoming hit
  3. spend spare Rapport on a Key Question - knowledge is the best buy-in in the game
  4. pick a line, pitch it up, then convert the excess into MARKUP
  5. offer once buy-in has been walked down to the target
It is deliberately readable rather than optimal - treat its numbers as a floor on
what a real player achieves.
"""
import argparse
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import engine  # noqa: E402

OUTCOMES = ("CLEARED", "MAXED_OUT", "TIME", "WALKED")


class Policy(engine.Encounter):
    def __init__(self, *a, **kw):
        self.risk = kw.pop("risk", 0.5)
        self.use_bracket = kw.pop("use_bracket", True)
        engine.Encounter.__init__(self, *a, **kw)

    # ---- where in our own uncertainty do we dare aim? -------------------
    def nerve(self, line):
        """How aggressive to be, given what is at stake.

        A refusal costs the product, so probing low is only worth it on something
        cheap. Stacks run cheapest-first, so this naturally means: PROBE with the
        opener, PLAY SAFE once the expensive items come up. Aiming near `lo` banks
        more markup but risks losing the sale; aiming near `hi` is a near-certain
        sale with less margin.
        """
        if not self.use_bracket:
            return self.risk
        prices = [p.sticker for p in line.stack]
        span = float(max(prices) - min(prices)) or 1.0
        dear = (line.product.sticker - min(prices)) / span       # 0 cheap .. 1 dear
        return self.risk + (1.0 - self.risk) * dear

    def target(self, line):
        """The buy-in we want to offer at. Lower = more markup banked = riskier."""
        if line.known is not None:
            return line.known
        if self.use_bracket:
            lo, hi = line.lo, line.hi
        else:
            lo, hi = 0, self.cfg["max_buyin"]      # control: never learns
        low = lo + 1
        return int(round(low + (hi - low) * self.nerve(line)))

    def gap(self, line):
        return self.target(line) - self.buyin(line)

    # ---- helpers --------------------------------------------------------
    def open_lines(self):
        return [l for l in self.lines.values() if self.workable(l)]

    def playable(self, pred, line_name=None):
        return [c for c in self.hand if pred(c) and self.can_play(c, line_name)]

    def best_line(self):
        """Finish what is closest to done; otherwise take the cheapest information."""
        open_ = self.open_lines()
        if not open_:
            return None
        ready = [l for l in open_ if self.buyin(l) >= self.target(l)]
        if ready:
            return max(ready, key=lambda l: self.price(l))
        return min(open_, key=lambda l: (self.gap(l), l.product.sticker))

    def choose_action(self, objection, damage):
        cfg = self.cfg

        # 1. answer the rider - the counter card also pays rapport
        if objection and objection.get("rider") and not self.countered:
            ctr = self.playable(lambda c: self.counters_it(c, objection))
            if ctr:
                return ("card", ctr[0], None)

        # 2. bank enough rapport to eat the incoming hit
        incoming = damage if objection else 0
        if self.rapport < incoming:
            rap = self.playable(lambda c: c.get("rapport") and not c.get("counters"))
            if rap:
                best = max(rap, key=lambda c: c.get("rapport") / max(c.cost, 0.5))
                return ("card", best, None)

        # 3. knowledge - the most efficient buy-in in the game, but it spends the same
        #    rapport that absorbs objections.
        kq = self.playable(lambda c: c.get("knowledge"))
        if kq and self.rapport - kq[0].get("rapport_cost", 0) >= incoming:
            return ("card", kq[0], None)

        line = self.best_line()
        if line is None:
            return ("end", None)

        buy = self.buyin(line)
        tgt = self.target(line)
        step_cost = cfg["buyin_per_step"] * self.c.balk
        pitches = self.playable(lambda c: c.get("buyin"), line.name)

        # Buy-in above the target is money not yet collected, so overshoot deliberately
        # and convert the excess into price. HOW FAR we dare overshoot depends on how
        # well we know this line: a tight bracket means we can pitch high and mark down
        # onto their number precisely. That is the learning loop paying off.
        ups = self.playable(lambda c: c.get("markup", 0) > 0, line.name)
        downs = self.playable(lambda c: c.get("markup", 0) < 0, line.name)
        room = int(cfg["markup_max"] / cfg["markup_step"]) - int(round(line.markup / cfg["markup_step"]))
        holding = sum(c.get("markup") / cfg["markup_step"] for c in ups)
        want = tgt + step_cost * max(0, min(room, holding))

        # 4a. build headroom worth converting
        if buy < want and pitches:
            best = max(pitches, key=lambda c: c.get("buyin") / max(c.cost, 0.5))
            return ("card", best, line.name)

        # 4b. convert excess buy-in into money - but only if we HOLD a markup card
        for c in sorted(ups, key=lambda c: -c.get("markup")):
            cost = c.get("markup") / cfg["markup_step"] * step_cost
            if buy - cost >= tgt:
                return ("card", c, line.name)

        # 4c. at or above target: take the deal
        if buy >= tgt:
            return ("offer", line.name)

        # 4d. overpriced and short - discount back into range if we hold the card
        if line.markup > 0 and downs:
            return ("card", downs[0], line.name)

        # 4e. still short: keep pitching
        if pitches:
            best = max(pitches, key=lambda c: c.get("buyin") / max(c.cost, 0.5))
            return ("card", best, line.name)

        # 4d. cannot reach the target - discount into range if that is cheap
        downs = self.playable(lambda c: c.get("markup", 0) < 0, line.name)
        if downs and line.markup > 0:
            return ("card", downs[0], line.name)

        # nothing productive left; if we are close and patience is bleeding, gamble
        if buy > line.lo and self.patience <= cfg["refusal_patience"] * 2:
            return ("offer", line.name)

        free = self.playable(lambda c: c.cost == 0 and (c.get("rapport") or c.get("draw")))
        if free:
            return ("card", free[0], None)
        return ("end", None)


class Naive(engine.Encounter):
    """A player who is not thinking: dump the whole hand every turn, then offer at
    sticker whenever buy-in looks respectable.

    This is the control that catches 'too easy'. If dumping your hand does about as
    well as playing carefully, the game is not asking you anything.
    """
    def choose_action(self, objection, damage):
        for card in list(self.hand):
            for ln in [None] + list(engine.LINES):
                if self.needs_target(card) and ln is None:
                    continue
                if not self.needs_target(card) and ln is not None:
                    continue
                if self.can_play(card, ln):
                    return ("card", card, ln)
        for name in engine.LINES:
            line = self.lines[name]
            if self.workable(line) and self.buyin(line) >= 12:
                return ("offer", name)
        return ("end", None)


# ------------------------------------------------------------------ driver
def summarise(results):
    n = float(len(results))
    out = dict((o, 0) for o in OUTCOMES)
    sold = perfect = rev = comm = refus = turns = 0.0
    pos_markup = {0: [], 1: [], 2: []}
    for r in results:
        out[r["outcome"]] += 1
        sold += r["sold"]
        perfect += r["perfect"]
        rev += r["revenue"]
        comm += r["commission"]
        refus += r["refusals"]
        turns += r["turns"]
        for i, m in r["by_position"].items():
            pos_markup[i].extend(m)
    avg = lambda xs: (sum(xs) / len(xs)) if xs else 0.0
    return {
        "cleared": 100 * out["CLEARED"] / n, "time": 100 * out["TIME"] / n,
        "maxed": 100 * out["MAXED_OUT"] / n,
        "walked": 100 * out["WALKED"] / n,
        "sold": sold / n, "perfect": perfect / n, "revenue": rev / n,
        "commission": comm / n, "refusals": refus / n, "turns": turns / n,
        "m0": avg(pos_markup[0]), "m1": avg(pos_markup[1]), "m2": avg(pos_markup[2]),
        "take": sum(r["take"] for r in results) / n,
        "unspent": sum(r["unspent_energy"] for r in results) / n,
        "cards_left": sum(r["cards_left"] for r in results) / n,
    }


def by_position(enc):
    """Markup fraction banked, split by how deep in the stack the product sat."""
    out = {0: [], 1: [], 2: []}
    for line in enc.lines.values():
        for i, (p, price, _) in enumerate(line.sold):
            if i in out:
                # scaled sticker, or price_scale masquerades as markup
                out[i].append(float(price) / p.sticker - 1.0)
    return out


def run_batch(cust, deck, data, cfg, runs, seed, risk, use_bracket, verbose=False):
    rng = random.Random(seed)
    results = []
    for i in range(runs):
        enc = Policy(cust, deck, data, cfg=cfg, rng=rng,
                     risk=risk, use_bracket=use_bracket)
        r = enc.run()
        r["by_position"] = by_position(enc)
        results.append(r)
    return results


def main():
    ap = argparse.ArgumentParser(description="M0 simulator")
    ap.add_argument("-n", "--runs", type=int, default=2000)
    ap.add_argument("--seed", type=int, default=1234)
    ap.add_argument("--risk", type=float, default=0.5)
    ap.add_argument("--no-bracket", action="store_true",
                    help="CONTROL: blindfold the policy to everything it learned")
    ap.add_argument("--copies", type=int, default=2)
    ap.add_argument("--naive", action="store_true",
                    help="CONTROL: a player who just dumps their hand every turn")
    args = ap.parse_args()

    data = engine.load_data()
    deck = engine.starter_deck(data["cards"], args.copies)
    cfg = {}

    print("=" * 104)
    print("AUTO SALES EXECUTIVE - M0 SIMULATION" +
          ("   [NO-BRACKET CONTROL]" if args.no_bracket else ""))
    print("=" * 104)
    print("Deck %d cards | %d runs each | risk %.2f | %d energy/turn | %d turns"
          % (len(deck), args.runs, args.risk, engine.DEFAULT_CFG["energy_per_turn"],
             engine.DEFAULT_CFG["max_turns"]))
    print()
    hdr = ("%-17s %8s %8s %7s %7s %10s %7s %8s %9s   %s" %
           ("Archetype", "Tapped", "Walked", "Sold/6", "Perfect", "Commission",
            "Take", "Unspent", "Cards-left", "markup by stack position"))
    print(hdr)
    print("-" * len(hdr))

    for cust in data["customers"]:
        if args.naive:
            rng = random.Random(args.seed)
            res = []
            for _ in range(args.runs):
                e = Naive(cust, deck, data, cfg=cfg, rng=rng)
                r = e.run()
                r["by_position"] = by_position(e)
                res.append(r)
        else:
            res = run_batch(cust, deck, data, cfg, args.runs, args.seed,
                            args.risk, not args.no_bracket)
        s = summarise(res)
        print("%-17s %7.1f%% %7.1f%% %6.1f %7.2f %10s %6.0f%% %8.2f %9.2f   %s"
              % (cust.name, s["maxed"], s["walked"], s["sold"], s["perfect"],
                 "$%s" % format(int(s["commission"]), ","), 100 * s["take"],
                 s["unspent"], s["cards_left"],
                 "1st %+.1f%%  2nd %+.1f%%  3rd %+.1f%%"
                 % (100 * s["m0"], 100 * s["m1"], 100 * s["m2"])))

    print()
    print("READ IT LIKE THIS")
    print("  Markup by stack position is THE number: it should RISE from 1st to 3rd.")
    print("  That is the learning loop paying off - early products buy information,")
    print("  later ones spend it. If it is flat, the bracket is decoration.")
    print("  Unspent-e and Cards-left are the DECISION DENSITY check: if energy is left")
    print("  over and cards go unplayed, the turn asked you something. If both are ~0,")
    print("  you are just dumping your hand and there is no game.")
    print("  Compare against:  python sim.py --no-bracket   and   python sim.py --naive")


if __name__ == "__main__":
    main()
