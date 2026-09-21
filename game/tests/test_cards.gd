extends RefCounted
var h: Harness

const POOL := "res://data/card_pool.tres"

func _pool() -> CardPool:
	return load(POOL)

func _products() -> Array:
	var out := []
	for c in _pool().cards:
		if c is ProductCardDef:
			out.append(c)
	return out

func test_every_interest_has_exactly_one_product() -> void:
	var interests: InterestPool = load("res://data/interests/interest_pool.tres")
	var seen := {}
	for p in _products():
		h.check("%s answers an interest" % p.id, p.interest != null)
		h.check("no interest answered twice", not seen.has(p.interest.id))
		seen[p.interest.id] = true
	h.eq("nine products for nine interests", seen.size(), interests.count())

func test_every_category_has_at_least_one_starter_product() -> void:
	## Not "exactly two per category" - that's a balance choice about how many
	## starter products exist, not an invariant. What has to hold is that no
	## category is left with zero starter products to sell from day one.
	var per := {}
	for p in _products():
		if p.starter:
			per[p.interest.category.id] = per.get(p.interest.category.id, 0) + 1
	var interests: InterestPool = load("res://data/interests/interest_pool.tres")
	for cat in interests.categories:
		h.check("%s has at least one starter product" % cat.id,
			int(per.get(cat.id, 0)) >= 1)

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

func test_the_card_pool_states_its_design_rule() -> void:
	h.check("card pool states its design rule",
		_pool().design_rule.strip_edges() != "")

func test_lookup_by_id_finds_every_card() -> void:
	for c in _pool().cards:
		h.eq("by_id round-trips %s" % c.id, _pool().by_id(c.id), c)
	h.eq("and returns null for a stranger", _pool().by_id(&"nonsense"), null)
