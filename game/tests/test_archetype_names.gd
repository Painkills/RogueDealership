extends RefCounted
## What customers are called, and the picture on their folder. Each archetype
## has names of its own - a pun on it, so a name says who sat down - and none is
## shared with another archetype. Rules against whatever ships, and against
## made-up archetypes for how a floor hands the names out: nothing here knows
## what anybody is called.
var h: Harness

func _everyone() -> Array[CustomerArchetype]:
	var out: Array[CustomerArchetype] = []
	for file in DirAccess.get_files_at("res://data/archetypes"):
		if file.ends_with(".tres"):
			out.append(load("res://data/archetypes/" + file))
	return out

func _made_up(id: StringName, names: Array) -> CustomerArchetype:
	var a := CustomerArchetype.new()
	a.id = id
	a.display_name = String(id)
	a.names.assign(names)
	return a

func _shift(seed_value: int = 5) -> Shift:
	var s := Shift.new(load("res://data/shift_config.tres"),
		load("res://data/interests/interest_pool.tres"), load("res://data/card_pool.tres"),
		load("res://data/archetype_pool.tres"), seed_value)
	for i in range(s.chairs.size()):
		s.chairs[i] = null
	return s

# ---------------------------------------------------------------- the data
func test_no_name_belongs_to_two_archetypes() -> void:
	var owner := {}
	var shared: Array[String] = []
	var offenders: Array[String] = []
	for a in _everyone():
		var mine := {}
		for n in a.names:
			if mine.has(n):
				offenders.append("%s lists %s twice" % [a.id, n])
			mine[n] = true
			if owner.has(n) and owner[n] != a.id:
				shared.append("%s (%s and %s)" % [n, owner[n], a.id])
			owner[n] = a.id
	h.check("no archetype repeats a name, and none shares one (%s)"
		% "; ".join(offenders + shared), offenders.is_empty() and shared.is_empty())
	var fallback: Array = (load("res://data/archetype_pool.tres") as ArchetypePool).names
	var crossing: Array[String] = []
	for n in fallback:
		if owner.has(n):
			crossing.append("%s is also %s's" % [n, owner[n]])
	h.check("and the pool they fall back on shares none with them either (%s)"
		% "; ".join(crossing), crossing.is_empty())

func test_every_picture_an_archetype_names_is_one_that_can_be_drawn() -> void:
	var missing: Array[String] = []
	for a in _everyone():
		if a.icon != &"" and not ArchetypeIcon.has(a.icon):
			missing.append("%s wants %s" % [a.id, a.icon])
	h.check("nobody asks for a picture nobody has drawn (%s)" % "; ".join(missing),
		missing.is_empty())
	for name in ArchetypeIcon.NAMES:
		h.check("%s is listed with its colours" % name, ArchetypeIcon.has(name))

# ------------------------------------------------------------- on the floor
func test_a_customer_takes_a_name_from_their_archetypes_list() -> void:
	var list := ["Aa One", "Bb Two", "Cc Three"]
	var s := _shift()
	s._spawn(0, _made_up(&"mine", list))
	h.check("it is one of theirs (%s)" % s.chairs[0].display_name,
		list.has(s.chairs[0].display_name))

func test_two_of_one_archetype_never_share_a_name_until_the_list_runs_out() -> void:
	var list := ["Aa One", "Bb Two", "Cc Three"]
	var arch := _made_up(&"mine", list)
	var s := _shift()
	var seen := {}
	for round_i in range(3):
		var chair := round_i % s.chairs.size()
		s.chairs[chair] = null
		s._spawn(chair, arch)
		seen[s.chairs[chair].display_name] = true
	h.eq("three customers, three different names", seen.size(), 3)
	s.chairs[0] = null
	s._spawn(0, arch)
	h.check("the fourth comes round to one of them again", list.has(s.chairs[0].display_name))

func test_one_archetypes_names_do_not_use_up_anothers() -> void:
	var a := _made_up(&"a", ["Aa One"])
	var b := _made_up(&"b", ["Bb Two"])
	var s := _shift()
	s._spawn(0, a)
	s._spawn(1, b)
	h.eq("each gets their own", [s.chairs[0].display_name, s.chairs[1].display_name],
		["Aa One", "Bb Two"])

func test_an_archetype_with_no_names_is_named_from_the_shared_pool() -> void:
	var s := _shift()
	s._spawn(0, _made_up(&"nameless", []))
	h.check("from the pool (%s)" % s.chairs[0].display_name,
		s.archetypes.names.has(s.chairs[0].display_name))

func test_what_somebody_is_called_moves_nothing_that_is_rolled() -> void:
	## Naming is voice, not the floor: the same seed deals the same customer
	## whatever list - or none - they are named from.
	var with_names := _shift(9)
	var without := _shift(9)
	with_names._spawn(0, _made_up(&"same", ["Aa One", "Bb Two"]))
	without._spawn(0, _made_up(&"same", []))
	var a: Customer = with_names.chairs[0]
	var b: Customer = without.chairs[0]
	h.eq("the same interests", a.ranks, b.ranks)
	h.eq("the same patience", [a.patience, a.max_patience], [b.patience, b.max_patience])
	h.eq("and the same Line", a.line, b.line)
