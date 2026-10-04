extends RefCounted
var h: Harness

func _shift(floor_ids: Array, overrides: Dictionary = {}) -> Shift:
	var cfg: ShiftConfig = (load("res://data/shift_config.tres") as ShiftConfig).duplicate()
	cfg.patience_jitter = 0
	cfg.action_cadence_jitter_ticks = 0
	cfg.prior_slip = 0.0
	cfg.arrival_patience_min_fraction = 1.0
	for k in overrides:
		cfg.set(k, overrides[k])
	return Shift.new(cfg,
		load("res://data/interests/interest_pool.tres"),
		load("res://data/card_pool.tres"),
		load("res://data/archetype_pool.tres"),
		1, floor_ids)

func test_one_tick_burns_every_customer_and_the_clock() -> void:
	var s := _shift([&"easygoing", &"easygoing", &"easygoing"])
	var before := []
	for c in s.chairs:
		before.append(c.patience)
	s._burn(1, "cards")
	h.eq("clock advanced", s.tick, 1)
	for i in range(3):
		h.eq("chair %d burned" % i, s.chairs[i].patience, before[i] - 1)

func test_patience_gone_means_gone() -> void:
	var s := _shift([&"easygoing", &"easygoing"],
		{"walk_up_ticks_min": 5, "walk_up_ticks_max": 5})
	s.chairs[0].patience = 1
	s._burn(1, "cards")
	h.eq("they walked", s.chairs[0], null)
	h.check("and nobody was waiting to take the chair", s.waiting.is_empty())

func test_an_empty_chair_fills_when_the_next_customer_comes_in() -> void:
	var s := _shift([&"easygoing", &"easygoing"],
		{"walk_up_ticks_min": 3, "walk_up_ticks_max": 3})
	s.chairs[0].patience = 1
	s._burn(1, "cards")                 # they walk, one tick into the gap
	h.eq("still empty", s.chairs[0], null)
	s._burn(1, "cards")
	h.eq("still empty a tick later", s.chairs[0], null)
	s._burn(1, "cards")
	h.check("the next one in sits straight down", s.chairs[0] != null)
	h.check("rather than waiting", s.waiting.is_empty())

func test_someone_who_comes_in_to_a_full_floor_waits_for_a_chair() -> void:
	## "Know if you should keep pushing on customers on the floor or get them
	## out if they're troublesome for someone easier that's waiting."
	var s := _shift([&"easygoing"], {"walk_up_ticks_min": 1, "walk_up_ticks_max": 1,
		"waiting_max": 1})
	s._burn(1, "cards")
	h.eq("they wait, since every chair is taken", s.waiting.size(), 1)
	var next: CustomerArchetype = s.waiting[0]
	s.chairs[0].patience = 0
	s._settle_patience()
	h.check("and take the first chair that frees up, straight away",
		s.chairs[0] != null and s.chairs[0].archetype == next)
	h.check("leaving the list", not s.waiting.has(next))

func test_the_waiting_list_never_outgrows_its_room() -> void:
	var s := _shift([&"easygoing"], {"walk_up_ticks_min": 1, "walk_up_ticks_max": 1,
		"shift_ticks": 999})
	for c in s.seated():
		c.patience = 999
	# One long burn, so more come due at once than there is room for.
	s._burn(s.cfg.waiting_max + 3, "cards")
	h.eq("the list stops at its room (%d)" % s.cfg.waiting_max,
		s.waiting.size(), s.cfg.waiting_max)
	var held: int = s.next_arrival
	s._burn(1, "cards")
	h.eq("and the door's clock waits while it is full", s.next_arrival, held)
	h.eq("so nobody is due", s.next_arrival_in(), -1)

func test_an_empty_chair_burns_nobody() -> void:
	var s := _shift([&"easygoing", &"easygoing"],
		{"walk_up_ticks_min": 99, "walk_up_ticks_max": 99})
	s.chairs[0].patience = 1
	s._burn(1, "cards")
	var b: int = s.chairs[1].patience
	s._burn(1, "cards")
	h.eq("only the remaining customer burns", s.chairs[1].patience, b - 1)

func test_the_shift_ends_at_closing_time() -> void:
	var s := _shift([&"easygoing"], {"shift_ticks": 3})
	s._burn(2, "cards")
	h.check("still open", not s.is_over())
	s._burn(1, "cards")
	h.check("closing time", s.is_over())

func test_the_starting_hand_is_filled_to_its_configured_size() -> void:
	var s := _shift([&"easygoing"])
	h.eq("hand filled to size", s.hand.size(), s.cfg.hand_size)

func test_every_card_instance_has_its_own_uid() -> void:
	var s := _shift([&"easygoing"])
	var seen := {}
	for pile in [s.draw, s.hand, s.discard]:
		for c in pile:
			h.check("uid %d is unique" % c.uid, not seen.has(c.uid))
			seen[c.uid] = true

func test_the_deck_reshuffles_when_it_runs_out() -> void:
	var s := _shift([&"easygoing"], {"shift_ticks": 999})
	for _i in range(40):
		s.discard.append(s.hand.pop_back())
		s._draw_up()
	h.eq("hand stays full", s.hand.size(), s.cfg.hand_size)
	h.check("it reshuffled", s.reshuffles >= 1)

func _seeded(seed_value: int, overrides: Dictionary = {}) -> Shift:
	var cfg: ShiftConfig = (load("res://data/shift_config.tres") as ShiftConfig).duplicate()
	cfg.patience_jitter = 0
	cfg.action_cadence_jitter_ticks = 0
	cfg.prior_slip = 0.0
	cfg.arrival_patience_min_fraction = 1.0
	for k in overrides:
		cfg.set(k, overrides[k])
	return Shift.new(cfg,
		load("res://data/interests/interest_pool.tres"),
		load("res://data/card_pool.tres"),
		load("res://data/archetype_pool.tres"),
		seed_value, [&"easygoing"])

func _products_in(pile: Array) -> int:
	var n := 0
	for c in pile:
		if c.is_product():
			n += 1
	return n

func test_no_opening_hand_is_ever_dealt_without_a_product() -> void:
	## A hand of pure support against a seated customer is nearly a dead turn:
	## needs_offer defaults to true, so 7 of the 10 starter support cards refuse
	## to play with an empty table, leaving Read the Room and two Small Talks,
	## and then dig at a tick a card. Unbiased, C(10,5)/C(16,5) = 5.8% of hands
	## land there - so 300 seeds catch a regression essentially every time.
	var without: Array[int] = []
	for seed_value in range(1, 301):
		if _products_in(_seeded(seed_value).hand) < 1:
			without.append(seed_value)
	h.check("every opening hand holds a product (seeds without: %s)" % str(without),
		without.is_empty())

func test_the_floor_holds_on_mid_shift_refills_not_just_the_opening_deal() -> void:
	## The opening deal is the easy case. The bite is mid-shift, once placed
	## products have left the draw pile support-heavy - a fix applied only in
	## _init would pass the sweep above and still strand you here.
	var s := _shift([&"easygoing"], {"shift_ticks": 999})
	var bad_rounds: Array[int] = []
	for round_no in range(30):
		for i in range(s.hand.size() - 1, -1, -1):
			if s.hand[i].is_product():
				s.discard.append(s.hand.pop_at(i))
		s._draw_up()
		if _products_in(s.hand) < 1 or s.hand.size() != s.cfg.hand_size:
			bad_rounds.append(round_no)
	h.check("every refill leaves a product in a full hand (rounds that did not: %s)"
		% str(bad_rounds), bad_rounds.is_empty())

func test_a_deck_with_no_products_fills_the_hand_instead_of_hanging() -> void:
	## The floor is best-effort. With nothing to reach for, _top_product_index()
	## returns -1 and the draw falls back to the top card - a product that is not
	## in circulation cannot be conjured. Spelled out in the code because
	## pop_at(-1) pops the top card anyway and would have hidden the miss.
	var pool: CardPool = load("res://data/card_pool.tres")
	var support_only := Deck.new()
	for c in pool.cards:
		if not (c is ProductCardDef):
			support_only.add(c)
			support_only.add(c)
	var cfg: ShiftConfig = (load("res://data/shift_config.tres") as ShiftConfig).duplicate()
	cfg.patience_jitter = 0
	cfg.action_cadence_jitter_ticks = 0
	cfg.prior_slip = 0.0
	var s := Shift.new(cfg,
		load("res://data/interests/interest_pool.tres"), pool,
		load("res://data/archetype_pool.tres"),
		1, [&"easygoing"], support_only)
	h.eq("the hand still filled", s.hand.size(), cfg.hand_size)
	h.eq("with no product, because there was none to find",
		_products_in(s.hand), 0)
	s.dig(0)
	h.eq("and digging refills without hanging", s.hand.size(), cfg.hand_size)

func test_same_seed_same_shift() -> void:
	var a := _shift([])
	var b := _shift([])
	var an := []
	var bn := []
	for c in a.chairs:
		an.append(c.display_name)
	for c in b.chairs:
		bn.append(c.display_name)
	h.eq("same customers", an, bn)
	var ah := []
	var bh := []
	for c in a.hand:
		ah.append(c.card.id)
	for c in b.hand:
		bh.append(c.card.id)
	h.eq("same hand", ah, bh)
	h.eq("same priorities", a.chairs[0].ranks, b.chairs[0].ranks)
