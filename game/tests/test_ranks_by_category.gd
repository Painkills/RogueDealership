extends RefCounted
## ShiftConfig.ranks_by_category: ranks dealt a category at a time, archetypes
## leaning by category, and Active Listening reading a category. Made-up
## archetypes and an explicit config, so none of it rides on the shipped data.
var h: Harness

func _pool() -> InterestPool:
	return load("res://data/interests/interest_pool.tres")

func _cfg() -> ShiftConfig:
	var cfg: ShiftConfig = (load("res://data/shift_config.tres") as ShiftConfig).duplicate()
	cfg.ranks_by_category = true
	cfg.prior_slip = 0.0
	return cfg

func _block_of(ranks: Dictionary, pool: InterestPool, cat: Category) -> Array:
	var out := []
	for i in pool.in_category(cat):
		out.append(int(ranks[i.id]))
	out.sort()
	return out

func test_ranks_come_a_category_at_a_time() -> void:
	var pool := _pool()
	var arch := CustomerArchetype.new()
	var broken := 0
	for seed_value in range(40):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var ranks := Customer.make_ranks(arch, pool, rng, 0.0, [], true)
		for cat in pool.categories:
			var block := _block_of(ranks, pool, cat)
			if block[-1] - block[0] != block.size() - 1:
				broken += 1
	h.eq("every category's interests hold one unbroken run of ranks", broken, 0)

func test_an_archetype_leaning_on_a_category_ranks_it_first_and_its_dislike_last() -> void:
	var pool := _pool()
	var arch := CustomerArchetype.new()
	var liked: Category = pool.categories[1]
	var disliked: Category = pool.categories[0]
	arch.top_categories = [liked]
	arch.bottom_categories = [disliked]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var ranks := Customer.make_ranks(arch, pool, rng, 0.0, [], true)
	var top := _block_of(ranks, pool, liked)
	var bottom := _block_of(ranks, pool, disliked)
	h.eq("the category they lean to takes the first ranks", top[0], 1)
	h.eq("and the one they dislike the last", bottom[-1], pool.count())

func test_each_category_an_archetype_leans_to_does_come_first() -> void:
	var pool := _pool()
	var arch := CustomerArchetype.new()
	arch.top_categories = [pool.categories[0], pool.categories[2]]
	var firsts := {}
	for seed_value in range(60):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var ranks := Customer.make_ranks(arch, pool, rng, 0.0, [], true)
		for cat in pool.categories:
			if _block_of(ranks, pool, cat)[0] == 1:
				firsts[cat.id] = true
	h.check("both of them come first sometimes, and nothing else does (%s)" % str(firsts.keys()),
		firsts.has(pool.categories[0].id) and firsts.has(pool.categories[2].id)
			and not firsts.has(pool.categories[1].id))

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
