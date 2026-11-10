extends RefCounted
var h: Harness

const POOL := "res://data/card_pool.tres"

func _pool() -> CardPool:
	return load(POOL)

func test_a_card_instance_reports_its_margin() -> void:
	var vsc: ProductCardDef = _pool().by_id(&"vsc")
	var inst := CardInstance.new(vsc, 1)
	h.eq("list margin", inst.margin(), vsc.margin)
	h.check("and knows it is a product", inst.is_product())

func test_upgrading_one_copy_leaves_the_others_alone() -> void:
	## The Godot trap this exists to avoid: a deck of shared Resource refs would
	## upgrade all three copies of Explain at once.
	var vsc: ProductCardDef = _pool().by_id(&"vsc")
	var a := CardInstance.new(vsc, 1)
	var b := CardInstance.new(vsc, 2)
	a.upgraded = true
	h.check("the upgraded copy changed", a.margin() > b.margin())
	h.eq("the untouched copy did not", b.margin(), vsc.margin)
	h.check("and they are distinct instances", a.uid != b.uid)

func test_shoppable_cards_is_exactly_the_pool_minus_starters() -> void:
	var pool := _pool()
	var shoppable := pool.shoppable_cards()
	for c in shoppable:
		h.check("%s in shoppable_cards is not a starter" % c.id, not c.starter)
	var non_starter_count := 0
	for c in pool.cards:
		if not c.starter:
			non_starter_count += 1
	h.eq("every non-starter card is in it", shoppable.size(), non_starter_count)

func test_lookup_by_id_finds_every_card() -> void:
	for c in _pool().cards:
		h.eq("by_id round-trips %s" % c.id, _pool().by_id(c.id), c)
	h.eq("and returns null for a stranger", _pool().by_id(&"nonsense"), null)

func test_an_upgraded_copy_costs_its_upgraded_ticks_and_playing_it_burns_that() -> void:
	var def := SupportCardDef.new()
	def.display_name = "Made-up quick card"
	def.ticks = 2
	def.upgraded_ticks = 0
	def.needs_offer = false
	var plain := CardInstance.new(def, 901)
	var better := CardInstance.new(def, 902)
	better.upgraded = true
	h.eq("a plain copy costs the card's ticks", plain.ticks(), 2)
	h.eq("an upgraded one its upgraded ticks", better.ticks(), 0)
	var unchanged := SupportCardDef.new()
	unchanged.ticks = 1
	var up := CardInstance.new(unchanged, 903)
	up.upgraded = true
	h.eq("and a card with no upgraded cost keeps its own", up.ticks(), 1)

	var s := Shift.new(load("res://data/shift_config.tres"),
		load("res://data/interests/interest_pool.tres"), _pool(),
		load("res://data/archetype_pool.tres"), 4)
	s.hand[0] = better
	var tick_before := s.tick
	h.check("the upgraded copy plays", s.play_card(0).ok)
	h.eq("and costs no time", s.tick, tick_before)


func test_no_product_is_better_than_one_of_its_rarity_for_its_interest_on_both_ticks_and_margin() -> void:
	## The pool's design rule: in a menu run each interest is one slot, so a
	## product that is quicker AND pays more than another of its rarity for the
	## same interest leaves that one no reason to exist. A rarer product beating a
	## commoner one is what its price buys - that is not this.
	var products: Array = _pool().cards.filter(func(c): return c is ProductCardDef)
	h.check("the pool has products to compare", products.size() > 1)
	for a in products:
		for b in products:
			if a == b or a.interest.id != b.interest.id or a.rarity != b.rarity:
				continue
			h.check("%s is not better than %s on both axes" % [a.id, b.id],
				not (a.ticks <= b.ticks and a.margin >= b.margin
					and (a.ticks < b.ticks or a.margin > b.margin)))

func test_only_walkaway_products_lower_the_line() -> void:
	## Taking their Line down is the WALKAWAY family's own thing; no other
	## product does it, plain or upgraded.
	for c in _pool().cards:
		if not c is ProductCardDef or c.brand == &"walkaway":
			continue
		for e in c.effects + c.upgraded_effects:
			var lowers: bool = (e is ChangeLine or e is ChangeLineFloorWide) and e.amount < 0
			h.check("%s does not lower the Line" % c.id, not lowers)