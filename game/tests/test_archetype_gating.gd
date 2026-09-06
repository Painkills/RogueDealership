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

func test_the_ladder_is_authored_as_designed() -> void:
	var want := {
		&"laydown": 1, &"easygoing": 1,
		&"family": 2, &"tech": 2,
		&"hawk": 3, &"kicker": 3,
		&"karen": 4,
	}
	h.eq("every archetype is on the ladder", _pool().archetypes.size(), want.size())
	for a in _pool().archetypes:
		h.check("%s is on the ladder" % a.id, want.has(a.id))
		if want.has(a.id):
			h.eq("%s opens on shift %d" % [a.id, want[a.id]], a.min_shift, want[a.id])

func test_shift_one_is_only_the_two_gentle_archetypes() -> void:
	for seed_value in range(40):
		for c in _shift(1, seed_value).seated():
			h.check("shift 1 seats only laydown or easygoing, got %s" % c.archetype.id,
				c.archetype.id == &"laydown" or c.archetype.id == &"easygoing")

func test_the_hard_two_cannot_open_a_run() -> void:
	for seed_value in range(40):
		for n in [1, 2]:
			for c in _shift(n, seed_value).seated():
				h.check("shift %d has no kicker or karen, got %s" % [n, c.archetype.id],
					c.archetype.id != &"kicker" and c.archetype.id != &"karen")

func test_the_kicker_arrives_on_three_and_the_karen_on_four() -> void:
	var seen_kicker := false
	var seen_karen := false
	for seed_value in range(60):
		for c in _shift(3, seed_value).seated():
			if c.archetype.id == &"kicker":
				seen_kicker = true
			h.check("shift 3 still has no karen", c.archetype.id != &"karen")
		for c in _shift(4, seed_value).seated():
			if c.archetype.id == &"karen":
				seen_karen = true
	h.check("the kicker does turn up by shift 3", seen_kicker)
	h.check("and the karen by shift 4", seen_karen)

func test_a_floor_still_fills_when_the_gate_leaves_too_few() -> void:
	## floor_size is 3 but shift 1 offers only 2 archetypes. The unique-archetype
	## filter is already guarded by "if not fresh.is_empty()", so the third chair
	## simply repeats one - and on shift 1 a doubled Lay-Down is a gift.
	var s := _shift(1, 11)
	h.eq("all three chairs filled", s.seated().size(), 3)

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
	h.eq("the floor still filled", s.seated().size(), 3)
	h.eq("from the fallback pool", s.seated()[0].archetype.id, &"late")
