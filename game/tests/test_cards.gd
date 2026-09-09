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

func test_the_starter_six_are_two_per_category() -> void:
	var per := {}
	for p in _products():
		if p.starter:
			per[p.interest.category.id] = per.get(p.interest.category.id, 0) + 1
	h.eq("three categories represented", per.size(), 3)
	for cat in per:
		h.eq("two starter products in %s" % cat, per[cat], 2)

func test_a_card_instance_reports_its_margin() -> void:
	var vsc: ProductCardDef = _pool().by_id(&"vsc")
	var inst := CardInstance.new(vsc, 1)
	h.eq("list margin", inst.margin(), 1600)
	h.check("and knows it is a product", inst.is_product())

func test_upgrading_one_copy_leaves_the_others_alone() -> void:
	## The Godot trap this exists to avoid: a deck of shared Resource refs would
	## upgrade all three copies of Explain at once.
	var vsc: ProductCardDef = _pool().by_id(&"vsc")
	var a := CardInstance.new(vsc, 1)
	var b := CardInstance.new(vsc, 2)
	a.upgraded = true
	h.check("the upgraded copy changed", a.margin() > b.margin())
	h.eq("the untouched copy did not", b.margin(), 1600)
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

func test_every_product_upgrades_by_exactly_a_quarter() -> void:
	## The flat +$300 this replaces was regressive - 50% on the $600 concierge
	## plan and 18.75% on the $1,600 service contract - so "upgraded" meant
	## something different on every card. Nothing pinned the convention, which is
	## how it drifted. Every base margin is a multiple of $100, so x1.25 is
	## always a whole number and no rounding rule is needed.
	for p in _products():
		h.eq("%s upgrades by a quarter" % p.id, p.upgraded_margin, p.margin * 5 / 4)
