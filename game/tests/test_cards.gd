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
