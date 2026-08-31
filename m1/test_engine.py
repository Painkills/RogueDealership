# -*- coding: utf-8 -*-
"""
Rogue Dealership - M1 engine tests (v3).

    python m1/test_engine.py

Pins the rules so retuning data/*.json cannot silently change them. Where the
design docs are silent and m1 made a call, the test name says so.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import engine  # noqa: E402

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

PASS = []
FAIL = []


def check(label, cond):
    (PASS if cond else FAIL).append(label)


def eq(label, got, want):
    check("%s (got %r, want %r)" % (label, got, want), got == want)


def _pin(cat, cfg):
    """Randomness off and wallets effectively infinite, so a test that is not
    ABOUT jitter or budget never has to think about them."""
    cat.config["patience_jitter"] = 0
    cat.config["start_patience_min_fraction"] = 1.0
    cat.config["budget_min"] = 999
    cat.config["budget_max"] = 999
    cat.config.update(cfg)


def fresh(archetype="easygoing", **cfg):
    cat = engine.Catalog()
    _pin(cat, cfg)
    g = engine.Game(catalog=cat, seed=1, floor=[archetype])
    return g, g.customers[0]


def floor_of(*archetypes, **cfg):
    cat = engine.Catalog()
    _pin(cat, cfg)
    return engine.Game(catalog=cat, seed=1, floor=list(archetypes))


def hand_of(g, *card_ids):
    g.hand = [g.cat.card(cid) for cid in card_ids]


def tray_index(g, need_id):
    return g.cat.tray.index(g.cat.product_for(need_id))


# --------------------------------------------------------------------------
# Catalog integrity - design rules the data files must not drift from
# --------------------------------------------------------------------------
def test_catalog():
    cat = engine.Catalog()

    eq("6 needs, flat", len(cat.needs), 6)
    check("categories are gone", not hasattr(cat, "categories"))

    eq("6 products", len(cat.tray), 6)
    check("every product answers exactly one need - no duals survive",
          all(len(p["needs"]) == 1 for p in cat.tray))
    eq("products map 1:1 onto needs",
       sorted(p["needs"][0] for p in cat.tray), sorted(cat.need_ids))

    eq("margins form a 7-6-5-4-3-2 ladder",
       [p["margin"] for p in cat.tray], [7, 6, 5, 4, 3, 2])
    check("every need is reachable from a product",
          all(cat.product_for(n) is not None for n in cat.need_ids))

    check("the deck holds no products",
          all(c["type"] != "product" for c in cat.cards.values()))
    check("every card is either a Trust builder or a Trust converter",
          all(c["type"] in ("rapport", "convert") for c in cat.cards.values()))

    for a in cat.archetypes.values():
        check("archetype %s only raises bars, never weakens a card" % a["id"],
              a["reveal1"] >= cat.base["reveal1"]
              and a["reveal2"] >= cat.base["reveal2"]
              and a["decay"] >= cat.base["decay"])
        check("archetype %s never asks for the second need before the first" % a["id"],
              a["reveal2"] > a["reveal1"])

    nonbase = [a for a in cat.archetypes.values() if a["id"] != "easygoing"]
    for a in nonbase:
        stressed = sum([a["reveal1"] > cat.base["reveal1"],
                        a["reveal2"] > cat.base["reveal2"],
                        a["decay"] > cat.base["decay"],
                        a["patience"] < cat.base["patience"]])
        # Guarded moves both reveals, but that is ONE axis (how hard they are to read).
        check("archetype %s stresses one axis, so you can tell what you failed at" % a["id"],
              stressed <= 2 and not (a["decay"] > cat.base["decay"]
                                     and a["reveal1"] > cat.base["reveal1"]))


# --------------------------------------------------------------------------
# Setup: deck, tray, floor
# --------------------------------------------------------------------------
def test_deck_and_setup():
    cat = engine.Catalog()
    g = engine.Game(catalog=cat, seed=3)

    expected = sum(c["copies"] for c in cat.cards.values())
    eq("deck is Trust cards only", g.deck_size, expected)
    eq("m1 v3 first-pass deck is 14 cards", expected, 14)
    eq("tray is always 6 and never shuffled in", len(cat.tray), 6)

    eq("hand drawn to hand_size", len(g.hand), cat.config["hand_size"])
    eq("floor size", len(g.customers), cat.config["floor_size"])
    eq("actions replenished", g.actions_left, cat.config["actions_per_round"])
    eq("customers keyed A/B/C", [c.key for c in g.customers], ["A", "B", "C"])
    check("unique archetypes on the floor",
          len(set(c.archetype["id"] for c in g.customers)) == len(g.customers))

    for c in g.customers:
        eq("%s has 2 need slots" % c.key, len(c.needs), 2)
        check("%s never holds the same need twice" % c.key, c.needs[0] != c.needs[1])
        eq("%s starts fully hidden" % c.key, c.revealed, [False, False])
        eq("%s starting trust" % c.key, c.trust, cat.config["starting_trust"])
        check("%s knows nothing yet" % c.key, c.known_needs() == [])
        check("%s walks in with a wallet in range" % c.key,
              cat.config["budget_min"] <= c.budget <= cat.config["budget_max"])
        eq("%s has not left yet" % c.key, c.exit_reason, None)

    wallets = set()
    for s in range(60):
        wallets.update(c.budget for c in engine.Game(catalog=cat, seed=s).customers)
    check("wallets vary, so customers are worth different amounts", len(wallets) > 3)
    check("the fattest wallet can cover both needs at the top of the ladder",
          cat.config["budget_max"] >= 13)

    for s in range(100):
        for c in engine.Game(catalog=cat, seed=s).customers:
            check("no customer ever gets the same need twice", c.needs[0] != c.needs[1])


def test_patience_jitter_and_partial_start():
    cat = engine.Catalog()
    base = cat.archetypes["easygoing"]["patience"]
    jitter = cat.config["patience_jitter"]
    floorv = cat.config["patience_floor"]

    tops, starts, partial = set(), set(), 0
    for s in range(200):
        c = engine.Game(catalog=cat, seed=s, floor=["easygoing"]).customers[0]
        tops.add(c.max_patience)
        starts.add(c.patience)
        check("the bar tops out within the jitter band",
              floorv <= c.max_patience <= base + jitter)
        check("nobody starts above their own bar", c.patience <= c.max_patience)
        check("nor below the hard floor", c.patience >= floorv)
        if c.patience < c.max_patience:
            partial += 1
    check("where the bar tops out varies", len(tops) > 1)
    check("and so does where they walked in", len(starts) > 1)
    check("most customers do NOT start full - pressure from round one",
          partial > 100)

    # A fast burner starting at the bare floor would walk before you could act,
    # so the start is also floored by rounds, not just by raw Patience.
    cat2 = engine.Catalog()
    cat2.config["start_patience_min_fraction"] = 0.01
    for s in range(120):
        for c in engine.Game(catalog=cat2, seed=s).customers:
            check("everyone gets at least the minimum usable rounds",
                  c.rounds_left >= min(cat2.config["start_patience_min_rounds"],
                                       c.max_patience))

    g, c = fresh("easygoing")   # helper pins jitter 0 and a full start
    eq("pinned, the start is exactly the archetype value", c.patience, base)
    eq("and tops out there too", c.max_patience, base)


def test_per_customer_decay():
    """The user's ask: some customers burn faster, and that is what forces triage."""
    g = floor_of("easygoing", "rushed")
    slow, fast = g.customers
    eq("both start level", (slow.patience, fast.patience), (14, 14))
    eq("baseline burns 1/round", slow.decay, 1)
    eq("Rushed burns 3/round", fast.decay, 3)
    eq("and says so before you commit", (slow.rounds_left, fast.rounds_left), (14, 5))

    for _ in range(4):
        g.end_round()
    eq("after 4 rounds the slow one is fine", slow.patience, 10)
    eq("the fast one is nearly out", fast.patience, 2)
    check("both still here", slow.playable and fast.playable)

    g.end_round()
    eq("identical starts, different fates", (slow.state, fast.state), ("floor", "gone"))

    g2, c2 = fresh("easygoing", patience_decay_per_round=2)
    eq("an archetype without a decay key falls back to the config default",
       c2.decay, engine.Catalog().archetypes["easygoing"].get("decay", 2))


# --------------------------------------------------------------------------
# Actions - the shared budget across the whole floor
# --------------------------------------------------------------------------
def test_action_budget():
    g, c = fresh(actions_per_round=2)
    hand_of(g, "genuine_connection", "common_ground", "genuine_connection")

    g.play_card(0, 0)
    eq("a card costs 1 action", g.actions_left, 1)
    g.play_card(0)
    eq("budget spent", g.actions_left, 0)
    r = g.play_card(0, 0)
    check("no action left = rejected", not r.ok)
    eq("rejection costs nothing", len(g.hand), 1)

    r = g.pitch(0, 0)
    check("pitching needs an action too", not r.ok)

    g.end_round()
    eq("actions replenish each round", g.actions_left, 2)


def test_small_talk_is_free():
    """The one deliberate 0-action card: never a question of WHETHER, only WHO."""
    g = floor_of("easygoing", "rushed", "guarded", actions_per_round=1)
    hand_of(g, "small_talk", "small_talk", "genuine_connection", "small_talk")

    r = g.play_card(0, 0)
    check("Small Talk plays", r.ok)
    eq("and costs no action at all", g.actions_left, 1)
    eq("but it still does its job", g.customers[0].trust, 2)

    g.play_card(0, 1)
    eq("so you can reach a second customer in the same round",
       g.customers[1].trust, 2)
    eq("still no actions spent", g.actions_left, 1)

    g.play_card(0, 2)
    eq("everything else still costs one", g.actions_left, 0)

    r = g.play_card(0, 0)
    check("a free card is still playable on an empty action budget", r.ok)
    eq("which is the point of it", g.customers[0].trust, 4)

    g2, c2 = fresh(actions_per_round=0)
    hand_of(g2, "genuine_connection")
    check("a 1-action card is not", not g2.play_card(0, 0).ok)


def test_targeting_rejections():
    g, c = fresh()

    hand_of(g, "genuine_connection")
    r = g.play_card(0)
    check("a targeted card needs a customer", not r.ok)
    r = g.play_card(0, 9)
    check("customer index must exist", not r.ok)
    r = g.play_card(9, 0)
    check("card index must exist", not r.ok)

    hand_of(g, "common_ground")
    r = g.play_card(0)
    check("a floor-wide card needs no target", r.ok)

    r = g.pitch(99, 0)
    check("product index must exist", not r.ok)
    r = g.pitch(0, 99)
    check("pitch customer must exist", not r.ok)

    eq("no rejection ever spent an action", g.actions_left,
       g.cfg["actions_per_round"] - 1)


# --------------------------------------------------------------------------
# Trust: thresholds reveal, and Reassure cashes out
# --------------------------------------------------------------------------
def test_rapport_and_thresholds():
    g, c = fresh("easygoing")          # reveal1 3, reveal2 9
    hand_of(g, "small_talk", "small_talk", "genuine_connection")

    r = g.play_card(0, 0)
    eq("Small Talk +2 Trust", c.trust, 2)
    eq("below the first threshold, nothing surfaces", c.revealed, [False, False])
    eq("no reveal means it reads as plain rapport", r.kind, "rapport")

    r = g.play_card(0, 0)
    eq("crossing reveal1 fires it automatically - no ask needed", c.revealed[0], True)
    eq("the second need stays buried", c.revealed[1], False)
    eq("the crossing is the headline event", r.kind, "reveal")
    eq("it names what surfaced", r.data["fired"], [0])
    eq("and points at the next bar", c.next_threshold, 9)

    g.end_round()
    hand_of(g, "genuine_connection", "genuine_connection")
    g.play_card(0, 0)
    eq("Genuine Connection +4", c.trust, 8)
    eq("8 is still under 9", c.revealed[1], False)
    g.play_card(0, 0)
    eq("crossing reveal2 fires the second need", c.revealed[1], True)
    check("both needs known", c.next_threshold is None and len(c.known_needs()) == 2)


def test_reveals_are_permanent():
    """Reassure must never un-teach you something you already learned."""
    g, c = fresh("easygoing")
    hand_of(g, "genuine_connection", "reassure", "small_talk")

    g.play_card(0, 0)
    eq("trust 4 clears reveal1", c.revealed[0], True)

    g.play_card(0, 0)
    eq("Reassure drops Trust below the threshold that fired", c.trust, 1)
    check("but what you learned stays learned", c.revealed[0])
    eq("progress toward the NEXT reveal is what you gave up", c.next_threshold, 9)

    g.play_card(0, 0)
    eq("rebuilding does not re-fire an old reveal", c.revealed, [True, False])


def test_reassure():
    g, c = fresh("rushed")             # decay 3, so the refill buys little
    hand_of(g, "reassure", "genuine_connection", "reassure")

    r = g.play_card(0, 0)
    check("cannot Reassure with no Trust to spend", not r.ok)
    eq("blocked before any cost", (c.trust, c.patience), (0, 14))

    g.play_card(1, 0)                  # +4 trust (index 1: the rejection above
                                       # did not consume the card at index 0)
    p0, t0 = c.patience, c.trust
    r = g.play_card(0, 0)
    check("Reassure converts", r.ok)
    eq("spends exactly the Trust cost", c.trust, t0 - g.cfg["reassure_trust_cost"])
    eq("buys exactly the Patience gain", c.patience, p0 + g.cfg["reassure_patience_gain"])
    check("a flat refill buys fewer rounds on a fast burner - intended",
          g.cfg["reassure_patience_gain"] // c.decay < g.cfg["reassure_patience_gain"])


def test_common_ground():
    g = floor_of("easygoing", "rushed", "guarded")
    a, b, d = g.customers
    hand_of(g, "common_ground", "common_ground")

    g.play_card(0)
    eq("everyone on the floor gains Trust", [x.trust for x in g.customers], [2, 2, 2])

    d.state = "gone"
    b.state = "away"
    g.play_card(0)
    eq("the one still on the floor gains", a.trust, 4)
    eq("someone who walked does not", d.trust, 2)
    eq("someone who stepped away does not", b.trust, 2)

    g2 = floor_of("easygoing")
    g2.customers[0].state = "gone"
    hand_of(g2, "common_ground")
    r = g2.play_card(0)
    check("with an empty floor it is refused rather than wasted", not r.ok)


def test_trust_is_per_customer():
    g = floor_of("easygoing", "rushed")
    hand_of(g, "genuine_connection")
    g.play_card(0, 0)
    eq("A gained trust", g.customers[0].trust, 4)
    eq("B did not", g.customers[1].trust, 0)


# --------------------------------------------------------------------------
# Pitching: no gate, and blind is always legal
# --------------------------------------------------------------------------
def test_no_pitch_gate():
    g, c = fresh()
    c.needs = ["reliability", "health"]
    eq("no trust at all", c.trust, 0)

    r = g.pitch(tray_index(g, "reliability"), 0)
    check("you can pitch at Trust 0 - there is no gate", r.ok and r.kind == "sale")
    eq("margin banked on turn one", g.margin, 7)
    eq("pitching never touches Trust", c.trust, 0)
    check("and it was flagged as the gamble it was", r.data["blind"])


def test_pitch_hit_and_miss():
    g, c = fresh()
    c.needs = ["reliability", "health"]
    c.revealed = [True, True]

    p0 = c.patience
    r = g.pitch(tray_index(g, "reliability"), 0)
    check("a known match sells", r.ok and r.kind == "sale")
    eq("margin banked", g.margin, 7)
    eq("a pitch costs 1 Patience", c.patience, p0 - 1)
    check("a known pitch is not a gamble", not r.data["blind"])

    c.revealed = [False, False]
    c.sold = []
    p1 = c.patience
    r = g.pitch(tray_index(g, "security"), 0)
    check("a mismatch is refused", r.ok and r.kind == "miss")
    eq("a miss costs the pitch AND the failure penalty", c.patience, p1 - 1 - 3)
    eq("margin unchanged", g.margin, 7)
    check("and it eliminates that need - Patience bought information",
          "security" in c.eliminated)


def test_blind_hit_reveals():
    """A lucky gamble has to be informative, or it teaches nothing."""
    g, c = fresh()
    c.needs = ["reliability", "health"]
    eq("nothing known", c.revealed, [False, False])

    r = g.pitch(tray_index(g, "health"), 0)
    check("blind, and it landed", r.ok and r.kind == "sale" and r.data["blind"])
    eq("the slot it hit is now revealed - you proved what it is", c.revealed[1], True)
    eq("the other slot is still hidden", c.revealed[0], False)
    eq("so the next reveal to chase is the second one", c.next_threshold, c.reveal2)

    # Thresholds are keyed to HOW MANY needs you know, not to slot index.
    g2, c2 = fresh("reserved")         # reveal1 3, reveal2 14 - the buried second
    c2.needs = ["reliability", "health"]
    g2.pitch(tray_index(g2, "health"), 0)
    check("the gamble landed", "health" in [c2.needs[i] for i in (0, 1) if c2.revealed[i]])
    eq("a lucky blind hit must NOT make the buried second need cheap",
       c2.next_threshold, 14)
    c2.trust = 13
    g2._check_reveals(c2)
    eq("13 Trust still is not enough for Reserved's second", c2.revealed.count(True), 1)
    c2.trust = 14
    g2._check_reveals(c2)
    eq("14 is", c2.revealed, [True, True])


def test_miss_ladder_narrows():
    g, c = fresh()
    c.needs = ["reliability", "health"]

    for need in ("security", "equity"):
        g.actions_left = 9
        g.pitch(tray_index(g, need), 0)
    eq("two misses ruled out two needs", len(c.eliminated), 2)

    g.actions_left = 9
    r = g.pitch(tray_index(g, "security"), 0)
    check("a need you already disproved cannot be pitched again", not r.ok)
    eq("and the refusal costs no Patience", c.patience, 14 - 2 * 4)

    c.revealed = [True, True]
    r = g.pitch(tray_index(g, "durability"), 0)
    check("once you know both needs, a doomed pitch is refused too", not r.ok)


def test_no_repeat_sales():
    g, c = fresh()
    c.needs = ["reliability", "health"]
    c.revealed = [True, True]

    g.actions_left = 9
    g.pitch(tray_index(g, "reliability"), 0)
    g.pitch(tray_index(g, "health"), 0)
    eq("a close does not end the interaction - both needs sold", g.margin, 13)
    eq("two sales on one customer", len(c.sold), 2)

    r = g.pitch(tray_index(g, "reliability"), 0)
    check("the same product cannot be sold twice to one customer", not r.ok)
    eq("rejection costs no Patience", c.patience, 14 - 2)


# --------------------------------------------------------------------------
# Round flow
# --------------------------------------------------------------------------
def test_budget_wallet():
    """The wallet is what makes customers worth different amounts, and what
    ends a customer other than the clock."""
    g, c = fresh(budget_min=8, budget_max=8)
    c.needs = ["reliability", "health"]     # margins 7 and 6
    c.revealed = [True, True]
    g.actions_left = 9

    eq("the wallet starts where it was rolled", c.budget, 8)
    g.pitch(tray_index(g, "reliability"), 0)
    eq("a sale draws the wallet down by the product's margin", c.budget, 1)
    check("1 left is still on the floor", c.playable)

    r = g.pitch(tray_index(g, "health"), 0)
    check("a sale bigger than the wallet is NOT blocked - they stretched",
          r.ok and r.kind == "sale")
    eq("and you are paid in full for it", g.margin, 13)
    check("but the wallet emptying ends them", r.data["tapped"])
    eq("TAPPED OUT, not walked - the good ending", c.exit_reason, "tapped")
    eq("they are off the floor", c.state, "gone")
    check("with Patience to spare - the clock is not what got them",
          c.patience > 0)


def test_budget_caps_what_a_customer_is_worth():
    """A thin wallet means one sale, however well you diagnose them."""
    g, c = fresh(budget_min=4, budget_max=4)
    c.needs = ["reliability", "health"]
    c.revealed = [True, True]
    g.actions_left = 9

    g.pitch(tray_index(g, "reliability"), 0)   # margin 7 against a budget of 4
    eq("you are still paid the full margin", g.margin, 7)
    eq("but that is the whole customer", c.exit_reason, "tapped")
    r = g.pitch(tray_index(g, "health"), 0)
    check("their second need is unreachable - not worth diagnosing", not r.ok)

    rich, poor = fresh(budget_min=14, budget_max=14)[1], c
    check("wallets differentiate customers before you spend an action on them",
          rich.start_budget != poor.start_budget)


def test_budget_never_blocks_and_misses_are_free():
    g, c = fresh(budget_min=3, budget_max=3)
    c.needs = ["reliability", "health"]
    g.actions_left = 9

    r = g.pitch(tray_index(g, "security"), 0)
    check("a miss still happens with a near-empty wallet", r.kind == "miss")
    eq("a refusal costs them nothing in money - only you, in Patience",
       c.budget, 3)
    check("still here", c.playable)


def test_round_flow():
    g = floor_of("easygoing", "rushed", "guarded")
    before = [c.patience for c in g.customers]
    hand_of(g, "small_talk")
    g.play_card(0, 0)
    eq("acting does not decay Patience by itself",
       [c.patience for c in g.customers], before)

    g.end_round()
    eq("everyone decays, at their own rate, targeted or not",
       [c.patience for c in g.customers],
       [p - c.decay for p, c in zip(before, g.customers)])
    eq("round advances", g.round_no, 2)
    eq("hand redrawn to size", len(g.hand), g.cfg["hand_size"])


def test_decay_is_after_actions_not_before():
    """m0's lesson: you close during your turn, before the clock lands."""
    g, c = fresh()
    c.needs = ["reliability", "health"]
    c.revealed = [True, True]
    c.patience = 1
    r = g.pitch(tray_index(g, "reliability"), 0)
    check("a customer on their last point of Patience can still be closed",
          r.ok and r.kind == "sale")
    eq("margin banked before the clock", g.margin, 7)


def test_hand_cycles_and_reshuffles():
    g = engine.Game(catalog=engine.Catalog(), seed=7)
    total = g.deck_size
    for _ in range(30):
        if g.over:
            break
        g.end_round()
        eq("deck is conserved - no card ever lost or duplicated",
           len(g.hand) + len(g.draw_pile) + len(g.discard_pile), total)
    check("draw pile reshuffled from discard at least once", g.reshuffles >= 1)


def test_keep_hand_option():
    g, c = fresh(discard_hand_each_round=True)
    hand_of(g, "small_talk", "small_talk")
    g.end_round()
    check("discard_hand_each_round=True discards the unplayed hand",
          len(g.discard_pile) >= 2)

    g2, c2 = fresh(discard_hand_each_round=False)
    hand_of(g2, "small_talk")
    g2.end_round()
    eq("discard_hand_each_round=False keeps unplayed cards",
       len(g2.hand), g2.cfg["hand_size"])


# --------------------------------------------------------------------------
# Walking and the end of the shift
# --------------------------------------------------------------------------
def test_walk_terminal():
    g, c = fresh("rushed", walk_returns=False)     # 14 patience, decay 3
    eq("five rounds on the clock", c.rounds_left, 5)
    for _ in range(4):
        g.end_round()
    check("still here at four", c.playable)
    g.end_round()
    eq("Patience gone", c.patience, 0)
    eq("customer walked", c.state, "gone")
    check("shift ends when the whole floor is gone", g.over)

    g2, c2 = fresh()
    c2.needs = ["reliability", "health"]
    c2.state = "gone"
    r = g2.pitch(tray_index(g2, "reliability"), 0)
    check("a customer who walked cannot be pitched", not r.ok)
    hand_of(g2, "genuine_connection")
    check("nor talked to", not g2.play_card(0, 0).ok)


def test_walk_can_be_triggered_by_a_miss():
    g, c = fresh()
    c.needs = ["reliability", "health"]
    c.patience = 3
    r = g.pitch(tray_index(g, "security"), 0)
    check("a bad gamble can walk them mid-turn", r.kind == "miss")
    eq("patience floors at 0", c.patience, 0)
    eq("and they are gone", c.state, "gone")


def test_walk_returns_option():
    g, c = fresh("rushed", walk_returns=True, walk_return_rounds=2,
                 walk_return_patience=5)
    for _ in range(5):
        g.end_round()
    eq("they walk out", c.state, "away")
    check("shift is not over while someone may return", not g.over)

    g.end_round()
    g.end_round()
    eq("they come back", c.state, "floor")
    eq("at reduced Patience, not restored", c.patience, 5)
    check("reduced means below where they started", c.patience < c.max_patience)

    for _ in range(2):
        g.end_round()
    eq("a second walk is terminal", c.state, "gone")
    check("now the shift can end", g.over)


def test_max_rounds_backstop():
    """Reassure can out-pace decay forever, so the floor emptying is not on its
    own a guaranteed terminator. The valve must never bind in normal play."""
    g, c = fresh("easygoing", max_rounds=6)
    for _ in range(5):
        g.end_round()
    check("the valve does not bind early", not g.over and c.playable)
    g.end_round()
    check("but it does end the shift", g.over)
    check("and the report says it was a stall, not a clean finish",
          g.report()["stalled"])

    g2 = engine.Game(catalog=engine.Catalog(), seed=5)
    while not g2.over:
        g2.end_round()
    check("a real shift ends by the floor emptying, well short of the valve",
          not g2.stalled and g2.round_no < g2.cfg["max_rounds"])


def test_shift_report():
    g, c = fresh()
    c.needs = ["reliability", "health"]
    c.revealed = [True, True]
    g.pitch(tray_index(g, "reliability"), 0)
    g.end_round()

    rep = g.report()
    eq("report counts margin", rep["margin"], 7)
    eq("report counts sales", rep["sales"], 1)
    eq("report knows the decay rate that killed you", rep["customers"][0]["decay"], 1)
    eq("report tracks the wallet drawdown",
       rep["customers"][0]["start_budget"] - rep["customers"][0]["budget"], 7)
    check("report separates tapping someone out from losing them",
          "tapped_out" in rep and "walked" in rep)
    eq("report tracks how fast the first margin landed", rep["first_margin_action"], 1)
    check("report tracks blind offers - is the gamble ever taken?",
          "blind_offers" in rep)
    check("report tracks unspent actions - m0's decision-density metric",
          "actions_unspent" in rep and "cards_unplayed" in rep)


def test_determinism():
    a = engine.Game(catalog=engine.Catalog(), seed=42)
    b = engine.Game(catalog=engine.Catalog(), seed=42)
    eq("same seed, same needs",
       [c.needs for c in a.customers], [c.needs for c in b.customers])
    eq("same seed, same jittered patience",
       [c.patience for c in a.customers], [c.patience for c in b.customers])
    eq("same seed, same hand",
       [c["id"] for c in a.hand], [c["id"] for c in b.hand])


# --------------------------------------------------------------------------
def main():
    tests = [v for k, v in sorted(globals().items()) if k.startswith("test_")]
    for t in tests:
        try:
            t()
        except Exception as exc:  # a crash is a failure, not a stack trace
            FAIL.append("%s CRASHED: %s: %s" % (t.__name__, type(exc).__name__, exc))
    for f in FAIL:
        print("FAIL  %s" % f)
    print("\n%d checks, %d passed, %d failed" % (len(PASS) + len(FAIL), len(PASS), len(FAIL)))
    return 1 if FAIL else 0


if __name__ == "__main__":
    sys.exit(main())
