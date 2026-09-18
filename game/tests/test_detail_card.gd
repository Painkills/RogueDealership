extends RefCounted
## DetailCard3D's non-visual behaviour: the appeal meter's fixed scale, and the
## category badge wired onto its sub line. What it draws is out of headless
## reach - see test_card_face.gd's own header - but everything here is plain
## data on the node, readable without ever calling _draw().
var h: Harness

const SCENE := "res://scenes/cards/detail_card_3d.tscn"
const CFG := {"appeal_step": 5, "line_per_sale": 3, "leaving_soon_at": 4}

func _instance() -> DetailCard3D:
	return (load(SCENE) as PackedScene).instantiate() as DetailCard3D

func _meter_scale() -> int:
	return (load("res://data/shift_config.tres") as ShiftConfig).appeal_meter_scale

func _interests() -> InterestPool:
	return load("res://data/interests/interest_pool.tres")

func _pool() -> CardPool:
	return load("res://data/card_pool.tres")

func _cust(id: StringName, seed_value: int) -> Customer:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var a := (load("res://data/archetype_pool.tres") as ArchetypePool).by_id(id)
	var ranks := Customer.make_ranks(a, _interests(), rng, 0.0)
	return Customer.new("A", "Test Person", a, ranks, a.patience, a.patience,
		CFG, _interests())

func _offer(product_id: StringName, appeal: int, margin: int, uid: int = 1) -> Offer:
	return Offer.new(CardInstance.new(_pool().by_id(product_id), uid), appeal, margin)

# --------------------------------------------------------------- the badge
func test_the_offer_sub_line_carries_the_products_own_category_badge() -> void:
	var d := _instance()
	var c := _cust(&"easygoing", 1)
	c.line = 40
	c.offer = _offer(&"vsc", 30, 1600)     # reliability -> vehicle
	d.show_offer(c, "COOL", _meter_scale())
	h.check("the badge is showing", d._sub_icon.visible)
	var vsc := _pool().by_id(&"vsc") as ProductCardDef
	h.eq("naming the product's own category", d._sub_icon._category_id,
		vsc.interest.category.id)
	d.free()

func test_an_archetype_name_carries_no_badge() -> void:
	## SubLabel is shared with show_customer(), where it names the ARCHETYPE,
	## not a category - a badge next to "Budget Hawk" would be a lie.
	var d := _instance()
	var c := _cust(&"easygoing", 1)
	d.show_customer(c)
	h.check("no badge next to an archetype's name", not d._sub_icon.visible)
	d.free()

func test_an_empty_table_carries_no_badge_either() -> void:
	var d := _instance()
	var c := _cust(&"easygoing", 1)
	d.show_offer(c, "COOL", _meter_scale())           # c.offer is still null
	h.check("nothing to put a badge on", not d._sub_icon.visible)
	d.free()

# --------------------------------------------------------- the meter's scale
func test_the_meter_scale_is_the_same_fixed_number_regardless_of_appeal_or_line() -> void:
	## It used to grow (and only ever grow) to fit whatever the current
	## negotiation needed, which meant the bar's own endpoint was a different
	## number on every card and every customer. Now it is one number, always -
	## ShiftConfig.appeal_meter_scale - and neither a low nor a sky-high
	## appeal/Line changes it.
	var d := _instance()
	var scale := _meter_scale()
	var c := _cust(&"easygoing", 1)
	c.line = 20
	c.offer = _offer(&"vsc", 5, 1600)
	d.show_offer(c, "COLD", scale)
	h.eq("low appeal, low Line: still the configured scale", d._bar._scale, scale)

	c.offer.appeal = scale * 3          # deliberately far past the ceiling
	c.line = scale * 2
	d.show_offer(c, "WARM", scale)
	h.eq("appeal and Line both past the ceiling: still the same scale",
		d._bar._scale, scale)

func test_a_new_offer_does_not_change_the_scale_either() -> void:
	## The scale has nothing to do with Offer identity any more - there is no
	## per-negotiation memory left to reset.
	var d := _instance()
	var scale := _meter_scale()
	var c := _cust(&"easygoing", 1)
	c.line = 20
	c.offer = _offer(&"vsc", 41, 1600)
	d.show_offer(c, "WARM", scale)
	h.eq("first offer", d._bar._scale, scale)

	c.offer = _offer(&"gap", 15, 1400, 2)   # a different Offer, same customer
	d.show_offer(c, "COLD", scale)
	h.eq("a different offer, same fixed scale", d._bar._scale, scale)
	d.free()
