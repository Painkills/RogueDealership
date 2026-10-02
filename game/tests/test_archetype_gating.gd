extends RefCounted
## Who is allowed to walk in, and when.
##
## The Tire Kicker has nine ticks of patience against a default sixteen, and the
## Karen demands a category AND drains the whole floor. They are the two hardest
## problems in the game and both could open a first-ever run.
var h: Harness

func _pool() -> ArchetypePool:
	return load("res://data/archetype_pool.tres")

func _shift(shift_number: int, seed_value: int) -> Shift:
	return Shift.new(load("res://data/shift_config.tres"),
		load("res://data/interests/interest_pool.tres"),
		load("res://data/card_pool.tres"), _pool(),
		seed_value, [], null, 0, shift_number)

func test_every_archetype_has_a_sane_min_shift() -> void:
	## The ladder's own shape (which archetype opens on which shift) is a
	## balance choice, authored per-archetype in its own .tres - what has to
	## hold regardless is that every min_shift is a real, positive shift
	## number, and that a run always has SOMETHING to seat on shift 1.
	var pool := _pool()
	h.check("the pool has at least one archetype", pool.archetypes.size() >= 1)
	var opens_shift_one := false
	for a in pool.archetypes:
		h.check("%s's min_shift is at least 1" % a.id, a.min_shift >= 1)
		if a.min_shift <= 1:
			opens_shift_one = true
	h.check("at least one archetype can open a run on shift 1", opens_shift_one)

func test_a_shift_never_seats_an_archetype_before_its_own_min_shift() -> void:
	var pool := _pool()
	var latest_min_shift := 1
	for a in pool.archetypes:
		latest_min_shift = maxi(latest_min_shift, a.min_shift)
	for shift_number in range(1, latest_min_shift + 1):
		for seed_value in range(40):
			for c in _shift(shift_number, seed_value).seated():
				h.check("shift %d seats only archetypes whose min_shift allows it (got %s, min_shift %d)"
					% [shift_number, c.archetype.id, c.archetype.min_shift],
					c.archetype.min_shift <= shift_number)

func test_every_archetype_does_turn_up_once_its_own_min_shift_arrives() -> void:
	var pool := _pool()
	for a in pool.archetypes:
		var seen := false
		for seed_value in range(60):
			for c in _shift(a.min_shift, seed_value).seated():
				if c.archetype.id == a.id:
					seen = true
					break
			if seen:
				break
		h.check("%s turns up by shift %d (its own min_shift)" % [a.id, a.min_shift], seen)

func test_a_floor_still_fills_when_the_gate_leaves_too_few() -> void:
	## Shift 1 offers only the archetypes gentle enough to open a run - fewer
	## than a full floor. The unique-archetype filter is already guarded by
	## "if not fresh.is_empty()", so the extra chairs simply repeat one rather
	## than sitting empty.
	var s := _shift(1, 11)
	h.eq("every chair is filled", s.seated().size(), s.cfg.floor_size)

func test_unlock_full_archetype_pool_ignores_min_shift() -> void:
	## The ShiftProfile a night pick threads through - see RunState.start_shift()
	## and ShiftProfile.unlock_full_archetype_pool - makes the WHOLE pool fair
	## game on shift 1, not just whoever's own min_shift already allows it.
	var pool := _pool()
	var latest: CustomerArchetype = pool.archetypes[0]
	for a in pool.archetypes:
		if a.min_shift > latest.min_shift:
			latest = a
	var seen := false
	for seed_value in range(60):
		var s := Shift.new(load("res://data/shift_config.tres"),
			load("res://data/interests/interest_pool.tres"),
			load("res://data/card_pool.tres"), pool,
			seed_value, [], null, 0, 1, 0, 0, null, 0, 1.0, 1.0, true)
		for c in s.seated():
			if c.archetype.id == latest.id:
				seen = true
				break
		if seen:
			break
	h.check("%s (min_shift %d) can appear on shift 1 once unlocked"
		% [latest.id, latest.min_shift], seen)

func test_an_empty_gated_pool_falls_back_rather_than_crashing() -> void:
	## Misauthored data - every min_shift set past the end of the run - would
	## otherwise index an empty array and take the game down on spawn. Built from
	## a fresh archetype rather than by mutating a loaded one: Resources are
	## cached project-wide and editing one here would corrupt every later test.
	var real: CustomerArchetype = _pool().archetypes[0]
	var late := CustomerArchetype.new()
	late.id = &"late"
	late.display_name = "Late Bloomer"
	late.pattern = "test double"
	late.line = real.line
	late.patience = real.patience
	late.line_per_sale = real.line_per_sale
	late.top_interests = real.top_interests
	late.bottom_interests = real.bottom_interests
	late.min_shift = 99

	var only_late: Array[CustomerArchetype] = [late]
	var pool := ArchetypePool.new()
	pool.design_rule = "test double"
	pool.names = _pool().names.duplicate()
	pool.archetypes = only_late

	var s := Shift.new(load("res://data/shift_config.tres"),
		load("res://data/interests/interest_pool.tres"),
		load("res://data/card_pool.tres"), pool, 7, [], null, 0, 1)
	h.eq("the floor still filled", s.seated().size(), s.cfg.floor_size)
	h.eq("from the fallback pool", s.seated()[0].archetype.id, &"late")

# ------------------------------------------------------------- the weights
# A pool of copies of the real archetypes, every one open on day 1 at weight 1
# and not hard, then `setup` - so these check the rule, not today's tuning.

func _made_up(setup: Callable) -> ArchetypePool:
	var real := _pool()
	var typed: Array[CustomerArchetype] = []
	for a in real.archetypes:
		var copy := a.duplicate() as CustomerArchetype
		copy.min_shift = 1
		copy.weight = 1.0
		copy.hard = false
		setup.call(copy)
		typed.append(copy)
	var p := ArchetypePool.new()
	p.design_rule = "test double"
	p.names = real.names.duplicate()
	p.archetypes = typed
	return p

func _on(pool: ArchetypePool, seed_value: int) -> Shift:
	return Shift.new(load("res://data/shift_config.tres"),
		load("res://data/interests/interest_pool.tres"),
		load("res://data/card_pool.tres"), pool, seed_value, [], null, 0, 1)

## How many of `n` picks from the whole of `pool` were `id`.
func _share(s: Shift, pool: ArchetypePool, id: StringName, n: int) -> float:
	var hits := 0
	for _i in range(n):
		if s._weighted_archetype(pool.archetypes).id == id:
			hits += 1
	return float(hits) / float(n)

func test_a_weight_of_nothing_never_comes_in() -> void:
	var never := _pool().archetypes[0].id
	var pool := _made_up(func(a): if a.id == never: a.weight = 0.0)
	var came := false
	for seed_value in range(30):
		var s := _on(pool, seed_value)
		for c in s.seated():
			came = came or c.archetype.id == never
		for _i in range(10):
			came = came or s._pick_archetype().id == never
	h.check("an archetype weighted 0 never walks in", not came)

func test_the_heavier_an_archetype_the_more_often_it_comes() -> void:
	var heavy := _pool().archetypes[0].id
	var pool := _made_up(func(a): if a.id == heavy: a.weight = 20.0)
	var share := _share(_on(pool, 3), pool, heavy, 600)
	h.check("weighted twenty to everyone else's one, it is most of the door (%.2f)" % share,
		share > 0.6)

func test_a_shift_can_weight_the_hard_ones_up() -> void:
	var tough := _pool().archetypes[0].id
	var pool := _made_up(func(a): if a.id == tough: a.hard = true)
	var s := _on(pool, 5)
	var plain := _share(s, pool, tough, 600)
	s.hard_weight_scale = 6.0
	var scaled := _share(s, pool, tough, 600)
	h.check("the hard one comes far more often at 6x (%.2f, was %.2f)" % [scaled, plain],
		scaled > plain * 2.0)

func test_never_two_of_the_same_hard_one_on_the_floor() -> void:
	var pool := _made_up(func(a): a.hard = true)
	for seed_value in range(40):
		var ids := {}
		for c in _on(pool, seed_value).seated():
			h.check("seed %d seats %s only once" % [seed_value, c.archetype.id],
				not ids.has(c.archetype.id))
			ids[c.archetype.id] = true

func test_but_two_of_an_easy_one_can_share_it() -> void:
	var common := _pool().archetypes[0].id
	var pool := _made_up(func(a): if a.id == common: a.weight = 50.0)
	var doubled := false
	for seed_value in range(40):
		var n := 0
		for c in _on(pool, seed_value).seated():
			if c.archetype.id == common:
				n += 1
		doubled = doubled or n >= 2
	h.check("a common, not-hard archetype sometimes sits at two desks at once", doubled)

## A shift of `pool` opened with `arrivals` - the ShiftProfile knobs RunState
## hands Shift.new().
func _opened_with(pool: ArchetypePool, seed_value: int, arrivals: Dictionary) -> Shift:
	return Shift.new(load("res://data/shift_config.tres"),
		load("res://data/interests/interest_pool.tres"),
		load("res://data/card_pool.tres"), pool, seed_value, [], null, 0, 1, 0, 0,
		null, 0, 1.0, 1.0, false, [], [], [], arrivals)

func test_a_shift_can_let_two_of_a_hard_one_share_the_floor() -> void:
	var tough := _pool().archetypes[0].id
	var pool := _made_up(func(a):
		a.hard = true
		if a.id == tough: a.weight = 50.0)
	var doubled := false
	var doubled_anyway := false
	for seed_value in range(40):
		for allowed in [true, false]:
			var n := 0
			for c in _opened_with(pool, seed_value, {"allow_hard_duplicates": allowed}).seated():
				if c.archetype.id == tough:
					n += 1
			if allowed:
				doubled = doubled or n >= 2
			else:
				doubled_anyway = doubled_anyway or n >= 2
	h.check("allowed, the common hard one sometimes sits at two desks", doubled)
	h.check("not allowed, never", not doubled_anyway)

func test_a_shift_can_scale_one_archetype_out_from_the_first_customer() -> void:
	var gone := _pool().archetypes[0].id
	var pool := _made_up(func(a): pass)
	var came := false
	for seed_value in range(30):
		var s := _opened_with(pool, seed_value, {"archetype_weight_scales": {gone: 0.0}})
		for c in s.seated():
			came = came or c.archetype.id == gone
		for _i in range(10):
			came = came or s._pick_archetype().id == gone
	h.check("scaled to nothing, they never come in - not even at opening", not came)

func test_who_demands_a_category_wants_it_most() -> void:
	## "Make her required category her favorites": every interest in the
	## category they came in for ranks in their top three.
	var demanding: StringName = &""
	for a in _pool().archetypes:
		if a.demands_category:
			demanding = a.id
	if demanding == &"":
		return    # nobody in the pool demands one today - nothing to check
	var interests: InterestPool = load("res://data/interests/interest_pool.tres")
	for seed_value in range(30):
		var s := Shift.new(load("res://data/shift_config.tres"), interests,
			load("res://data/card_pool.tres"), _pool(), seed_value, [demanding], null, 0, 99)
		for c in s.seated():
			if c.demands_category == null:
				continue
			for iid in c.ranks:
				var in_it: bool = interests.by_id(iid).category.id == c.demands_category
				h.check("seed %d: %s ranks %d - %s her category" % [seed_value, iid,
					c.ranks[iid], "in" if in_it else "outside"],
					(int(c.ranks[iid]) <= 3) == in_it)
