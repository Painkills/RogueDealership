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

func test_never_two_of_the_same_hard_one_on_the_floor() -> void:
	var pool := _made_up(func(a): a.hard = true)
	var doubled: Array[int] = []
	for seed_value in range(40):
		var ids := {}
		for c in _on(pool, seed_value).seated():
			if ids.has(c.archetype.id):
				doubled.append(seed_value)
			ids[c.archetype.id] = true
	h.check("no floor seats the same hard one twice (seeds that did: %s)"
		% str(doubled), doubled.is_empty())
