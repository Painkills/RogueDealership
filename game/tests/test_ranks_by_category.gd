extends RefCounted
## CustomerArchetype.ranks_by_category: an archetype whose customers rank their
## interests a category at a time, in an order nobody's archetype decides, and
## Active Listening reading a category for them. Everyone else ranks interest by
## interest. Made-up archetypes, so none of it rides on who ships with the flag.
var h: Harness

func _pool() -> InterestPool:
	return load("res://data/interests/interest_pool.tres")

func _block_of(ranks: Dictionary, pool: InterestPool, cat: Category) -> Array:
	var out := []
	for i in pool.in_category(cat):
		out.append(int(ranks[i.id]))
	out.sort()
	return out

## Whether every category's interests hold one unbroken run of ranks.
func _in_blocks(ranks: Dictionary, pool: InterestPool) -> bool:
	for cat in pool.categories:
		var block := _block_of(ranks, pool, cat)
		if block[-1] - block[0] != block.size() - 1:
			return false
	return true

func _made_up(by_category: bool) -> CustomerArchetype:
	var a := CustomerArchetype.new()
	a.id = &"made_up_by_category" if by_category else &"made_up_one_by_one"
	a.display_name = "Made-up buyer"
	a.ranks_by_category = by_category
	return a

## A customer of `arch`, sat down in chair A of a fresh shift.
func _seated(arch: CustomerArchetype, seed_value: int) -> Customer:
	var s := Shift.new(load("res://data/shift_config.tres"), _pool(),
		load("res://data/card_pool.tres"), load("res://data/archetype_pool.tres"), seed_value)
	s.chairs[0] = null
	s._spawn(0, arch)
	return s.chairs[0]

func test_ranks_come_a_category_at_a_time_in_a_random_order() -> void:
	var pool := _pool()
	var broken := 0
	var firsts := {}
	for seed_value in range(40):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var ranks := Customer.make_ranks(pool, rng, [], true)
		if not _in_blocks(ranks, pool):
			broken += 1
		for cat in pool.categories:
			if _block_of(ranks, pool, cat)[0] == 1:
				firsts[cat.id] = true
	h.eq("every category's interests hold one unbroken run of ranks", broken, 0)
	h.eq("and every category is somebody's favourite (%s)" % str(firsts.keys()),
		firsts.size(), pool.categories.size())

func test_only_an_archetype_that_ranks_by_category_does() -> void:
	var pool := _pool()
	var grouped := 0
	var loose := 0
	for seed_value in range(20):
		if _in_blocks(_seated(_made_up(true), seed_value).ranks, pool):
			grouped += 1
		if _in_blocks(_seated(_made_up(false), seed_value).ranks, pool):
			loose += 1
	h.eq("theirs come in category blocks, every time", grouped, 20)
	h.check("everyone else's are dealt one by one (%d of 20 happened to block up)" % loose,
		loose < 20)

func test_a_category_they_came_in_for_ranks_first() -> void:
	var pool := _pool()
	var missed := 0
	for by_category in [true, false]:
		for cat in pool.categories:
			var rng := RandomNumberGenerator.new()
			rng.seed = 3
			var ranks := Customer.make_ranks(pool, rng, pool.in_category(cat), by_category)
			var block := _block_of(ranks, pool, cat)
			if block[-1] != block.size():
				missed += 1
	h.eq("its interests take the top ranks, dealt either way", missed, 0)

func test_active_listening_reads_the_top_three_in_order_for_them_too() -> void:
	## Someone who ranks by category is read the way everyone is: their Line and
	## the three they want most, in order - no category named, no row lit.
	var c := _seated(_made_up(true), 5)
	c.reveal_room(true)
	h.check("the Line", c.known_line)
	var three := c.top_unsold_interest_ids(3)
	h.eq("their three", c.known_top_three, three)
	for k in range(3):
		h.eq("number %d, with its rank" % (k + 1), int(c.known_ranks.get(three[k], -1)), k + 1)
	h.check("and the read names no category",
		c.known_top_category == null)

func test_a_plain_read_gives_just_the_one_they_want_most() -> void:
	var c := _seated(_made_up(false), 5)
	var top := c.top_interest_id()
	c.reveal_room(false)
	h.eq("their top interest, with its rank", c.known_ranks.get(top, -1), int(c.ranks[top]))
	h.eq("and nothing else ranked", c.known_ranks.size(), 1)
