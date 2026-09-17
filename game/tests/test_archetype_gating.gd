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
