# -*- coding: utf-8 -*-
"""
Arithmetic checks for engine.py. Run before trusting any simulation output.

    python test_engine.py
"""
import random
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import engine  # noqa: E402

DATA = engine.load_data()
CUST = dict((c.id, c) for c in DATA["customers"])
CARDS = dict((c.id, c) for c in DATA["cards"])

PASS, FAIL = [], []


def check(name, got, want):
    if got == want:
        PASS.append(name)
    else:
        FAIL.append("%s\n     got  %r\n     want %r" % (name, got, want))


def close(name, got, want, tol=1e-6):
    if abs(got - want) <= tol:
        PASS.append(name)
    else:
        FAIL.append("%s\n     got  %r\n     want %r" % (name, got, want))


def enc(cust_id="family_first", cfg=None):
    return engine.Encounter(CUST[cust_id], engine.starter_deck(DATA["cards"]), DATA,
                            cfg=cfg, rng=random.Random(1), seed_shuffle=False)


class Scripted(engine.Encounter):
    """Drives run() from a fixed list of actions per turn."""
    def __init__(self, script, *a, **kw):
        engine.Encounter.__init__(self, *a, **kw)
        self.script = list(script)

    def choose_action(self, objection, damage):
        if not self.script:
            return ("end", None)
        return self.script.pop(0)


# --------------------------------------------------------------- buy-in math
e = enc()
prot = e.lines["protection"]
check("stack starts on the cheapest product", prot.product.id, "paint_protect")
check("base buy-in read from product", e.buyin(prot), 6)

prot.pitch = 8.0
check("pitch adds to buy-in (6 + 8)", e.buyin(prot), 14)

# pitching is unbounded - the cost of over-pitching is tempo, not a wall
prot.pitch = 40.0
check("pitching is not capped", e.buyin(prot), min(6 + 40, engine.DEFAULT_CFG["max_buyin"]))
prot.pitch = 8.0

STEP = engine.DEFAULT_CFG["buyin_per_step"]     # derive, so retuning cannot rot these

prot.markup = 0.10
close("markup penalty = steps x buyin_per_step x balk", e.markup_penalty(prot), 1 * STEP * 1.4)
check("+10% markup lowers buy-in", e.buyin(prot), int(round(14 - 1 * STEP * 1.4)))

prot.markup = 0.25
close("+25% markup costs 2.5 steps", e.markup_penalty(prot), 2.5 * STEP * 1.4)
check("+25% markup lowers buy-in further", e.buyin(prot), int(round(14 - 2.5 * STEP * 1.4)))

e2 = enc("tech_enthusiast")           # balk 1.0
p2 = e2.lines["protection"]
p2.pitch = 8.0
p2.markup = 0.10
close("balk 1.0 makes markup cheaper", e2.markup_penalty(p2), 1 * STEP * 1.0)

e3 = enc("budget_buyer")              # balk 2.0
p3 = e3.lines["protection"]
p3.pitch = 8.0
p3.markup = 0.10
close("balk 2.0 makes markup hurt double", e3.markup_penalty(p3), 1 * STEP * 2.0)
close("balk is exactly the ratio between them",
      e3.markup_penalty(p3) / e2.markup_penalty(p2), 2.0)

check("price = sticker x (1 + markup), same for everyone", e3.price(p3),
      int(round(900 * 1.10)))

prot.markup = -0.10
check("discount raises buy-in above raw", e.buyin(prot), int(round(14 + 1 * STEP * 1.4)))

# ------------------------------------------------------------ offer outcomes
# Stacks are 2 deep now, so a refusal + a sale finishes a line.
e = enc()
line = e.lines["protection"]
T = e.threshold(line)
BASE = line.product.base_buyin

line.pitch = float(T - BASE - 1)            # one under their number
res, price, eff, _ = e.offer(line)
check("buy-in below T is refused", res, "REFUSED")
check("refusal records a floor", line.lo, T - 1)
check("a refusal COSTS you the product", line.product.id, "extended_warranty")
check("the refused product is recorded as lost", len(line.lost), 1)
close("refusal costs patience", e.patience,
      CUST["family_first"].patience - engine.DEFAULT_CFG["refusal_patience"])

line.pitch = float(T - BASE + 1)            # one over
res, price, eff, _ = e.offer(line)
check("buy-in above T sells", res, "SOLD")
check("sale records a ceiling", line.hi, T + 1)
check("bracket now brackets T from BOTH sides", (line.lo, line.hi), (T - 1, T + 1))
check("a 2-deep stack is finished after two offers", line.done, True)

# perfect pitch, on a line we have not touched
e = enc()
veh = e.lines["vehicle"]
Tv = e.threshold(veh)
veh.pitch = float(Tv - veh.product.base_buyin)
res, price, eff, revealed = e.offer(veh)
check("exact hit is a perfect pitch", res, "PERFECT")
check("perfect pitch reveals T", veh.known, Tv)
check("perfect pitch reports the number", revealed, Tv)
check("perfect pitch is counted", e.perfect_pitches, 1)

# ----------------------------------------------- bracket persists per LINE only
e = enc()
prot, veh = e.lines["protection"], e.lines["vehicle"]
prot.pitch = float(e.threshold(prot) - prot.product.base_buyin - 1)
e.offer(prot)
check("floor set on protection", prot.lo, e.threshold(prot) - 1)
check("vehicle bracket untouched", (veh.lo, veh.hi), (0, engine.DEFAULT_CFG["max_buyin"]))

# ------------------------------------------------------------ narrow (1 bit)
e = enc()
line = e.lines["protection"]
T = e.threshold(line)
MAXB = engine.DEFAULT_CFG["max_buyin"]
mid1 = (0 + 1 + MAXB) // 2
out = e.narrow(line)
check("narrow reports which side of the midpoint T is on",
      out, ("<=", mid1) if T <= mid1 else (">", mid1))
check("narrow never excludes the real T", line.lo < T <= line.hi, True)

# --------------------------------------------------------- severity roll
e = enc()
weights = engine.DEFAULT_CFG["severity_weights"]
rolls = [e.roll_severity() for _ in range(200)]
check("every roll is a known severity",
      all(r in weights for r in rolls), True)

# a quiet turn deals nothing at all
cust = CUST["family_first"]
ONE = {"max_turns": 1, "severity_weights": {"quiet": 1}}
e = Scripted([("end", None)], cust, engine.starter_deck(DATA["cards"]), DATA,
             cfg=ONE, rng=random.Random(1), seed_shuffle=False)
e.run()
check("a quiet turn costs no patience", e.patience, float(cust.patience))
check("a quiet turn is recorded as quiet", e.severity, "quiet")

# heavy is exactly 1.5x, and it is the ONLY thing that differs
base_pool = cust.objection_pool
cust.objection_pool = ["price_objection"]
try:
    dmg = {}
    for sev in ("standard", "heavy"):
        e = Scripted([("end", None)], cust, engine.starter_deck(DATA["cards"]), DATA,
                     cfg={"max_turns": 1, "severity_weights": {sev: 1}},
                     rng=random.Random(1), seed_shuffle=False)
        e.run()
        dmg[sev] = cust.patience - e.patience
    close("heavy deals exactly the heavy multiplier", dmg["heavy"],
          dmg["standard"] * engine.DEFAULT_CFG["heavy_multiplier"])

    # riders fire ONLY on a rider roll
    cust.objection_pool = ["talk_to_spouse"]        # rider: drain_energy
    for sev, expect in (("standard", 0), ("heavy", 0), ("rider", 1)):
        e = Scripted([("end", None)], cust, engine.starter_deck(DATA["cards"]), DATA,
                     cfg={"max_turns": 1, "severity_weights": {sev: 1}},
                     rng=random.Random(1), seed_shuffle=False)
        e.run()
        check("rider fires only on a rider roll (%s)" % sev, e.drain_next, expect)
finally:
    cust.objection_pool = base_pool

# ------------------------------------------------- rapport absorbs, then patience
# talk_to_spouse deals 4 at turn 1. Give rapport 2 -> 2 absorbed, 2 to patience.
cust = CUST["family_first"]
cust_pool = cust.objection_pool
cust.objection_pool = ["talk_to_spouse"]
TTS = DATA["objections"]["talk_to_spouse"].damage
try:
    ONE = {"max_turns": 1}
    e = Scripted([("end", None)], cust, engine.starter_deck(DATA["cards"]), DATA,
                 cfg=ONE, rng=random.Random(1), seed_shuffle=False)
    e.rapport = 2
    e.run()
    check("rapport absorbed first", e.rapport, 0)
    close("only the overflow hit patience", e.patience, cust.patience - (TTS - 2))

    e = Scripted([("end", None)], cust, engine.starter_deck(DATA["cards"]), DATA,
                 cfg=ONE, rng=random.Random(1), seed_shuffle=False)
    e.rapport = 10
    e.run()
    check("enough rapport blocks it entirely", e.rapport, 10 - TTS)
    close("patience untouched when fully absorbed", e.patience, cust.patience)
finally:
    cust.objection_pool = cust_pool

# ------------------------------------------------------ knowledge costs rapport
e = enc()
e.energy = 5
kq = CARDS["key_question"]
e.rapport = kq.get("rapport_cost", 0)
e.hand = [kq]
check("key question blocked without rapport", enc().can_play(kq, None), False)
check("key question allowed with rapport", e.can_play(kq, None), True)
before = sum(l.kpitch for l in e.lines.values())
note = e.play(kq, None)
check("rapport spent", e.rapport, 0)
after = sum(l.kpitch for l in e.lines.values())
check("knowledge card added buy-in, bypassing the cap", after > before, True)
check("knowledge card was returned for display", note is not None, True)

# ------------------------------------------------------------------- skip
e = enc()
line = e.lines["vehicle"]
first = line.product.id
e.skip(line)
check("skip advances the stack", line.product.id != first, True)
check("skip banks nothing", len(line.sold), 0)

# --------------------------------------------------------------------- riders
e = enc()
o = DATA["objections"]["competitor_quote"]
before_T = e.threshold(e.lines["vehicle"])
e._apply_rider(o)
check("raise_threshold pushes T up", e.threshold(e.lines["vehicle"]), before_T + 2)

e = enc()
e.turn = 3
e._apply_rider(DATA["objections"]["dont_need_extras"])
check("lock_line locks next turn", e.lines["protection"].locked_turn, 4)
e.turn = 4
check("locked line is not workable", e.workable(e.lines["protection"]), False)

e = enc()
e._apply_rider(DATA["objections"]["talk_to_spouse"])
check("drain_energy set for next turn", e.drain_next,
      DATA["objections"]["talk_to_spouse"].amount)

e = enc()
e.lines["financing"].pitch = 6.0
e._apply_rider(DATA["objections"]["preapproved"])
check("knock_buyin removes pitch", e.lines["financing"].pitch,
      6.0 - DATA["objections"]["preapproved"].amount)

# --------------------------------------------------- the budget wallet
bb, ff, te = enc("budget_buyer"), enc("family_first"), enc("tech_enthusiast")
check("one price for everyone", bb.sticker(bb.lines["vehicle"].product),
      te.sticker(te.lines["vehicle"].product))
check("what differs is the wallet", bb.potential() < te.potential(), True)
check("potential IS the wallet", ff.potential(), int(CUST["family_first"].budget))

# a sale draws the wallet down
e = enc()
line = e.lines["protection"]
line.pitch = float(e.threshold(line) - line.product.base_buyin + 1)
price = e.price(line)
e.offer(line)
check("a sale spends their money", e.spent, price)
check("remaining wallet drops by the price", e.remaining_budget(),
      CUST["family_first"].budget - price)

# an offer bigger than what is left still goes through - they stretch
cust = CUST["family_first"]
orig = cust.budget
try:
    cust.budget = 500                       # less than any single product
    e = Scripted([("offer", "protection")], cust, engine.starter_deck(DATA["cards"]), DATA,
                 cfg={"max_turns": 3}, rng=random.Random(1), seed_shuffle=False)
    line = e.lines["protection"]
    line.pitch = float(e.threshold(line) - line.product.base_buyin + 2)
    res = e.run()
    check("a sale over the remaining wallet is NOT blocked", res["sold"], 1)
    check("emptying the wallet ends the encounter", res["outcome"], "MAXED_OUT")
    check("revenue may exceed the wallet - they stretched",
          res["revenue"] > cust.budget, True)
    check("take can read over 100%", res["take"] > 1.0, True)
finally:
    cust.budget = orig

# --------------------------------------------- counters answer a CATEGORY
# No counter cards in the lean deck, but the matcher stays for when they return.
e = enc()
price_answer = engine.Rec({"id": "x", "name": "X", "cost": 1, "counters": "price"})
check("counter answers any objection in its category",
      e.counters_it(price_answer, DATA["objections"]["price_objection"]), True)
check("and another one in the same category",
      e.counters_it(price_answer, DATA["objections"]["competitor_quote"]), True)
check("but not a different category",
      e.counters_it(price_answer, DATA["objections"]["dont_need_extras"]), False)

# ------------------------------------------------------ can_act / auto-end
e = enc()
e.energy = 0
e.hand = []
check("nothing to do with no energy and no cards", e.can_act(), False)
e.energy = 3
check("energy alone is enough to act (you can offer)", e.can_act(), True)
e.energy = 0
e.hand = [CARDS["small_talk"]]            # 0-cost card is still playable
check("a free card still counts as an action", e.can_act(), True)

# ------------------------------------------------ pitch card design budget
# 1 energy = +3 buy-in generic; +2 if restricted to a line; +1 per patience point.
for card in DATA["cards"]:
    if not card.get("buyin") or card.get("rapport"):
        continue
    budget = 4 * card.cost + card.get("patience_cost", 0)
    check("card '%s' is priced to the design budget" % card.id, card.get("buyin"), budget)

# -------------------------------------------------------------------- report
print("=" * 70)
for f in FAIL:
    print("FAIL " + f)
print("%d passed, %d failed" % (len(PASS), len(FAIL)))
print("=" * 70)
sys.exit(1 if FAIL else 0)
