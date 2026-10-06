extends RefCounted
## ShiftGenerator: a slot's shift built to its difficulty target - who comes in,
## and the complicators a premade shift that scales comes with. Made-up
## archetypes, points and complicators only, so these check the rules and never
## today's tuning.
var h: Harness

func _arch(id: StringName, points: int, hard: bool = false,
		from_week: int = 1) -> CustomerArchetype:
	var a := CustomerArchetype.new()
	a.id = id
	a.display_name = String(id)
	a.difficulty = points
	a.hard = hard
	a.from_week = from_week
	a.weight = 1.0
	return a

func _pool(archetypes: Array) -> ArchetypePool:
	var typed: Array[CustomerArchetype] = []
	typed.assign(archetypes)
	var p := ArchetypePool.new()
	p.design_rule = "test double"
	p.archetypes = typed
	return p

func _tier(customers: int) -> ShiftProfile:
	var t := ShiftProfile.new()
	t.id = &"morning"
	t.customers = customers
	return t

func _complicator(id: StringName, field: StringName, value, points: int = 1,
		from_day: int = 1) -> ShiftComplicator:
	var c := ShiftComplicator.new()
	c.id = id
	c.display_text = String(id)
	c.points = points
	c.from_day = from_day
	c.set(field, value)
	return c

func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng

## A regular shift - the tier filled on its own.
func _regular(pool: ArchetypePool, tier: ShiftProfile, target: int, seed_value: int,
		week: int = 1) -> ShiftProfile:
	return ShiftGenerator.fill(tier, tier, 1, week, target, pool, [], 0.0, _rng(seed_value))

func _count(lineup: Array, a: CustomerArchetype) -> int:
	return lineup.filter(func(x): return x == a).size()

func _sum(lineup: Array) -> int:
	var total := 0
	for a in lineup:
		total += a.difficulty
	return total

# ---------------------------------------------------------------- customers
func test_a_lineup_is_the_tiers_length_and_lands_on_a_reachable_target() -> void:
	var pool := _pool([_arch(&"one", 1), _arch(&"two", 2), _arch(&"three", 3)])
	var tier := _tier(5)
	var missed: Array = []
	for target in range(5, 16):
		for seed_value in range(8):
			var s := _regular(pool, tier, target, seed_value)
			if s.lineup.size() != 5 or _sum(s.lineup) != target or s.difficulty != target:
				missed.append([target, seed_value])
	h.check("every target from the cheapest to the dearest lineup is hit exactly (missed: %s)"
		% str(missed), missed.is_empty())
	h.check("and the authored tier is never touched", tier.lineup.is_empty())

func test_an_unreachable_target_comes_as_near_as_the_pool_allows() -> void:
	var one := _arch(&"one", 1)
	var three := _arch(&"three", 3)
	var pool := _pool([one, three])
	var low := _regular(pool, _tier(4), 1, 3)
	h.eq("too easy: the cheapest lineup", _count(low.lineup, one), 4)
	h.eq("and it says what it came to", low.difficulty, 4)
	var high := _regular(pool, _tier(4), 99, 3)
	h.eq("too hard: the dearest lineup", _count(high.lineup, three), 4)
	h.eq("and it says what it came to", high.difficulty, 12)

func test_a_bigger_budget_affords_more_of_the_same_difficult_one() -> void:
	## "On day 1 you can see a Family First, but no more than one. On day 4,
	## two of them."
	var easy := _arch(&"easy", 1)
	var middling := _arch(&"middling", 2)
	var pool := _pool([easy, middling])
	for seed_value in range(6):
		h.eq("seed %d: a point over the cheapest buys one" % seed_value,
			_count(_regular(pool, _tier(5), 6, seed_value).lineup, middling), 1)
		h.eq("seed %d: three over buys three" % seed_value,
			_count(_regular(pool, _tier(5), 8, seed_value).lineup, middling), 3)

func test_nobody_comes_before_their_week_or_from_outside_who_the_shift_allows() -> void:
	var easy := _arch(&"easy", 1)
	var late := _arch(&"late", 9, false, 2)
	var kept_out := _arch(&"kept_out", 2)
	var pool := _pool([easy, late, kept_out])
	var tier := _tier(5)
	tier.excluded_archetypes.assign([kept_out])
	var seen := {}
	for seed_value in range(10):
		for a in _regular(pool, tier, 40, seed_value).lineup:
			seen[a] = true
	h.check("week 1 never sends the late one, however big the budget", not seen.has(late))
	h.check("and the slot's exclusions hold", not seen.has(kept_out))
	h.check("week 2 can send them", _regular(pool, tier, 40, 1, 2).lineup.has(late))
	var only := ShiftProfile.new()
	only.only_archetypes.assign([kept_out])
	var named := ShiftGenerator.fill(only, tier, 1, 1, 40, pool, [], 0.0, _rng(1))
	h.check("a shift that names its customers gets only them",
		named.lineup.all(func(a): return a == kept_out))

func test_a_hard_one_comes_once_unless_the_slot_allows_more_or_there_is_nobody_else() -> void:
	var easy := _arch(&"easy", 1)
	var hard_a := _arch(&"hard_a", 4, true)
	var hard_b := _arch(&"hard_b", 4, true)
	var pool := _pool([easy, hard_a, hard_b])
	for seed_value in range(6):
		var lineup := _regular(pool, _tier(5), 99, seed_value).lineup
		h.check("seed %d: each hard one at most once" % seed_value,
			_count(lineup, hard_a) <= 1 and _count(lineup, hard_b) <= 1)
	var doubles := _tier(5)
	doubles.allow_hard_duplicates = true
	h.eq("a slot that allows it can fill up on them",
		_regular(pool, doubles, 99, 1).difficulty, 20)
	var only_hard := _pool([hard_a])
	h.eq("and with nobody else to send, the rule gives way",
		_regular(only_hard, _tier(5), 20, 1).lineup.size(), 5)

func test_the_same_seed_builds_the_same_shift() -> void:
	var pool := _pool([_arch(&"one", 1), _arch(&"two", 2), _arch(&"three", 3)])
	var a := _regular(pool, _tier(5), 10, 42)
	var b := _regular(pool, _tier(5), 10, 42)
	h.eq("same lineup", a.lineup, b.lineup)

# ------------------------------------------------------------- complicators
func _scaling(rules_points: int = 0) -> ShiftProfile:
	var s := ShiftProfile.new()
	s.id = &"scaling"
	s.difficulty = rules_points
	return s

func _fill(shift: ShiftProfile, pool: ArchetypePool, target: int, complicators: Array,
		share: float, seed_value: int, day: int = 1) -> ShiftProfile:
	return ShiftGenerator.fill(shift, _tier(5), day, 1, target, pool, complicators, share,
		_rng(seed_value))

func _all_kinds(points: int = 1, from_day: int = 1) -> Array:
	return [
		_complicator(&"line", &"line_offset", 2, points, from_day),
		_complicator(&"ticks", &"ticks_delta", -2, points, from_day),
		_complicator(&"patience", &"patience_scale", 0.8, points, from_day),
		_complicator(&"hand", &"hand_size_delta", -1, points, from_day),
		_complicator(&"combo", &"combo_scale", 0.5, points, from_day),
	]

func test_a_scaling_shift_pays_for_its_own_rules_then_fills_the_rest() -> void:
	var pool := _pool([_arch(&"one", 1), _arch(&"two", 2), _arch(&"three", 3)])
	var s := _fill(_scaling(3), pool, 12, [], 0.0, 1)
	h.eq("its customers bring what its rules leave", _sum(s.lineup), 9)
	h.eq("and the copy says the total", s.difficulty, 12)
	h.eq("the authored shift still says what its rules add", _scaling(3).difficulty, 3)

func test_no_complicators_when_there_is_nothing_spare_and_more_as_the_target_climbs() -> void:
	var pool := _pool([_arch(&"one", 1), _arch(&"three", 3)])
	var kinds := _all_kinds()
	h.eq("the cheapest lineup's target leaves nothing to spend",
		_fill(_scaling(), pool, 5, kinds, 0.5, 1).complicators.size(), 0)
	var low := 0
	var high := 0
	for seed_value in range(10):
		low += _fill(_scaling(), pool, 7, kinds, 0.5, seed_value).complicators.size()
		high += _fill(_scaling(), pool, 15, kinds, 0.5, seed_value).complicators.size()
	h.check("a harder slot brings more of them (%d against %d)" % [high, low], high > low)
	for seed_value in range(10):
		var s := _fill(_scaling(), pool, 13, kinds, 0.5, seed_value)
		h.eq("seed %d: still lands on the target" % seed_value, s.difficulty, 13)

func test_complicators_never_touch_the_shifts_own_rules_or_each_other() -> void:
	var pool := _pool([_arch(&"one", 1)])
	var own := _scaling()
	own.hand_size = 4
	var two_lines := [_complicator(&"line_a", &"line_offset", 1),
		_complicator(&"line_b", &"line_offset", 2)]
	var kinds := _all_kinds() + two_lines
	for seed_value in range(12):
		var s := _fill(own, pool, 99, kinds, 1.0, seed_value)
		var touched := {}
		var clash := false
		for c in s.complicators:
			for t in c.touches():
				clash = clash or touched.has(t)
				touched[t] = true
		h.check("seed %d: no hand on a shift with its own hand" % seed_value,
			not touched.has(&"hand"))
		h.check("seed %d: no two changing the same rule" % seed_value, not clash)

func test_a_complicator_waits_for_its_day() -> void:
	var pool := _pool([_arch(&"one", 1)])
	var late := _all_kinds(1, 5)
	h.eq("not before", _fill(_scaling(), pool, 99, late, 1.0, 1, 4).complicators.size(), 0)
	h.check("from then on", _fill(_scaling(), pool, 99, late, 1.0, 1, 5).complicators.size() > 0)

func test_complicators_make_up_what_customers_cannot_reach() -> void:
	## Week 1 has nobody harder to send: a scaling shift still gets to its target.
	var pool := _pool([_arch(&"one", 1)])
	var s := _fill(_scaling(), pool, 8, _all_kinds(1), 0.0, 1)
	h.eq("the customers give all they can", _sum(s.lineup), 5)
	h.eq("and complicators the rest", s.difficulty, 8)

func test_a_regular_shift_never_gets_complicators() -> void:
	var pool := _pool([_arch(&"one", 1)])
	var tier := _tier(5)
	var s := ShiftGenerator.fill(tier, tier, 1, 1, 99, pool, _all_kinds(), 1.0, _rng(1))
	h.eq("customers only", s.complicators.size(), 0)
