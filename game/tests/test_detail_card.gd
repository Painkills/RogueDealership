extends RefCounted
## DetailCard3D's non-visual behaviour - the back of a customer's folder. What it
## draws is out of headless reach - see test_card_face.gd's own header - but
## everything here is plain data on the node, readable without ever calling
## _draw().
var h: Harness

const SCENE := "res://scenes/cards/detail_card_3d.tscn"
const CFG := {"appeal_step": 5, "line_per_sale": 3, "leaving_soon_at": 4}

func _instance() -> DetailCard3D:
	return (load(SCENE) as PackedScene).instantiate() as DetailCard3D

func _interests() -> InterestPool:
	return load("res://data/interests/interest_pool.tres")

func _cust(id: StringName, seed_value: int) -> Customer:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var a := (load("res://data/archetype_pool.tres") as ArchetypePool).by_id(id)
	var ranks := Customer.make_ranks(a, _interests(), rng, 0.0)
	return Customer.new("A", "Test Person", a, ranks, a.patience, a.patience,
		CFG, _interests())

func test_the_back_of_their_folder_says_who_they_are_and_what_they_do() -> void:
	var d := _instance()
	var c := _cust(&"karen", 1)
	d.show_customer(c)
	h.eq("their name heads it", d._title.text, c.display_name)
	h.eq("and their archetype under it", d._sub.text, c.archetype.display_name)
	h.check("with the sheet about them showing", d._customer_body.visible)
	h.eq("what they do to you", d._does.text, CustomerCard3D.behaviour_text(c))
	h.eq("what they have agreed to", d._table.text, CustomerCard3D.unsigned_text(c))
	h.eq("and what you have worked out", d._known.text, CustomerCard3D.known_text(c))
	d.free()

func test_an_empty_chair_says_so() -> void:
	var d := _instance()
	d.show_customer(null)
	h.eq("nobody's name", d._title.text, "- empty -")
	h.check("and no sheet about nobody", not d._customer_body.visible)
	d.free()

func test_the_product_half_is_gone() -> void:
	## The product slot's own detail card - the one that slid out with the
	## appeal meter - is the tablet's job now (see test_offer_tablet.gd). What
	## is left is only ever the back of a folder.
	var d := _instance()
	var col := d.get_node(^"FrontViewport/DetailFront/Margin/Column")
	h.check("no product body left on the face", col.get_node_or_null(^"OfferBody") == null)
	h.check("and no appeal meter", not d.has_method(&"show_offer"))
	d.free()
