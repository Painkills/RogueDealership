extends RefCounted
## The model/view seam for the 3D table, tested without a single Node.
##
## Everything a dropped card does is decided by three pure functions - CardIndex,
## DropRouter and CardHomes - precisely so that the part most likely to be wrong
## is the part a headless run can actually prove. Mouse picking, tweens and
## legibility are not testable here and are not faked here.
var h: Harness

func _shift(forced: Array = [&"easygoing"]) -> Shift:
	var cfg: ShiftConfig = load("res://data/shift_config.tres").duplicate()
	cfg.patience_jitter = 0
	cfg.prior_slip = 0.0
	return Shift.new(cfg,
		load("res://data/interests/interest_pool.tres"),
		load("res://data/card_pool.tres"),
		load("res://data/archetype_pool.tres"), 1, forced)

# --- CardIndex -------------------------------------------------------------

func test_a_uid_resolves_to_its_current_hand_index() -> void:
	var s := _shift()
	h.check("the fixture has a hand to work with", s.hand.size() >= 3)
	for i in range(s.hand.size()):
		h.eq("hand[%d] resolves to %d" % [i, i], CardIndex.of(s, s.hand[i].uid), i)

func test_a_uid_still_resolves_after_the_indices_shift_under_it() -> void:
	## This is the whole reason the view holds uids and never indices.
	var s := _shift()
	var moved_uid: int = s.hand[2].uid
	s.dig(0)                       # hand[0] leaves; everything after it shifts down
	h.eq("the card that was at 2 is now at 1", CardIndex.of(s, moved_uid), 1)

func test_a_uid_that_is_not_in_hand_resolves_to_minus_one() -> void:
	var s := _shift()
	h.eq("a uid nobody holds", CardIndex.of(s, 999999), -1)
	var gone: int = s.hand[0].uid
	s.dig(0)
	h.eq("a uid that just left the hand", CardIndex.of(s, gone), -1)

# --- DropRouter ------------------------------------------------------------

func test_dropping_on_the_customer_you_are_already_with_just_plays() -> void:
	var s := _shift()
	s.approach(0)
	var plan := DropRouter.plan(s, s.hand[0].uid, CardHomes.chair_zone(0))
	h.eq("command", plan["command"], DropRouter.PLAY)
	h.eq("no approach needed - you are already there", plan["approach"], -1)

func test_dropping_on_a_different_customer_approaches_first() -> void:
	var s := _shift([&"easygoing", &"easygoing", &"easygoing"])
	s.approach(0)
	var plan := DropRouter.plan(s, s.hand[0].uid, CardHomes.chair_zone(2))
	h.eq("command", plan["command"], DropRouter.PLAY)
	h.eq("approach chair 2 first", plan["approach"], 2)

func test_dropping_on_a_customer_when_standing_nowhere_approaches_first() -> void:
	var s := _shift()
	h.eq("fixture starts on the floor", s.at, null)
	var plan := DropRouter.plan(s, s.hand[0].uid, CardHomes.chair_zone(1))
	h.eq("approach chair 1 first", plan["approach"], 1)

func test_dropping_on_the_discard_digs() -> void:
	var s := _shift()
	var plan := DropRouter.plan(s, s.hand[0].uid, CardHomes.ZONE_DISCARD)
	h.eq("command", plan["command"], DropRouter.DIG)
	h.eq("digging never moves you", plan["approach"], -1)

func test_dropping_back_into_the_hand_is_ignored_not_refused() -> void:
	## Reordering your own hand is cosmetic. It must not bounce and must not
	## reach the model - there is no model command for it.
	var s := _shift()
	var plan := DropRouter.plan(s, s.hand[0].uid, CardHomes.ZONE_HAND)
	h.eq("command", plan["command"], DropRouter.IGNORE)

func test_dropping_somewhere_meaningless_is_refused() -> void:
	var s := _shift()
	var plan := DropRouter.plan(s, s.hand[0].uid, &"draw")
	h.eq("command", plan["command"], DropRouter.NONE)
	h.check("and says why", not String(plan["reason"]).is_empty())

func test_dragging_a_card_that_is_no_longer_in_hand_is_refused() -> void:
	var s := _shift()
	var plan := DropRouter.plan(s, 999999, CardHomes.chair_zone(0))
	h.eq("command", plan["command"], DropRouter.NONE)

func test_the_router_does_not_second_guess_the_model_on_an_empty_chair() -> void:
	## "Never grey out speculatively" - the router maps geometry to commands and
	## the MODEL owns legality, so dropping on an empty chair must still route,
	## reach approach(), and come back with the model's own refusal message.
	var s := _shift()
	# All three chairs are occupied at tick 0, so empty one deliberately rather
	# than hoping the seed hands us one - a test that quietly skips itself is
	# worse than no test.
	var empty := 2
	s.chairs[empty] = null
	var plan := DropRouter.plan(s, s.hand[0].uid, CardHomes.chair_zone(empty))
	h.eq("still routed as a play", plan["command"], DropRouter.PLAY)
	var res := s.approach(empty)
	h.check("and the model is the one that says no", not res.ok)
	h.check("with a message worth showing", not res.msg.is_empty())

# --- CardHomes -------------------------------------------------------------

func test_every_card_in_the_deck_always_has_a_home() -> void:
	## If a uid could ever have no home, reconciliation would have to guess where
	## to put its node. Covering draw as well as hand/discard/table makes that
	## state unreachable by construction.
	var s := _shift()
	var homes := CardHomes.desired(s)
	var total: int = s.draw.size() + s.discard.size() + s.hand.size()
	for c in s.seated():
		if c.offer != null:
			total += 1
	h.eq("one home per physical card", homes.size(), total)
	for inst in s.hand:
		h.eq("a hand card lives in the hand", homes[inst.uid]["zone"], CardHomes.ZONE_HAND)
	for inst in s.draw:
		h.eq("a draw card lives in the draw pile", homes[inst.uid]["zone"], CardHomes.ZONE_DRAW)

func test_hand_ordinals_match_hand_order() -> void:
	var s := _shift()
	var homes := CardHomes.desired(s)
	for i in range(s.hand.size()):
		h.eq("hand[%d] keeps its place in the fan" % i, homes[s.hand[i].uid]["ordinal"], i)

func test_a_placed_product_moves_from_the_hand_to_its_customer() -> void:
	var s := _shift()
	s.approach(0)
	var uid := _first_product_uid(s)
	h.check("the seeded opening hand really does contain a product", uid != -1)
	h.eq("starts in hand", CardHomes.desired(s)[uid]["zone"], CardHomes.ZONE_HAND)
	s.place(CardIndex.of(s, uid))
	h.eq("ends up in front of the customer",
		CardHomes.desired(s)[uid]["zone"], CardHomes.chair_zone(0))

func test_a_sold_product_leaves_the_table_for_the_discard() -> void:
	## The bug this catches is "the card vanished after the sale" - the node has
	## to go somewhere, and only the model knows it went to the discard.
	var s := _shift()
	s.approach(0)
	var c: Customer = s.chairs[0]
	c.line = 0                              # guarantee the sale
	var uid := _first_product_uid(s)
	h.check("the seeded opening hand really does contain a product", uid != -1)
	s.place(CardIndex.of(s, uid))
	h.eq("on the table before offering",
		CardHomes.desired(s)[uid]["zone"], CardHomes.chair_zone(0))
	var res := s.offer()
	h.check("it sold", res.ok and res.kind == "sale")
	h.eq("and the card itself is now in the discard",
		CardHomes.desired(s)[uid]["zone"], CardHomes.ZONE_DISCARD)

func test_a_dug_card_ends_up_in_the_discard() -> void:
	var s := _shift()
	var uid: int = s.hand[0].uid
	s.dig(0)
	h.eq("dug card", CardHomes.desired(s)[uid]["zone"], CardHomes.ZONE_DISCARD)

func test_chair_zones_round_trip() -> void:
	for i in range(3):
		var z := CardHomes.chair_zone(i)
		h.check("%s reads as a chair" % z, CardHomes.is_chair_zone(z))
		h.eq("and maps back to %d" % i, CardHomes.chair_of(z), i)
	h.check("the discard is not a chair", not CardHomes.is_chair_zone(CardHomes.ZONE_DISCARD))
	h.eq("and has no chair index", CardHomes.chair_of(CardHomes.ZONE_HAND), -1)

func _first_product_uid(s: Shift) -> int:
	for inst in s.hand:
		if inst.is_product():
			return inst.uid
	return -1
