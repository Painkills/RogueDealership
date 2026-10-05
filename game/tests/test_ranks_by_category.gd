extends RefCounted
## ShiftConfig.ranks_by_category: ranks dealt a category at a time, in an order
## nobody's archetype decides, and Active Listening reading a category. An
## explicit config, so none of it rides on the shipped data.
var h: Harness

func _pool() -> InterestPool:
	return load("res://data/interests/interest_pool.tres")

func _cfg() -> ShiftConfig:
	var cfg: ShiftConfig = (load("res://data/shift_config.tres") as ShiftConfig).duplicate()
	cfg.ranks_by_category = true
	return cfg

func _block_of(ranks: Dictionary, pool: InterestPool, cat: Category) -> Array:
	var out := []
	for i in pool.in_category(cat):
		out.append(int(ranks[i.id]))
	out.sort()
	return out

func test_ranks_come_a_category_at_a_time_in_a_random_order() -> void:
	var pool := _pool()
	var broken := 0
	var firsts := {}
	for seed_value in range(40):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var ranks := Customer.make_ranks(pool, rng, [], true)
		for cat in pool.categories:
			var block := _block_of(ranks, pool, cat)
			if block[-1] - block[0] != block.size() - 1:
				broken += 1
			if block[0] == 1:
				firsts[cat.id] = true
	h.eq("every category's interests hold one unbroken run of ranks", broken, 0)
	h.eq("and every category is somebody's favourite (%s)" % str(firsts.keys()),
		firsts.size(), pool.categories.size())

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
	var s := Shift.new(_cfg(), _pool(), load("res://data/card_pool.tres"),
		load("res://data/archetype_pool.tres"), 5)
	var c: Customer = s.chairs[0]
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
