extends RefCounted
var h: Harness

func _shift(floor_ids: Array, overrides: Dictionary = {}) -> Shift:
	var cfg: ShiftConfig = (load("res://data/shift_config.tres") as ShiftConfig).duplicate()
	cfg.patience_jitter = 0
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

func test_a_two_tick_action_burns_two() -> void:
	var s := _shift([&"easygoing", &"easygoing"])
	var before: int = s.chairs[1].patience
	s._burn(2, "cards")
	h.eq("clock advanced two", s.tick, 2)
	h.eq("and so did the burn", s.chairs[1].patience, before - 2)

func test_patience_gone_means_gone() -> void:
	var s := _shift([&"easygoing", &"easygoing"])
	s.chairs[0].patience = 1
	s._burn(1, "cards")
	h.eq("they walked", s.chairs[0], null)
	h.eq("the chair is empty and waiting", s.walk_up[0], s.cfg.walk_up_ticks)

func test_a_freed_chair_refills_after_the_walk_up_delay() -> void:
	var s := _shift([&"easygoing", &"easygoing"], {"walk_up_ticks": 3})
	s.chairs[0].patience = 1
	s._burn(1, "cards")                 # they walk; the timer starts now
	h.eq("still empty", s.chairs[0], null)
	s._burn(2, "cards")
	h.eq("still empty after two more", s.chairs[0], null)
	s._burn(1, "cards")
	h.check("someone walks up on the third", s.chairs[0] != null)

func test_an_empty_chair_burns_nobody() -> void:
	var s := _shift([&"easygoing", &"easygoing"], {"walk_up_ticks": 99})
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

func test_the_starting_deck_is_fourteen_instances() -> void:
	var s := _shift([&"easygoing"])
	var total: int = s.draw.size() + s.hand.size() + s.discard.size()
	h.eq("fourteen cards in play", total, 14)
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

func test_customers_do_not_all_walk_in_fresh() -> void:
	var partial := 0
	for s in range(40):
		var cfg: ShiftConfig = (load("res://data/shift_config.tres") as ShiftConfig).duplicate()
		cfg.patience_jitter = 0
		cfg.prior_slip = 0.0
		cfg.arrival_patience_min_fraction = 0.6
		var sh := Shift.new(cfg,
			load("res://data/interests/interest_pool.tres"),
			load("res://data/card_pool.tres"),
			load("res://data/archetype_pool.tres"),
			s, [&"easygoing"])
		var c = sh.chairs[0]
		h.check("seed %d arrives inside the band" % s,
			c.patience >= min(c.max_patience, cfg.arrival_patience_floor)
			and c.patience <= c.max_patience)
		if c.patience < c.max_patience:
			partial += 1
	h.check("some arrive partway to the door (%d/40)" % partial, partial > 0)

func test_the_karen_announces_the_category_she_came_for() -> void:
	var s := _shift([&"karen"])
	var c: Customer = s.chairs[0]
	h.check("she demands something", c.demands != null)
	h.eq("and it is the category of her own number one", c.demands,
		s.interests.by_id(c.top_interest_id()).category.id)
	h.eq("which she says out loud", c.known_top_category, c.demands)

func test_the_shift_config_states_its_design_rule() -> void:
	var cfg: ShiftConfig = load("res://data/shift_config.tres")
	h.check("shift config states its design rule",
		cfg.design_rule.strip_edges() != "")
