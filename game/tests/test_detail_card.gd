extends RefCounted
## DetailCard3D's non-visual behaviour: the appeal meter's own memory, and the
## category badge wired onto its sub line. What it draws is out of headless
## reach - see test_card_face.gd's own header - but everything here is plain
## data on the node, readable without ever calling _draw().
var h: Harness

const SCENE := "res://scenes/cards/detail_card_3d.tscn"
const CFG := {"appeal_step": 5, "line_per_sale": 3, "leaving_soon_at": 4}

func _instance() -> DetailCard3D:
	return (load(SCENE) as PackedScene).instantiate() as DetailCard3D

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
	d.show_offer(c, "COOL")
	h.check("the badge is showing", d._sub_icon.visible)
	h.eq("naming the product's own category", d._sub_icon._category_id, &"vehicle")
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
	d.show_offer(c, "COOL")           # c.offer is still null
	h.check("nothing to put a badge on", not d._sub_icon.visible)
	d.free()

# ----------------------------------------------------- the meter's own memory
func test_the_meter_scale_never_shrinks_within_the_same_offer() -> void:
	## The bug: meter_scale() used to be recomputed fresh from whatever appeal
	## and Line happened to be THIS render, so the bar's own endpoint could
	## grow AND shrink from one card play to the next - "resizing its highest
	## point" is exactly what that looked like.
	var d := _instance()
	var c := _cust(&"easygoing", 1)
	c.line = 20
	c.offer = _offer(&"vsc", 33, 1600)
	d.show_offer(c, "WARM")
	var after_33 := d._bar._scale
	h.eq("40 comfortably covers 33 and a Line of 20", after_33, 40)

	c.offer.appeal = 41                # crosses the ten boundary Discount would
	d.show_offer(c, "WARM")
	var after_41 := d._bar._scale
	h.check("it grew, because 41 genuinely needs more room",
		after_41 > after_33)

	c.offer.appeal = 35                # a later card brings it back down
	d.show_offer(c, "WARM")
	h.eq("but it does NOT shrink back just because appeal dropped",
		d._bar._scale, after_41)

func test_a_genuinely_new_offer_starts_the_meter_over() -> void:
	## place() always builds a fresh Offer, even for the same product placed
	## twice - so "a new negotiation" is exactly "a different Offer object",
	## and that is the only thing allowed to reset the memory.
	var d := _instance()
	var c := _cust(&"easygoing", 1)
	c.line = 20
	c.offer = _offer(&"vsc", 41, 1600)
	d.show_offer(c, "WARM")
	h.check("grown past the default for the first offer", d._bar._scale > 40)

	c.offer = _offer(&"gap", 15, 1400, 2)   # a different Offer, same customer
	d.show_offer(c, "COLD")
	h.eq("a fresh product starts the meter fresh", d._bar._scale, 40)

func test_dropping_the_offer_forgets_the_scale_too() -> void:
	var d := _instance()
	var c := _cust(&"easygoing", 1)
	c.line = 20
	c.offer = _offer(&"vsc", 41, 1600)
	d.show_offer(c, "WARM")
	h.check("grown", d._bar._scale > 40)

	c.offer = null
	d.show_offer(c, "")
	c.offer = _offer(&"vsc", 33, 1600, 3)
	d.show_offer(c, "WARM")
	h.eq("the empty table in between cleared the memory too", d._bar._scale, 40)
	d.free()
