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
