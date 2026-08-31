# -*- coding: utf-8 -*-
"""
Rogue Dealership - M2 engine tests (the negotiation model).

    python m2/test_engine.py

Pins the rules so retuning data/*.json cannot silently change them. Where the
design was silent and m2 made a call, the test name says so.
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

NINE = ["reliability", "security", "power", "affordability", "equity",
        "value_retention", "stability", "convenience", "status"]


def check(label, cond):
    (PASS if cond else FAIL).append(label)


def eq(label, got, want):
    check("%s (got %r, want %r)" % (label, got, want), got == want)


def _shift(floor=None, seed=1, **cfg):
    """Randomness off by default, so a test that is not ABOUT variance never
    has to think about it."""
    cat = engine.Catalog()
    cat.config["patience_jitter"] = 0
    cat.config["prior_slip"] = 0.0
    cat.config["arrival_patience_min_fraction"] = 1.0
    cat.config.update(cfg)
    return engine.Shift(catalog=cat, seed=seed, floor=floor)


def _rank(cust, order):
    """Force a priority list. order is best-first; anything omitted fills in
    behind it in NINE order."""
    rest = [i for i in NINE if i not in order]
    for n, iid in enumerate(list(order) + rest, start=1):
        cust.ranks[iid] = n


def _hand(s, *ids):
    s.hand = [s.cat.card(i) for i in ids]


def _at(s, chair=0):
    """Stand with a customer without the approach tick muddying the numbers."""
    s.at = chair
    s.last_customer = s.chairs[chair]
    return s.chairs[chair]


def _pitch(s, card_id):
    """Place and offer in one go, for tests that are not about the split."""
    _hand(s, card_id)
    s.place(0)
    return s.offer()


# ---------------------------------------------------------------- the ladder
def test_appeal_is_step_times_places_from_the_bottom():
    s = _shift(floor=["easygoing"])
    c = s.chairs[0]
    _rank(c, ["reliability"])
    eq("rank 1 opens at 40", c.appeal_for("reliability"), 40)
    c.ranks["security"] = 9
    eq("rank 9 opens at 0", c.appeal_for("security"), 0)
    c.ranks["power"] = 5
    eq("rank 5 opens at 20", c.appeal_for("power"), 20)


def test_no_card_moves_a_full_place_on_their_list():
    """cards.json _DESIGN_RULE: a card that is worth a whole rank step becomes
    a substitute for reading the customer."""
    cat = engine.Catalog()
    step = cat.config["appeal_step"]
    for card in cat.cards.values():
        gain = card.get("appeal", 0)
        if gain <= 0 or card.get("margin", 0) < 0 or card.get("patience", 0) < 0:
            continue          # it pays in margin or patience, so it may be big
        check("%s moves less than one place (%d < %d)"
              % (card["id"], gain, step), gain < step)


def test_placing_opens_the_offer_at_that_appeal():
    s = _shift(floor=["easygoing"])
    c = _at(s)
    _rank(c, ["status", "power", "reliability"])   # reliability 3rd -> 30
    _hand(s, "vsc")
    res = s.place(0)
    check("placing is legal at any rank", res.ok)
    eq("appeal opens at the rank value", c.offer.appeal, 30)
    eq("margin opens at list", c.offer.margin, 1600)


def test_placing_costs_a_tick_and_shows_only_a_band():
    s = _shift(floor=["easygoing"])
    c = _at(s)
    _rank(c, ["status", "power", "reliability"])
    _hand(s, "vsc")
    res = s.place(0)
    eq("placing costs a tick", s.tick, 1)
    check("it tells you a band", res.data.get("band") in
          ("ALMOST", "WARM", "COOL", "COLD"))
    check("but not the rank", "reliability" not in c.known_ranks)
    check("and not the threshold", not c.known_threshold)
    check("and the offer is not revealed", not c.offer.revealed)


def test_offering_is_free_and_reveals_everything():
    s = _shift(floor=["easygoing"])
    c = _at(s)
    c.threshold = 99
    _rank(c, ["status", "power", "reliability"])
    _hand(s, "vsc")
    s.place(0)
    t = s.tick
    res = s.offer()
    eq("offering costs no ticks", s.tick, t)
    check("it teaches you the rank", "reliability" in c.known_ranks)
    check("and the threshold", c.known_threshold)
    eq("and reports the exact shortfall", res.data.get("short"), 99 - 30)


def test_accept_fires_exactly_at_threshold_not_above():
    s = _shift(floor=["easygoing"])
    c = _at(s)
    c.threshold = 30
    _rank(c, ["status", "power", "reliability"])   # appeal 30
    _pitch(s, "vsc")
    eq("appeal == threshold sells", len(c.unsigned), 1)

    s2 = _shift(floor=["easygoing"])
    c2 = _at(s2)
    c2.threshold = 31
    _rank(c2, ["status", "power", "reliability"])
    _pitch(s2, "vsc")
    eq("one short does not sell", len(c2.unsigned), 0)
    check("and the offer stays on the table", c2.offer is not None)


def test_support_cards_alone_never_close_a_sale():
    """Acceptance happens on OFFER and nowhere else - that is the whole point
    of the two-step."""
    s = _shift(floor=["easygoing"])
    c = _at(s)
    c.threshold = 30
    _rank(c, ["status", "power", "reliability"])
    _hand(s, "vsc", "explain", "explain")
    s.place(0)
    s.play_card(0)
    s.play_card(0)
    check("appeal is well over the bar", c.offer.appeal >= c.threshold)
    eq("and nothing has been agreed to", len(c.unsigned), 0)
    s.offer()
    eq("until you ask", len(c.unsigned), 1)


def test_threshold_ramps_three_per_sale():
    s = _shift(floor=["easygoing"])
    c = _at(s)
    c.threshold = 20
    _rank(c, ["reliability", "equity"])            # 40 and 35
    _pitch(s, "vsc")
    eq("first sale lands", len(c.unsigned), 1)
    eq("threshold ramps +3", c.threshold, 23)
    _pitch(s, "gap")
    eq("second sale lands", len(c.unsigned), 2)
    eq("and ramps again", c.threshold, 26)


def test_family_first_never_gets_harder():
    s = _shift(floor=["family"])
    c = _at(s)
    _rank(c, ["reliability", "equity", "stability"])
    start = c.threshold
    _pitch(s, "vsc")
    _pitch(s, "gap")
    eq("three sales in and she wants exactly what she wanted",
       c.threshold, start)
    eq("both landed", len(c.unsigned), 2)


def test_sale_refunds_patience_capped_at_max():
    s = _shift(floor=["easygoing"])
    c = _at(s)
    c.threshold, c.patience = 20, 5
    _rank(c, ["reliability"])
    _pitch(s, "vsc")
    eq("place burned a tick, then the sale refunded 3", c.patience, 5 - 1 + 3)

    s2 = _shift(floor=["easygoing"])
    c2 = _at(s2)
    c2.threshold = 20
    _rank(c2, ["reliability"])
    _pitch(s2, "vsc")
    eq("refund never exceeds max_patience", c2.patience, c2.max_patience)


def test_a_short_offer_costs_one_patience_and_no_time():
    s = _shift(floor=["easygoing", "easygoing"])
    c = _at(s)
    c.threshold = 99
    _rank(c, ["status", "power", "reliability"])
    _hand(s, "vsc")
    s.place(0)
    p, b, t = c.patience, s.chairs[1].patience, s.tick
    s.offer()
    eq("they bruise a little", c.patience, p - 1)
    eq("the clock does not move", s.tick, t)
    eq("and nobody else pays for it", s.chairs[1].patience, b)


# ------------------------------------------------------------------ the tick
def test_one_tick_burns_every_customer_on_the_floor_and_the_clock():
    s = _shift(floor=["easygoing", "easygoing", "easygoing"])
    _at(s)
    s.chairs[0].patience = 5           # small talk cannot exceed max_patience
    before = [c.patience for c in s.chairs]
    _hand(s, "smalltalk", "explain")
    s.play_card(1)                                  # explain, no live offer
    eq("a refused card costs nothing", s.tick, 0)
    eq("and burns nobody", [c.patience for c in s.chairs], before)

    _hand(s, "smalltalk")
    s.play_card(0)
    eq("clock advanced one", s.tick, 1)
    eq("target: +5 small talk, -1 tick", s.chairs[0].patience, before[0] + 4)
    eq("bystander B burned", s.chairs[1].patience, before[1] - 1)
    eq("bystander C burned", s.chairs[2].patience, before[2] - 1)


def test_a_two_tick_card_burns_two():
    s = _shift(floor=["easygoing", "easygoing"])
    c = _at(s)
    c.threshold = 99
    _rank(c, ["status", "power", "reliability"])
    b = s.chairs[1].patience
    _hand(s, "vsc", "hardclose")
    s.play_card(0)                                  # place, 1 tick
    s.play_card(0)                                  # hard close, 2 ticks
    eq("clock advanced 1 + 2", s.tick, 3)
    eq("bystander burned 3 total", s.chairs[1].patience, b - 3)


def test_going_back_to_the_same_customer_is_free():
    s = _shift(floor=["easygoing", "easygoing"])
    s.approach(0)
    eq("the first walk over costs a tick", s.tick, 1)
    s.leave()
    eq("stepping out is free", s.tick, 1)
    s.approach(0)
    eq("and going back to the same person is free", s.tick, 1)
    s.leave()
    s.approach(1)
    eq("changing your mind costs a tick", s.tick, 2)
    s.leave()
    s.approach(0)
    eq("and going back again costs, because you moved", s.tick, 3)


def test_a_new_customer_in_the_same_chair_is_not_the_same_person():
    s = _shift(floor=["easygoing", "easygoing"], walk_up_ticks=1)
    s.approach(0)
    s.close()                                       # chair 0 empties
    s.approach(1)                                   # 1 tick, chair 0 refills
    t = s.tick
    check("someone new is in chair 0", s.chairs[0] is not None)
    s.leave()
    s.approach(0)
    eq("a stranger in a familiar chair still costs a tick", s.tick, t + 1)


def test_effects_resolve_before_the_tick_burns():
    """m0's discovered rule: you close DURING your turn, before the damage."""
    s = _shift(floor=["easygoing", "easygoing"])
    c = _at(s)
    c.patience = 1
    _hand(s, "smalltalk")
    s.play_card(0)
    eq("small talk saves someone at 1 patience", c.patience, 1 + 5 - 1)
    eq("they are still on the floor", c.state, "floor")


def test_a_sale_lands_on_a_customer_who_had_one_patience_left():
    s = _shift(floor=["easygoing", "easygoing"])
    c = _at(s)
    c.threshold = 20
    _rank(c, ["reliability"])
    _hand(s, "vsc")
    s.place(0)
    c.patience = 1
    s.offer()
    eq("the sale registered", len(c.unsigned), 1)
    eq("and the refund landed", c.patience, 1 + 3)
    eq("still there", c.state, "floor")


def test_walking_forfeits_the_entire_unsigned_deal():
    s = _shift(floor=["easygoing", "easygoing"])
    c = _at(s)
    c.threshold = 20
    _rank(c, ["reliability", "equity"])
    _pitch(s, "vsc")
    _pitch(s, "gap")
    eq("$3,000 agreed to", c.unsigned_margin, 3000)
    c.patience = 1
    _hand(s, "smalltalk")
    s.dig(0)                                        # one tick -> they walk
    eq("patience gone means gone", c.state, "walked")
    eq("the unsigned deal went with them", s.margin_banked, 0)
    eq("the report counts it as lost",
       s.report()["margin_lost_to_walks"], 3000)
    eq("the chair is empty", s.chairs[0], None)
    eq("and you are not standing in it", s.at, None)


def test_close_is_the_only_thing_that_banks():
    s = _shift(floor=["easygoing", "easygoing"])
    c = _at(s)
    c.threshold = 20
    _rank(c, ["reliability"])
    _pitch(s, "vsc")
    eq("agreeing banks nothing", s.margin_banked, 0)
    eq("it sits unsigned", c.unsigned_margin, 1600)
    t = s.tick
    res = s.close()
    check("close is allowed", res.ok)
    eq("close banks it", s.margin_banked, 1600)
    eq("closing is free", s.tick, t)
    eq("they are gone", c.state, "signed")
    eq("the chair is empty", s.chairs[0], None)
    eq("and you are back on the floor", s.at, None)


def test_close_with_nothing_sold_is_legal_and_banks_zero():
    """You let them buy the car with no F&I and take the chair back."""
    s = _shift(floor=["easygoing", "easygoing"])
    _at(s)
    res = s.close()
    check("dismissing an unsold customer is allowed", res.ok)
    eq("banks nothing", s.margin_banked, 0)
    eq("chair freed", s.chairs[0], None)


# ---------------------------------------------------------------- the offer
def test_an_offer_survives_you_walking_away_and_back():
    s = _shift(floor=["easygoing", "easygoing", "easygoing"])
    c = _at(s)
    c.threshold = 99
    _rank(c, ["status", "power", "reliability"])
    _hand(s, "vsc", "discount")
    s.place(0)
    s.play_card(0)
    appeal, margin = c.offer.appeal, c.offer.margin
    eq("conceded once", (appeal, margin), (30 + 8, 1600 - 300))
    s.leave()
    s.approach(1)
    s.leave()
    s.approach(0)
    eq("appeal exactly as left", c.offer.appeal, appeal)
    eq("margin exactly as left", c.offer.margin, margin)


def test_only_one_offer_on_the_table_at_a_time():
    s = _shift(floor=["easygoing"])
    c = _at(s)
    c.threshold = 99
    _rank(c, ["status", "power", "reliability"])
    _hand(s, "vsc", "gap")
    s.place(0)
    t = s.tick
    res = s.place(0)
    check("a second product is refused", not res.ok)
    eq("and costs nothing", s.tick, t)
    eq("the first is untouched", c.offer.product["id"], "vsc")


def test_dropping_an_offer_is_free_and_loses_the_concessions():
    s = _shift(floor=["easygoing"])
    c = _at(s)
    c.threshold = 99
    _rank(c, ["status", "power", "reliability"])
    _hand(s, "vsc", "discount", "gap")
    s.place(0)
    s.play_card(0)
    t = s.tick
    s.drop_offer()
    eq("dropping is free", s.tick, t)
    eq("nothing on the table", c.offer, None)
    eq("the card went to discard", s.discard[-1]["id"], "vsc")
    s.place(0)                                      # gap
    eq("a fresh offer starts at list", c.offer.margin, 1400)


def test_a_product_they_already_bought_cannot_be_placed_again():
    s = _shift(floor=["easygoing"])
    c = _at(s)
    c.threshold = 20
    _rank(c, ["reliability"])
    _pitch(s, "vsc")
    _hand(s, "vsc")
    t = s.tick
    res = s.place(0)
    check("no double-dipping", not res.ok)
    eq("and it costs nothing", s.tick, t)


def test_support_cards_need_something_on_the_table():
    s = _shift(floor=["easygoing"])
    _at(s)
    _hand(s, "discount", "smalltalk")
    res = s.play_card(0)
    check("a discount on nothing is refused", not res.ok)
    res = s.play_card(1)
    check("small talk needs no offer", res.ok)


def test_nothing_can_be_played_from_the_floor():
    s = _shift(floor=["easygoing"])
    s.at = None
    _hand(s, "smalltalk")
    check("cards need a customer", not s.play_card(0).ok)
    check("so does offering", not s.offer().ok)
    check("and closing", not s.close().ok)
    eq("costs nothing", s.tick, 0)


# ------------------------------------------------------------- card effects
def test_pad_the_deal_buys_margin_with_appeal():
    s = _shift(floor=["easygoing"])
    c = _at(s)
    c.threshold = 99
    _rank(c, ["status", "power", "reliability"])
    _hand(s, "vsc", "pad")
    s.place(0)
    s.play_card(0)
    eq("margin up 400", c.offer.margin, 2000)
    eq("appeal down 5", c.offer.appeal, 25)


def test_pad_works_on_a_product_that_would_have_closed_cold():
    """The whole reason placing and offering are separate moves."""
    s = _shift(floor=["easygoing"])
    c = _at(s)
    c.threshold = 35
    _rank(c, ["reliability"])                       # appeal 40, clears by 5
    _hand(s, "vsc", "pad", "explain", "explain")
    s.place(0)
    s.play_card(0)                                  # pad first: 40 -> 35
    eq("still exactly on the bar", c.offer.appeal, 35)
    s.offer()
    eq("sold at a padded price", c.unsigned_margin, 2000)


def test_margin_can_be_conceded_below_zero_and_banks_as_is():
    """The arithmetic is the deterrent, never a rule."""
    s = _shift(floor=["easygoing"])
    c = _at(s)
    c.threshold = 99
    _rank(c, ["status", "power", "convenience"])    # concierge $600, appeal 30
    _hand(s, "concierge", "discount", "discount", "discount")
    s.place(0)
    for _ in range(3):
        s.play_card(0)
    eq("margin went underwater", c.offer.margin, 600 - 900)
    c.threshold = 0
    s.offer()
    eq("and a loss banks as a loss", c.unsigned_margin, -300)


def test_read_the_room_reveals_threshold_and_a_category():
    s = _shift(floor=["easygoing"])
    c = _at(s)
    check("hidden on arrival", not c.known_threshold)
    _hand(s, "readroom")
    s.play_card(0)
    check("read the room tells you the bar", c.known_threshold)
    top = [i for i, r in c.ranks.items() if r == 1][0]
    eq("and narrows nine interests to three",
       c.known_top_category, s.cat.interests[top]["category"])


# ------------------------------------------------------------------ actions
def test_budget_hawk_gets_harder_every_time_you_ask_and_miss():
    s = _shift(floor=["hawk"])
    c = _at(s)
    _rank(c, ["status", "power", "reliability"])    # appeal 30 vs her 40
    start = c.threshold
    _hand(s, "vsc")
    s.place(0)
    s.offer()
    eq("a short offer makes her harder", c.threshold, start + 5)
    s.offer()
    eq("and it stacks", c.threshold, start + 10)


def test_budget_hawk_does_not_punish_an_offer_that_clears():
    s = _shift(floor=["hawk"])
    c = _at(s)
    _rank(c, ["reliability"])                       # appeal 40 == her 40
    _pitch(s, "vsc")
    eq("it sold", len(c.unsigned), 1)
    eq("only the normal ramp applied", c.threshold, 40 + 3)


def test_tire_kicker_bleeds_every_four_ticks():
    s = _shift(floor=["kicker", "easygoing"])
    c = _at(s)
    start = c.patience
    _hand(s, "explain", "explain", "explain", "explain")
    for _ in range(3):
        s.dig(0)
    eq("three ticks, three patience", c.patience, start - 3)
    s.dig(0)
    eq("on the fourth he loses two more", c.patience, start - 4 - 2)


def test_tech_enthusiast_pays_a_premium_for_a_bullseye():
    s = _shift(floor=["tech"])
    c = _at(s)
    c.threshold = 30
    _rank(c, ["reliability"])                       # his 1st
    _pitch(s, "vsc")
    eq("bullseye banks the premium", c.unsigned_margin, 1600 + 300)

    s2 = _shift(floor=["tech"])
    c2 = _at(s2)
    c2.threshold = 30
    _rank(c2, ["status", "power", "reliability"])   # his 3rd
    _pitch(s2, "vsc")
    eq("third place is just a sale", c2.unsigned_margin, 1600)


def test_family_first_bleeds_when_you_fish_below_her_top_five():
    s = _shift(floor=["family"])
    c = _at(s)
    _rank(c, ["reliability", "stability", "equity", "security",
              "affordability", "convenience"])      # convenience 6th
    _hand(s, "concierge")
    s.place(0)
    p = c.patience
    s.offer()
    eq("fishing costs 4 on top of the failed offer", c.patience, p - 1 - 4)


def test_family_first_does_not_mind_a_miss_inside_her_top_five():
    s = _shift(floor=["family"])
    c = _at(s)
    _rank(c, ["reliability", "stability", "equity", "security",
              "affordability"])                     # affordability 5th, appeal 20
    _hand(s, "flex")
    s.place(0)
    p = c.patience
    s.offer()
    eq("a miss she cared about costs only the offer", c.patience, p - 1)


def test_the_karen_drains_everyone_but_herself():
    s = _shift(floor=["karen", "easygoing", "easygoing"])
    _at(s)
    hers = s.chairs[0].patience
    theirs = s.chairs[1].patience
    _hand(s, "explain", "explain", "explain", "explain")
    for _ in range(5):
        s.dig(0)
    eq("she pays only the clock", s.chairs[0].patience, hers - 5)
    eq("everyone else pays the clock and her", s.chairs[1].patience,
       theirs - 5 - 1)
    eq("and so does C", s.chairs[2].patience, theirs - 5 - 1)


def test_the_karen_will_not_sign_without_what_she_came_for():
    s = _shift(floor=["karen", "easygoing"])
    c = _at(s)
    _rank(c, ["reliability"])
    c.demands = "vehicle"
    c.threshold = 20
    res = s.close()
    check("she refuses to sign", not res.ok)
    eq("nothing banked", s.margin_banked, 0)
    eq("and she is still sitting there", s.chairs[0], c)

    _pitch(s, "gap")                                # Deal, not what she wants
    check("a sale in the wrong category does not unlock her",
          not s.close().ok)
    _pitch(s, "vsc")                                # Vehicle
    res = s.close()
    check("now she signs", res.ok)
    eq("banking both", s.margin_banked, 1400 + 1600)


def test_the_karen_still_walks_when_her_patience_runs_out():
    s = _shift(floor=["karen", "easygoing"])
    c = _at(s)
    c.demands = "vehicle"
    c.threshold = 20
    _rank(c, ["equity"])
    _pitch(s, "gap")
    eq("she agreed to something", c.unsigned_margin, 1400)
    c.patience = 1
    s.dig(0)
    eq("the lock does not make her immortal", c.state, "walked")
    eq("and it went with her", s.report()["margin_lost_to_walks"], 1400)


def test_her_demand_is_the_category_of_her_own_first_choice():
    for seed in range(12):
        s = _shift(floor=["karen"], seed=seed)
        c = s.chairs[0]
        eq("seed %d: she demands what she came for" % seed,
           c.demands, s.cat.category_of(c.top_interest))
        eq("seed %d: and she says so out loud" % seed,
           c.known_top_category, c.demands)


def test_the_quiet_archetypes_never_do_anything():
    for aid in ("easygoing", "laydown"):
        s = _shift(floor=[aid, aid])
        c = _at(s)
        c.threshold = 99
        _rank(c, ["status", "power", "reliability"])
        _hand(s, "vsc", "explain", "explain", "explain")
        s.place(0)
        s.offer()
        s.offer()
        for _ in range(3):
            s.dig(0)
        eq("%s does nothing to you" % aid, s.report()["actions_fired"], 0)


# ------------------------------------------------------------- deck & floor
def test_dig_costs_a_tick_and_refills_the_hand():
    s = _shift(floor=["easygoing"])
    _at(s)
    n = len(s.hand)
    top = s.hand[0]["id"]
    res = s.dig(0)
    check("digging is allowed", res.ok)
    eq("it costs a tick", s.tick, 1)
    eq("hand is refilled", len(s.hand), n)
    eq("the card went to discard", s.discard[-1]["id"], top)


def test_the_deck_reshuffles_when_it_runs_out():
    s = _shift(floor=["easygoing"], shift_ticks=999)
    _at(s)
    for _ in range(40):
        s.dig(0)
    eq("hand stays full", len(s.hand), s.cfg["hand_size"])
    check("it reshuffled at least once", s.reshuffles >= 1)


def test_a_freed_chair_refills_after_the_walk_up_delay():
    s = _shift(floor=["easygoing", "easygoing"], walk_up_ticks=3)
    _at(s)
    s.close()
    eq("chair is empty", s.chairs[0], None)
    s.approach(1)                                   # tick 1
    s.dig(0)                                        # tick 2
    eq("still empty after 2 ticks", s.chairs[0], None)
    s.dig(0)                                        # tick 3
    check("someone walks up on the third", s.chairs[0] is not None)


def test_an_empty_chair_burns_nobody():
    s = _shift(floor=["easygoing", "easygoing"], walk_up_ticks=99)
    _at(s)
    s.close()
    b = s.chairs[1].patience
    s.approach(1)
    eq("only the remaining customer burns", s.chairs[1].patience, b - 1)


def test_customers_do_not_all_walk_in_fresh():
    partial = 0
    for seed in range(40):
        s = _shift(floor=["easygoing"], seed=seed,
                   arrival_patience_min_fraction=0.6)
        c = s.chairs[0]
        lo = min(c.max_patience, s.cfg["arrival_patience_floor"])
        check("seed %d arrives inside the band" % seed,
              lo <= c.patience <= c.max_patience)
        if c.patience < c.max_patience:
            partial += 1
    check("and some of them are already partway to the door (%d/40)" % partial,
          partial > 0)


# ----------------------------------------------------------------- the shift
def test_the_shift_ends_at_closing_time():
    s = _shift(floor=["easygoing"], shift_ticks=3)
    _at(s)
    s.dig(0)
    s.dig(0)
    check("still open", not s.over)
    s.dig(0)
    check("closing time", s.over)
    check("nothing plays after close", not s.dig(0).ok)
    check("and you cannot sign after close", not s.close().ok)


def test_closing_time_forfeits_whatever_is_unsigned():
    s = _shift(floor=["easygoing"], shift_ticks=2)
    c = _at(s)
    c.threshold = 20
    _rank(c, ["reliability"])
    _pitch(s, "vsc")                                # 1 tick to place
    eq("agreed but unsigned", c.unsigned_margin, 1600)
    s.dig(0)                                        # tick 2 - the bell
    check("the day ended", s.over)
    eq("nothing banked", s.margin_banked, 0)
    eq("reported as lost at the bell",
       s.report()["margin_lost_to_closing"], 1600)


# -------------------------------------------------------------- generation
def test_every_archetype_produces_a_valid_priority_list():
    for aid in engine.Catalog().archetypes:
        ok = True
        for seed in range(20):
            s = _shift(floor=[aid], seed=seed, prior_slip=0.2)
            ranks = sorted(s.chairs[0].ranks.values())
            ok = ok and ranks == list(range(1, 10))
        check("%s always ranks 1-9 exactly once" % aid, ok)


def test_archetype_priors_are_reliable_but_not_certain():
    hits = 0
    trials = 200
    for seed in range(trials):
        s = _shift(floor=["tech"], seed=seed, prior_slip=0.2)
        if s.chairs[0].ranks["security"] <= 3:
            hits += 1
    rate = float(hits) / trials
    check("a tech enthusiast ranks Security top-3 far above chance"
          " (got %.2f, want 0.55-0.99)" % rate, 0.55 <= rate <= 0.99)


def test_same_seed_same_shift():
    a, b = _shift(seed=7), _shift(seed=7)
    eq("same customers", [c.name for c in a.chairs], [c.name for c in b.chairs])
    eq("same hand", [c["id"] for c in a.hand], [c["id"] for c in b.hand])
    eq("same priorities", a.chairs[0].ranks, b.chairs[0].ranks)


# -------------------------------------------------------------------- data
def test_the_starter_deck_is_fourteen_cards():
    cat = engine.Catalog()
    deck = cat.starter_deck()
    eq("fourteen cards", len(deck), 14)
    products = [c for c in deck if c["kind"] == "product"]
    eq("six of them are products", len(products), 6)
    eq("eight are support", len(deck) - len(products), 8)
    by_cat = {}
    for p in products:
        by_cat[p["category"]] = by_cat.get(p["category"], 0) + 1
    eq("two products per category, so a category read is always actionable",
       sorted(by_cat.items()),
       [("deal", 2), ("person", 2), ("vehicle", 2)])


def test_every_interest_has_exactly_one_product():
    cat = engine.Catalog()
    covered = [p["interest"] for p in cat.products]
    eq("nine products", len(covered), 9)
    eq("covering nine distinct interests", sorted(covered), sorted(cat.interests))
    for p in cat.products:
        eq("%s's category matches its interest" % p["id"],
           p["category"], cat.category_of(p["interest"]))


def test_every_archetype_states_the_pattern_it_teaches():
    """archetypes.json _DESIGN_RULE: if you cannot say it in one sentence, the
    archetype is not designed yet."""
    cat = engine.Catalog()
    for a in cat.archetypes.values():
        check("%s states its pattern" % a["id"], bool(a.get("pattern")))
        check("%s has a tell" % a["id"], bool(a.get("tell")))
        for act in a.get("actions", []):
            check("%s/%s is telegraphed" % (a["id"], act["id"]),
                  bool(act.get("tell")))
            check("%s/%s has a trigger and an effect" % (a["id"], act["id"]),
                  bool(act.get("trigger")) and bool(act.get("effect")))


def test_at_least_two_archetypes_are_in_the_players_favour():
    """Or the system reads as punishment instead of personality. A favour can
    be an action (Tech pays a premium) or a property (Family First never gets
    harder, Lay-Down starts low) - both land the same way at the table."""
    cat = engine.Catalog()
    base = cat.base
    good = []
    for a in cat.archetypes.values():
        if a["threshold"] < base["threshold"]:
            good.append(a["id"] + ":low bar")
        if a.get("threshold_per_sale", cat.config["threshold_per_sale"]) \
                < cat.config["threshold_per_sale"]:
            good.append(a["id"] + ":gentle ramp")
        for act in a.get("actions", []):
            eff = act["effect"]
            if (eff.get("margin_bonus", 0) > 0 or eff.get("threshold", 0) < 0
                    or eff.get("patience_self", 0) > 0
                    or eff.get("patience_floor", 0) > 0):
                good.append("%s:%s" % (a["id"], act["id"]))
    check("at least two archetypes do you a favour (got %s)" % (good,),
          len(good) >= 2)


def test_every_data_file_states_its_design_rule():
    import glob
    import json
    here = os.path.dirname(os.path.abspath(__file__))
    files = glob.glob(os.path.join(here, "data", "*.json"))
    check("there are data files", len(files) >= 6)
    for path in files:
        with open(path, "r", encoding="utf-8") as fh:
            d = json.load(fh)
        check("%s states its _DESIGN_RULE" % os.path.basename(path),
              bool(d.get("_DESIGN_RULE", "").strip()))


def test_objection_bands_are_sorted_and_cover_every_gap():
    cat = engine.Catalog()
    gaps = [b["max_gap"] for b in cat.objections["bands"]]
    eq("bands ascend", gaps, sorted(gaps))
    check("the last band is unreachable-high", gaps[-1] >= 45)
    for gap in range(0, 60):
        check("gap %d has a line" % gap, bool(cat.objection_for(gap)))
    for band in cat.objections["bands"]:
        check("%s has a placed-reaction line" % band["label"],
              bool(cat.objections["placed"].get(band["label"])))


def test_every_support_card_declares_its_cost():
    cat = engine.Catalog()
    for card in cat.cards.values():
        check("%s declares a tick cost" % card["id"], card.get("ticks", 0) >= 1)
        check("%s declares copies" % card["id"], card.get("copies", 0) >= 1)
        check("%s has rules text" % card["id"], bool(card.get("text")))


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
    print("\n%d checks, %d passed, %d failed"
          % (len(PASS) + len(FAIL), len(PASS), len(FAIL)))
    return 1 if FAIL else 0


if __name__ == "__main__":
    sys.exit(main())
