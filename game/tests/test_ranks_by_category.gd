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

func test_active_listening_reads_their_favourite_category_and_the_upgrade_its_order() -> void:
	var c := _seated(_made_up(true), 5)
	var favourite: Category = c.interests().by_id(c.top_interest_id()).category
	var theirs: Array = []
	for i in c.interests().in_category(favourite):
		theirs.append(i.id)
	c.reveal_room(false)
	h.check("the read gives the Line", c.known_line)
	h.eq("and names the category they want most", c.known_top_category, favourite.id)
	var marked: Array = Array(c.known_top_three)
	marked.sort()
	theirs.sort()
	h.eq("marking everything in it", marked, theirs)
	h.check("but not in what order",
		theirs.all(func(iid): return not c.known_ranks.has(iid)))
	c.reveal_room(true)
	h.check("the upgraded read gives each one's rank",
		theirs.all(func(iid): return int(c.known_ranks.get(iid, -1)) == int(c.ranks[iid])))

func test_for_everyone_else_active_listening_reads_one_interest() -> void:
	var c := _seated(_made_up(false), 5)
	var top := c.top_interest_id()
	c.reveal_room(false)
	h.eq("their top interest, with its rank", c.known_ranks.get(top, -1), int(c.ranks[top]))
	h.eq("and nothing else ranked", c.known_ranks.size(), 1)
