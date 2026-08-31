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
	var hits := 0
	var trials := 200
	for s in range(trials):
		var rng := RandomNumberGenerator.new()
		rng.seed = s
		var ranks := Customer.make_ranks(_arch(&"tech"), _interests(), rng, 0.2)
		if int(ranks[&"security"]) <= 3:
			hits += 1
	var rate := float(hits) / trials
	h.check("a tech enthusiast ranks Security top-3 far above chance (%.2f)"
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

func test_family_first_never_gets_harder() -> void:
	h.eq("their Line does not move on a sale", _arch(&"family").line_per_sale, 0)

func test_the_quiet_archetypes_have_no_actions() -> void:
	h.eq("easygoing does nothing", _arch(&"easygoing").actions.size(), 0)
	h.eq("lay-down does nothing", _arch(&"laydown").actions.size(), 0)

func test_the_budget_hawk_is_the_hardest_and_lay_down_the_easiest() -> void:
	h.eq("the Hawk wants 40", _arch(&"hawk").line, 40)
	h.eq("Lay-Down wants 20", _arch(&"laydown").line, 20)
	h.eq("the Tire Kicker has the least patience", _arch(&"kicker").patience, 9)

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

func test_at_least_two_archetypes_do_you_a_favour() -> void:
	## Or the system reads as punishment instead of personality. A favour can
	## be an action (Tech pays a premium) or a property (Family First never
	## gets harder, Lay-Down starts low).
	var pool: ArchetypePool = load("res://data/archetype_pool.tres")
	var favours: Array[String] = []
	for a in pool.archetypes:
		if a.line < 35:
			favours.append("%s:low bar" % a.id)
		if a.line_per_sale < 3:
			favours.append("%s:gentle ramp" % a.id)
		for act in a.actions:
			for e in act.effects:
				if e is MarginBonus \
						or (e is ChangeLine and e.amount < 0) \
						or (e is ChangePatience and e.amount > 0):
					favours.append("%s:%s" % [a.id, act.id])
	h.check("at least two archetypes do you a favour (%s)" % str(favours),
		favours.size() >= 2)

func test_the_pool_states_its_design_rule_and_has_names() -> void:
	var pool: ArchetypePool = load("res://data/archetype_pool.tres")
	h.check("archetype pool states its design rule",
		pool.design_rule.strip_edges() != "")
	h.check("and has customer names to draw from", pool.names.size() >= 10)
	h.eq("seven archetypes", pool.archetypes.size(), 7)
