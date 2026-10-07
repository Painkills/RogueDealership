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
	var ranks := Customer.make_ranks(_interests(), rng)
	return Customer.new("A", "Test Person", a, ranks, a.patience, a.patience,
		CFG, _interests())

func test_patience_never_exceeds_its_ceiling() -> void:
	var c := _cust(&"easygoing", 1)
	c.patience = c.max_patience - 1
	c.add_patience(5)
	h.eq("capped at max", c.patience, c.max_patience)
	c.add_patience(-3)
	h.eq("but falls freely", c.patience, c.max_patience - 3)

func test_reveal_room_gives_the_line_and_their_number_one() -> void:
	var c := _cust(&"easygoing", 1)
	h.check("starts hidden", not c.known_line)
	c.reveal_room()
	h.check("now known", c.known_line)
	var top := c.top_interest_id()
	h.eq("and their number one, with its rank", c.known_ranks.get(top, -1), int(c.ranks[top]))
	h.eq("and only that", c.known_ranks.size(), 1)
	h.check("no row of their grid is lit - that is for someone who came in for one",
		c.known_top_category == null)

func test_an_exact_read_gives_the_line_and_their_top_three_in_order() -> void:
	var c := _cust(&"easygoing", 1)
	c.reveal_room(true)
	h.check("the Line", c.known_line)
	var three := c.top_unsold_interest_ids(3)
	h.eq("three of them", c.known_top_three, three)
	for k in range(3):
		h.eq("number %d, with its rank" % (k + 1), int(c.known_ranks.get(three[k], -1)), k + 1)
	h.check("and still nothing lit but the ranks", c.known_top_category == null)
	# What is already sold is not what they want next.
	c.unsigned.append({"product": _a_product_for(c, three[0]), "margin": 100})
	c.known_ranks.clear()
	c.reveal_room(true)
	var next := c.top_unsold_interest_ids(3)
	h.check("a read after a sale starts from what is left (%s)" % str(next),
		not next.has(three[0]) and c.known_top_three == next)

## Any product answering `iid`, for a test that needs one sold.
func _a_product_for(_c, iid: StringName) -> ProductCardDef:
	for def in (load("res://data/card_pool.tres") as CardPool).cards:
		if def is ProductCardDef and def.interest.id == iid:
			return def
	for def in (load("res://data/card_pool.tres") as CardPool).cards:
		if def is ProductCardDef:
			var fake := def.duplicate() as ProductCardDef
			fake.interest = _interests().by_id(iid)
			return fake
	return null
