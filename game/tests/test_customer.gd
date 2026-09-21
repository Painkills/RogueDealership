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

func test_appeal_is_the_step_times_places_from_the_bottom() -> void:
	var c := _cust(&"easygoing", 1)
	for iid in c.ranks:
		var expected: int = 5 * (9 - int(c.ranks[iid]))
		h.eq("rank %d opens at %d" % [c.ranks[iid], expected],
			c.appeal_for(iid), expected)

func test_their_number_one_opens_at_forty_and_their_last_at_zero() -> void:
	var c := _cust(&"easygoing", 1)
	var best := ""
	var worst := ""
	for iid in c.ranks:
		if int(c.ranks[iid]) == 1: best = iid
		if int(c.ranks[iid]) == 9: worst = iid
	h.eq("number one opens at 40", c.appeal_for(best), 40)
	h.eq("last place opens at 0", c.appeal_for(worst), 0)

func test_ranks_are_always_a_permutation_of_one_to_nine() -> void:
	for id in [&"easygoing", &"laydown", &"hawk", &"kicker", &"tech",
			&"family", &"karen"]:
		var ok := true
		for s in range(20):
			var got := _cust(id, s).ranks.values()
			got.sort()
			if got != [1, 2, 3, 4, 5, 6, 7, 8, 9]:
				ok = false
		h.check("%s always ranks 1-9 exactly once" % id, ok)

func test_priors_are_reliable_but_not_certain() -> void:
	## Reads tech's own top interest from the pool rather than naming
	## "security" - which interest that is is a balance choice, not a fact
	## this test should pin.
	var tech := _arch(&"tech")
	var favored: StringName = tech.top_interests[0].id
	var hits := 0
	var trials := 200
	for s in range(trials):
		var rng := RandomNumberGenerator.new()
		rng.seed = s
		var ranks := Customer.make_ranks(tech, _interests(), rng, 0.2)
		if int(ranks[favored]) <= 3:
			hits += 1
	var rate := float(hits) / trials
	h.check("a tech enthusiast ranks their own favored interest top-3 far above chance (%.2f)"
		% rate, rate >= 0.55 and rate <= 0.99)

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

## The bug this guards: reading the room after you have already sold their
## number one used to keep pointing at that same, already-closed interest -
## a read that told you nothing new. It should point at whatever is now
## their highest-priority interest that is still open.
func test_reveal_room_skips_what_is_already_sold() -> void:
	var c := _cust(&"easygoing", 1)
	var first := c.top_interest_id()
	var product := ProductCardDef.new()
	product.interest = _interests().by_id(first)
	product.margin = 100
	c.unsigned.append({"product": product, "margin": 100, "bonus": 0})

	c.reveal_room(true)
	var second := c.top_unsold_interest_id()
	h.check("the already-sold interest is not what gets named", second != first)
	h.eq("it names whatever ranks next instead", c.known_top_category,
		_interests().by_id(second).category.id)
	h.eq("and records ITS real rank, not 1", c.known_ranks[second],
		c.ranks[second])
	h.check("the rank recorded is not the hardcoded 1 the sold interest had",
		int(c.ranks[second]) != 1)

func test_the_budget_hawk_is_the_hardest_and_lay_down_the_easiest() -> void:
	## Relational, not pinned to today's exact numbers: whatever the pool's
	## current tuning is, the Hawk should be the hardest sign and Lay-Down the
	## easiest - that ordering is the actual design intent, not the literal
	## line values.
	var pool: ArchetypePool = load("res://data/archetype_pool.tres")
	var hawk := pool.by_id(&"hawk")
	var laydown := pool.by_id(&"laydown")
	var max_line := -1
	var min_line := 999999
	for a in pool.archetypes:
		max_line = maxi(max_line, a.line)
		min_line = mini(min_line, a.line)
	h.eq("the Hawk wants the highest Line in the pool (%d)" % hawk.line,
		hawk.line, max_line)
	h.eq("Lay-Down wants the lowest Line in the pool (%d)" % laydown.line,
		laydown.line, min_line)

	var kicker := pool.by_id(&"kicker")
	var min_patience := 999999
	for a in pool.archetypes:
		min_patience = mini(min_patience, a.patience)
	h.eq("the Tire Kicker has the least patience in the pool (%d)" % kicker.patience,
		kicker.patience, min_patience)

func test_every_archetype_states_the_pattern_it_teaches() -> void:
	for a in (load("res://data/archetype_pool.tres") as ArchetypePool).archetypes:
		h.check("%s states its pattern" % a.id, a.pattern.strip_edges() != "")
		h.check("%s has a tell" % a.id, a.tell.strip_edges() != "")
		for act in a.actions:
			h.check("%s/%s is telegraphed" % [a.id, act.id],
				act.tell.strip_edges() != "")
			h.check("%s/%s has a trigger" % [a.id, act.id], act.trigger != null)
			h.check("%s/%s has effects" % [a.id, act.id],
				act.effects.size() > 0)

func test_the_pool_states_its_design_rule_and_has_names() -> void:
	var pool: ArchetypePool = load("res://data/archetype_pool.tres")
	h.check("archetype pool states its design rule",
		pool.design_rule.strip_edges() != "")
	h.check("and has customer names to draw from", pool.names.size() >= 10)
	h.check("and has at least one archetype", pool.archetypes.size() >= 1)
