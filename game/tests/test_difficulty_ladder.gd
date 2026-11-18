extends RefCounted
## The difficulty ladder (DifficultyLadder): a day's target spread across its
## slots, and every shift built to its slot's target from priced modifiers and
## customers (ShiftGenerator.fill_to_ladder). Made-up archetypes, points and
## modifiers only - the rules, never today's tuning.
var h: Harness

func _arch(id: StringName, points: int, min_difficulty: int = 0) -> CustomerArchetype:
	var a := CustomerArchetype.new()
	a.id = id
	a.display_name = String(id)
	a.difficulty = points
	a.min_difficulty = min_difficulty
	a.weight = 1.0
	return a

func _archetypes(list: Array) -> ArchetypePool:
	var typed: Array[CustomerArchetype] = []
	typed.assign(list)
	var p := ArchetypePool.new()
	p.design_rule = "test double"
	p.archetypes = typed
	return p

func _points() -> ArchetypePool:
	return _archetypes([_arch(&"one", 1), _arch(&"two", 2), _arch(&"three", 3)])

func _tier(customers: int = 5) -> ShiftProfile:
	var t := ShiftProfile.new()
	t.id = &"morning"
	t.customers = customers
	return t

func _mod(id: StringName, fields: Dictionary, points: int) -> ShiftComplicator:
	var c := ShiftComplicator.new()
	c.id = id
	c.display_text = String(id)
	c.points = points
	c.on_regular_shifts = true
	for f in fields:
		c.set(f, fields[f])
	return c

## A small price list: quota steps, a condition, seat counts (one easier than
## the rest) and an easing step.
func _modifiers() -> Array:
	return [
		_mod(&"quota_a", {"quota_scale": 1.1}, 2),
		_mod(&"quota_b", {"quota_scale": 1.3}, 4),
		_mod(&"quota_c", {"quota_scale": 1.6}, 8),
		_mod(&"crowd", {"line_offset": 2}, 3),
		_mod(&"seat_1", {"seats": 1, "customers": 3}, -1),
		_mod(&"seat_2", {"seats": 2, "customers": 4}, 0),
		_mod(&"seat_3", {"seats": 3, "customers": 5}, 1),
		_mod(&"more_time", {"ticks_delta": 3}, -3),
	]

func _ladder(start: float = 10.0, per_day: float = 0.0, spread: Array = [0]) -> DifficultyLadder:
	var l := DifficultyLadder.new()
	l.start = start
	l.per_day = per_day
	l.spread.assign(spread)
	return l

func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng

func _fill(target: int, seed_value: int, ladder: DifficultyLadder = null,
		archetypes: ArchetypePool = null, tolerance: int = 1) -> ShiftProfile:
	var tier := _tier()
	return ShiftGenerator.fill_to_ladder(tier, tier, 1, 1, target,
		archetypes if archetypes != null else _points(), _modifiers(),
		ladder if ladder != null else _ladder(), tolerance, _rng(seed_value))

func _total(p: ShiftProfile) -> int:
	var total := 0
	for a in p.lineup:
		total += a.difficulty
	for c in p.complicators:
		total += c.points
	return total

func _with(p: ShiftProfile, field: StringName) -> Array:
	return p.complicators.filter(func(c): return c.touches().has(field))

# ------------------------------------------------------------------ the plan
func test_a_days_target_climbs_by_the_ladder() -> void:
	var l := _ladder(10, 2)
	h.eq("day 1 is the start", l.target_on(1), 10)
	h.eq("and each day after climbs by the step", l.target_on(4), 16)

func test_the_spread_gives_each_slot_its_own_offset_in_an_order_drawn_for_the_day() -> void:
	var l := _ladder(10, 0, [-2, 0, 2])
	var orders := {}
	var wrong := []
	for seed_value in range(30):
		var t := l.targets_on(1, 3, _rng(seed_value))
		var sorted := t.duplicate()
		sorted.sort()
		if sorted != [8, 10, 12]:
			wrong.append(t)
		orders[str(t)] = true
	h.check("every day the three slots get the three offsets (%s)" % str(wrong), wrong.is_empty())
	h.check("in more than one order (%d seen)" % orders.size(), orders.size() > 1)
	h.eq("the same draw, the same order", l.targets_on(1, 3, _rng(5)), l.targets_on(1, 3, _rng(5)))
	var short := _ladder(10, 0, [2]).targets_on(1, 3, _rng(1))
	short.sort()
	h.eq("slots past the offsets get the day's own", short, [10, 10, 12])

# --------------------------------------------------------------- the build
func test_a_shift_lands_on_its_target_from_its_modifiers_and_customers() -> void:
	var missed := []
	var untrue := []
	for target in range(8, 21):
		for seed_value in range(6):
			var s := _fill(target, seed_value)
			if absi(s.difficulty - target) > 1:
				missed.append([target, seed_value, s.difficulty])
			if s.difficulty != _total(s):
				untrue.append([target, seed_value])
	h.check("within tolerance of every target (missed: %s)" % str(missed), missed.is_empty())
	h.check("and its difficulty is what it is made of (%s)" % str(untrue), untrue.is_empty())

func test_the_quota_takes_the_dearest_step_its_share_affords() -> void:
	var l := _ladder()
	l.quota_share_min = 0.5
	l.quota_share_max = 0.5
	l.conditions_share_min = 0.0
	l.conditions_share_max = 0.0
	var big := _with(_fill(16, 1, l), &"quota")
	h.check("half of 16 buys the 8-point step", big.size() == 1 and big[0].points == 8)
	var small := _with(_fill(9, 1, l), &"quota")
	h.check("half of 9 buys the 4-point one", small.size() == 1 and small[0].points == 4)

func test_a_seat_count_brings_its_own_lineup_length() -> void:
	var wrong := []
	for seed_value in range(20):
		var s := _fill(14, seed_value)
		var seats := _with(s, &"seats")
		if seats.size() != 1 or s.lineup.size() != s.customers_on() \
				or s.lineup.size() != seats[0].customers or s.seats_on() != seats[0].seats:
			wrong.append(seed_value)
	h.check("one seat count, and as many customers as it brings (%s)" % str(wrong), wrong.is_empty())

func test_easing_comes_in_only_when_even_the_gentlest_shift_is_over_the_target() -> void:
	var low := _fill(0, 1, null, null, 0)
	h.check("a target under the gentlest shift is eased (%s)"
		% str(low.complicators.map(func(c): return c.id)),
		low.complicators.any(func(c): return c.points < 0 and c.seats == 0))
	var wrong := []
	for seed_value in range(10):
		var s := _fill(16, seed_value)
		if s.complicators.any(func(c): return c.points < 0 and c.seats == 0):
			wrong.append(seed_value)
	h.check("and a harder one never is (%s)" % str(wrong), wrong.is_empty())

func test_a_harder_customer_waits_for_a_target_that_allows_them() -> void:
	var tough := _arch(&"tough", 3, 15)
	var pool := _archetypes([_arch(&"one", 1), _arch(&"two", 2), tough])
	var early := 0
	var late := 0
	for seed_value in range(20):
		early += _fill(12, seed_value, null, pool).lineup.count(tough)
		late += _fill(20, seed_value, null, pool).lineup.count(tough)
	h.eq("never under their difficulty", early, 0)
	h.check("and they come once it is reached (%d)" % late, late > 0)

# ------------------------------------------------------------------ the week
func _ladder_pool(spread: Array) -> ShiftProfilePool:
	var pool := ShiftProfilePool.new()
	var tiers: Array[ShiftProfile] = []
	for id in ShiftCategory.SLOTS:
		var t := ShiftProfile.new()
		t.id = id
		t.customers = 5
		tiers.append(t)
	pool.profiles = tiers
	pool.complicators.assign(_modifiers())
	pool.ladder = _ladder(12, 1, spread)
	return pool

func _cfg() -> ShiftConfig:
	var cfg: ShiftConfig = (load("res://data/shift_config.tres") as ShiftConfig).duplicate()
	cfg.difficulty_tolerance = 1
	return cfg

func test_a_ladder_week_deals_every_slot_to_its_planned_target() -> void:
	var pool := _ladder_pool([-2, 0, 2])
	var week := Week.new(pool, 4, 3, 6, _points(), _cfg())
	var wrong := []
	for day in range(1, 5):
		var planned := []
		for p in week.offers(day):
			planned.append(p.planned)
			if absi(p.difficulty - p.planned) > 1:
				wrong.append([day, p.id, p.planned, p.difficulty])
		planned.sort()
		var base := pool.ladder.target_on(day)
		if planned != [base - 2, base, base + 2]:
			wrong.append([day, planned])
	h.check("each slot planned from the day's target and dealt to it (%s)" % str(wrong),
		wrong.is_empty())

func test_the_weekday_sets_the_seats_whatever_they_cost() -> void:
	var pool := _ladder_pool([0])
	pool.ladder.seats_by_weekday.assign([1, 2, 3])
	var week := Week.new(pool, 4, 2, 6, _points(), _cfg())
	var seen := []
	for day in range(1, 5):
		seen.append(week.offers(day).map(func(p): return p.seats_on()))
	h.eq("one, then two, then three - and the ladder picks past the list",
		seen.slice(0, 3), [[1, 1, 1], [2, 2, 2], [3, 3, 3]])
	h.check("each still within reach of its target",
		week.offers(1).all(func(p): return absi(p.difficulty - p.planned) <= 1))

func test_on_the_ladder_a_hard_shift_takes_the_days_hardest_slot() -> void:
	var pool := _ladder_pool([-2, 0, 2])
	var hard := ShiftProfile.new()
	hard.id = &"made_up_hard"
	hard.customers = 3
	var category := ShiftCategory.new()
	category.days = 0b111111
	category.slots = 0b111
	category.boss_day = true
	category.shifts.append(hard)
	pool.categories.append(category)
	var wrong := []
	for seed_value in range(6):
		var offers := Week.new(pool, 1, seed_value, 6, _points(), _cfg()).offers(1)
		var top := 0
		for p in offers:
			top = maxi(top, p.planned)
		var dealt := offers.filter(func(p): return p.id == &"made_up_hard")
		if dealt.size() != 1 or dealt[0].planned != top:
			wrong.append(seed_value)
	h.check("always in the slot planned hardest (%s)" % str(wrong), wrong.is_empty())

# ---------------------------------------------------------- reaching the floor
func test_a_modifiers_seats_waiting_room_and_product_quota_reach_the_shift() -> void:
	var run := RunState.new(load("res://data/shift_config.tres"),
		load("res://data/interests/interest_pool.tres"), load("res://data/card_pool.tres"),
		load("res://data/archetype_pool.tres"), 7)
	var p := ShiftProfile.new()
	p.id = &"made_up"
	p.complicators.assign([
		_mod(&"two_seats", {"seats": 2, "customers": 4}, 0),
		_mod(&"one_waiting", {"waiting_room": 1}, 0),
		_mod(&"sell_two", {"product_quota_count": 2}, 0),
	])
	var s := run.start_shift(p)
	h.eq("two chairs", s.chairs.size(), 2)
	h.eq("one may wait", s.cfg.waiting_max, 1)
	h.eq("two to sell", s.category_quota_count, 2)
	h.eq("from the day's category", s.category_quota, run.day_category(run.shift_number).id)
