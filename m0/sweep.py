# -*- coding: utf-8 -*-
"""
Auto Sales Executive - M0 balance sweep.

Varies one lever at a time so you can see which knob actually moves the game.

    python sweep.py            # all sweeps
    python sweep.py --quick

Columns: Sold/9 | Perfect | Refused | Commission | Markup% | Walked%
"""
import argparse
import copy
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import engine  # noqa: E402
import sim     # noqa: E402


def trial(data, deck, runs, seed=1234, risk=0.5, use_bracket=True,
          cfg_over=None, patience_x=1.0, damage_x=1.0, thresh_d=0):
    cfg = dict(cfg_over or {})
    objs = data["objections"]
    if damage_x != 1.0:
        objs = {}
        for k, o in data["objections"].items():
            o2 = copy.copy(o)
            o2.damage = o.damage * damage_x
            objs[k] = o2
    d2 = dict(data)
    d2["objections"] = objs

    rows = []
    for cust in data["customers"]:
        cu = copy.copy(cust)
        cu.patience = cust.patience * patience_x
        cu.thresholds = dict((k, v + thresh_d) for k, v in cust.thresholds.items())
        rng = random.Random(seed)
        res = []
        for _ in range(runs):
            e = sim.Policy(cu, deck, d2, cfg=cfg, rng=rng, risk=risk, use_bracket=use_bracket)
            r = e.run()
            r["by_position"] = sim.by_position(e)
            res.append(r)
        rows.append(sim.summarise(res))
    return rows


def show(label, rows):
    cells = []
    for s in rows:
        cells.append("%3.1f %4.2f %4.1f $%-5d %4.1f%% %4.0f%%"
                     % (s["sold"], s["perfect"], s["refusals"], s["commission"],
                        100 * s["m0"], s["walked"]))
    print("%-30s %s" % (label, " | ".join(cells)))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--quick", action="store_true")
    ap.add_argument("--runs", type=int, default=900)
    args = ap.parse_args()
    runs = 300 if args.quick else args.runs

    data = engine.load_data()
    deck = engine.starter_deck(data["cards"], 2)

    print("Sold/9  Perfect  Refused  Commission  Markup  Walked      (%d runs)" % runs)
    print("%-30s %s" % ("", " | ".join("%-31s" % c.name for c in data["customers"])))
    print("-" * 132)

    show("BASELINE (risk 0.50)", trial(data, deck, runs))
    print()
    print("--- lever 1: nerve (how close to the known floor we dare aim) ---")
    for r in (0.2, 0.35, 0.5, 0.65, 0.8):
        show("risk %.2f" % r, trial(data, deck, runs, risk=r))

    print()
    print("--- lever 2: what a refusal costs in patience ---")
    for v in (2, 4, 7):
        show("refusal_patience %d" % v, trial(data, deck, runs, cfg_over={"refusal_patience": v}))

    print()
    print("--- lever 3: objection damage ---")
    for v in (0.7, 1.0, 1.3):
        show("objection damage x%.1f" % v, trial(data, deck, runs, damage_x=v))

    print()
    print("--- lever 4: patience ---")
    for v in (0.8, 1.0, 1.25):
        show("patience x%.2f" % v, trial(data, deck, runs, patience_x=v))

    print()
    print("--- lever 5: how far markup may be pushed ---")
    for v in (0.4, 0.6, 0.9):
        show("markup_max %.1f" % v, trial(data, deck, runs, cfg_over={"markup_max": v}))

    print()
    print("--- lever 6: turn budget ---")
    for v in (12, 15, 18):
        show("max_turns %d" % v, trial(data, deck, runs, cfg_over={"max_turns": v}))

    print()
    print("--- CONTROL: same policy, blindfolded to everything it learns ---")
    show("with bracket (risk 0.50)", trial(data, deck, runs, risk=0.5))
    show("NO bracket   (risk 0.50)", trial(data, deck, runs, risk=0.5, use_bracket=False))


if __name__ == "__main__":
    main()
