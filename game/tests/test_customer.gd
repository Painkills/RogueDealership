extends RefCounted
var h: Harness

const CFG := {"appeal_step": 5, "line_per_sale": 3, "leaving_soon_at": 4}

func _interests() -> InterestPool:
	return load("res://data/interests/interest_pool.tres")

func _arch(id: StringName) -> CustomerArchetype:
	return (load("res://data/archetype_pool.tres") as ArchetypePool).by_id(id)

func _cust(id: StringName, seed_value: int) -> Customer:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var a := _arch(id)
	var ranks := Customer.make_ranks(a, _interests(), rng, 0.0)
	return Customer.new("A", "Test Person", a, ranks, a.patience, a.patience,
		CFG, _interests())

func test_patience_never_exceeds_its_ceiling() -> void:
	var c := _cust(&"easygoing", 1)
	c.patience = c.max_patience - 1
	c.add_patience(5)
	h.eq("capped at max", c.patience, c.max_patience)
	c.add_patience(-3)
	h.eq("but falls freely", c.patience, c.max_patience - 3)

func test_reveal_room_gives_the_line_and_a_category() -> void:
	var c := _cust(&"easygoing", 1)
	h.check("starts hidden", not c.known_line)
	c.reveal_room()
	h.check("now known", c.known_line)
	h.eq("and the category of their number one", c.known_top_category,
		_interests().by_id(c.top_interest_id()).category.id)
