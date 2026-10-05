extends RefCounted
## Dealership upgrades: that each bonus reaches the floor, and that a store
## offering them hands out one the run does not own yet. Made-up upgrades only -
## the shipped ones are data to retune freely.
var h: Harness

func _cfg() -> ShiftConfig:
	return load("res://data/shift_config.tres")

func _shift(owned: Array) -> Shift:
	return Shift.new(_cfg(), load("res://data/interests/interest_pool.tres"),
		load("res://data/card_pool.tres"), load("res://data/archetype_pool.tres"),
		11, [], null, 0, 1, 0, 0, null, 0, 1.0, 1.0, false, [], [], [], {}, owned)

func _run(pool: DealershipUpgradePool) -> RunState:
	return RunState.new(_cfg(), load("res://data/interests/interest_pool.tres"),
		load("res://data/card_pool.tres"), load("res://data/archetype_pool.tres"), 5,
		null, null, pool)

func test_every_bonus_reaches_the_floor() -> void:
	var u := DealershipUpgrade.new()
	u.hand_size = 1
	u.patience = 3
	u.line = -4
	u.appeal_per_card = 2
	u.margin = 0.5
	u.combo_step = 0.1
	var early: CustomerArchetype = (load("res://data/archetype_pool.tres") as ArchetypePool).archetypes[0]
	u.waiting_at_open.append(early)
	u.line_drop_brand = &"made_up_brand"
	u.line_drop_extra = 1.0
	var plain := _shift([])
	var upgraded := _shift([u])
	h.eq("one more card in hand", upgraded.hand.size(), plain.hand.size() + 1)
	h.check("someone already waiting at opening",
		upgraded.waiting.size() == plain.waiting.size() + 1 and upgraded.waiting.has(early))
	h.eq("an extra customer leaves the door's clock alone",
		upgraded.next_arrival, plain.next_arrival)
	var early_door := DealershipUpgrade.new()
	early_door.waiting_at_open.append(early)
	early_door.counts_against_door = true
	h.check("one brought forward puts the door's next arrival back a gap",
		_shift([early_door]).next_arrival > plain.next_arrival)
	var a: Customer = plain.chairs[0]
	var b: Customer = upgraded.chairs[0]
	h.check("the same customer either way", a.archetype == b.archetype)
	h.eq("more patience to work with", b.max_patience, a.max_patience + 3)
	h.eq("and more of it to start from", b.patience, a.patience + 3)
	h.eq("a lower Line", b.line, maxi(0, a.line - 4))
	h.check("a bigger combo step", is_equal_approx(b.combo_step, a.combo_step + 0.1))

	# Margin and appeal, on the same product put in front of each.
	for s in [plain, upgraded]:
		var c: Customer = s.chairs[0]
		var inst := CardInstance.new(s.card_pool.cards.filter(
			func(d): return d is ProductCardDef)[0], 999)
		s.hand[0] = inst
		s.place(0)
		var bump := ChangeAppeal.new()
		bump.amount = 3
		var before: int = c.offer.appeal
		bump.apply(s._yours(c))
		s.set_meta(&"added", c.offer.appeal - before)
		var lower := ChangeAppeal.new()
		lower.amount = -3
		before = c.offer.appeal
		lower.apply(s._yours(c))
		s.set_meta(&"taken", before - c.offer.appeal)
		before = c.offer.appeal
		bump.apply(s._context(c))
		s.set_meta(&"theirs", c.offer.appeal - before)
		s.set_meta(&"margin", c.offer.margin)
		# A Line drop from a card of the brand, and from one of no brand.
		var drop := ChangeLine.new()
		drop.amount = -2
		var branded := SupportCardDef.new()
		branded.brand = &"made_up_brand"
		var line_before: int = c.line
		drop.apply(s._yours(c, branded))
		s.set_meta(&"brand_drop", line_before - c.line)
		line_before = c.line
		drop.apply(s._yours(c, SupportCardDef.new()))
		s.set_meta(&"other_drop", line_before - c.line)
	h.eq("the product earns its margin share more",
		upgraded.get_meta(&"margin"), roundi(plain.get_meta(&"margin") * 1.5))
	h.eq("your appeal adds the bonus", upgraded.get_meta(&"added"), plain.get_meta(&"added") + 2)
	h.eq("appeal taken away gets no bonus", upgraded.get_meta(&"taken"), plain.get_meta(&"taken"))
	h.eq("and a customer's own appeal effects get none", upgraded.get_meta(&"theirs"),
		plain.get_meta(&"theirs"))
	h.eq("the brand's Line drop doubles", upgraded.get_meta(&"brand_drop"),
		plain.get_meta(&"brand_drop") * 2)
	h.eq("another card's does not", upgraded.get_meta(&"other_drop"),
		plain.get_meta(&"other_drop"))

func test_a_store_offers_upgrades_the_run_does_not_own_and_keeps_the_one_taken() -> void:
	var pool := DealershipUpgradePool.new()
	for i in range(4):
		var u := DealershipUpgrade.new()
		u.id = StringName("made_up_%d" % i)
		u.hand_size = 1
		pool.upgrades.append(u)
	var offering := ShiftProfile.new()
	offering.dealership_upgrades = 3
	var run := _run(pool)
	var shop := Shop.new(run, offering)
	h.eq("as many as the shift offers", shop.dealership_offers.size(), 3)
	var taken: DealershipUpgrade = shop.dealership_offers[1]
	h.check("taking one works", shop.take_dealership_upgrade(taken).ok)
	h.check("and the run keeps it", run.dealership.has(taken))
	h.check("only one per visit", not shop.take_dealership_upgrade(shop.dealership_offers[0]).ok)
	for _visit in range(5):
		h.check("never offered again once owned",
			not Shop.new(run, offering).dealership_offers.has(taken))
	h.eq("every shift after it is worked with it",
		run.start_shift(ShiftProfile.new()).hand.size(), run.cfg.hand_size + 1)

	# Only a shift that made its quota earns one.
	var missed := _run(pool)
	missed.reports.append({"made_quota": false})
	var no_pick := Shop.new(missed, offering)
	h.check("a shift that missed quota offers no upgrade, and says so",
		no_pick.dealership_offers.is_empty() and no_pick.dealership_missed)
	var made := _run(pool)
	made.reports.append({"made_quota": true})
	h.eq("one that made it does", Shop.new(made, offering).dealership_offers.size(), 3)

	# A store that offers none rolls nothing for them: the run's dice end up
	# where a run with no upgrades at all would leave them.
	var plain := _run(null)
	var with_pool := _run(pool)
	Shop.new(plain, ShiftProfile.new())
	Shop.new(with_pool, ShiftProfile.new())
	h.eq("no upgrades on offer moves no dice", with_pool.rng.state, plain.rng.state)
	h.check("and offers nothing", Shop.new(_run(pool), ShiftProfile.new()).dealership_offers.is_empty())
