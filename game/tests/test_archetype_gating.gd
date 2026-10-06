extends RefCounted
## Who is allowed to walk in, and when: the hardest archetypes wait for a later
## week of the run (CustomerArchetype.from_week), and within its week anyone
## unlocked may come in on any day. Made-up archetypes only - which of the real
## ones wait, and for how long, is David's to tune.
var h: Harness

func _pool() -> ArchetypePool:
	return load("res://data/archetype_pool.tres")

## A made-up archetype, copied off a real one so it can sit down.
func _made(id: StringName, from_week: int) -> CustomerArchetype:
	var a := _pool().archetypes[0].duplicate() as CustomerArchetype
	a.id = id
	a.display_name = String(id)
	a.from_week = from_week
	a.weight = 1.0
	a.hard = false
	return a

func _pool_of(archetypes: Array) -> ArchetypePool:
	var typed: Array[CustomerArchetype] = []
	typed.assign(archetypes)
	var p := ArchetypePool.new()
	p.design_rule = "test double"
	p.names = _pool().names.duplicate()
	p.archetypes = typed
	return p

func _cfg() -> ShiftConfig:
	return load("res://data/shift_config.tres")

func _on(pool: ArchetypePool, day: int, seed_value: int) -> Shift:
	return Shift.new(_cfg(), load("res://data/interests/interest_pool.tres"),
		load("res://data/card_pool.tres"), pool, seed_value, [], null, 0, day)

func _ids(archetypes: Array) -> Array:
	return archetypes.map(func(a): return a.id)

func test_nobody_comes_in_before_their_week() -> void:
	var pool := _pool_of([_made(&"early", 1), _made(&"late", 2)])
	var week := _cfg().days_per_week
	h.eq("week 1 is only who has unlocked",
		_ids(Shift.eligible_archetypes(pool, 1)), [&"early"])
	h.eq("week 2 brings in the rest",
		_ids(Shift.eligible_archetypes(pool, 2)), [&"early", &"late"])
	var seen := {}
	for day in range(1, week + 1):
		for seed_value in range(6):
			for c in _on(pool, day, seed_value).seated():
				seen[c.archetype.id] = true
	h.eq("and no floor in week 1 seats the late one", seen.keys(), [&"early"])
	h.eq("the week a day falls in counts from 1",
		[Shift.week_of(1, week), Shift.week_of(week, week), Shift.week_of(week + 1, week)],
		[1, 1, 2])

func test_everyone_unlocked_can_come_in_on_any_day_of_the_week() -> void:
	## No more two new archetypes a day - the first day of a week is as open as
	## the last.
	var pool := _pool_of([_made(&"a", 1), _made(&"b", 1), _made(&"c", 1)])
	var seen := {}
	for seed_value in range(30):
		for c in _on(pool, 1, seed_value).seated():
			seen[c.archetype.id] = true
	h.check("all three turn up on day 1 (%s)" % str(seen.keys()),
		seen.size() == 3 and seen.has(&"a") and seen.has(&"b") and seen.has(&"c"))

func test_misauthored_weeks_give_way_rather_than_leave_nobody() -> void:
	## Every from_week past the end of the run would otherwise index an empty
	## array and take the game down on spawn.
	var pool := _pool_of([_made(&"late", 99)])
	var s := _on(pool, 1, 7)
	h.eq("the floor still filled", s.seated().size(), s.cfg.floor_size)
	h.eq("from the fallback pool", s.seated()[0].archetype.id, &"late")

func test_a_shift_that_names_its_customers_ignores_the_week() -> void:
	var late := _made(&"late", 2)
	var pool := _pool_of([_made(&"early", 1), late])
	h.eq("only = exactly them, whatever the week",
		_ids(Shift.eligible_archetypes(pool, 1, [late])), [&"late"])

func test_an_exclusion_takes_them_out_unless_that_leaves_nobody() -> void:
	var a := _made(&"a", 1)
	var b := _made(&"b", 1)
	var pool := _pool_of([a, b])
	h.eq("excluded are taken out", _ids(Shift.eligible_archetypes(pool, 1, [], [a])), [&"b"])
	h.eq("but never down to nobody",
		_ids(Shift.eligible_archetypes(pool, 1, [], [a, b])), [&"a", &"b"])

func test_never_two_of_the_same_hard_one_on_the_floor() -> void:
	var made: Array = []
	for i in range(_pool().archetypes.size()):
		var a := _made(StringName("hard_%d" % i), 1)
		a.hard = true
		made.append(a)
	var pool := _pool_of(made)
	var doubled: Array[int] = []
	for seed_value in range(40):
		var ids := {}
		for c in _on(pool, 1, seed_value).seated():
			if ids.has(c.archetype.id):
				doubled.append(seed_value)
			ids[c.archetype.id] = true
	h.check("no floor seats the same hard one twice (seeds that did: %s)"
		% str(doubled), doubled.is_empty())
