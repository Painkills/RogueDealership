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
	h.eq("and what they have agreed to", d._table.text, CustomerCard3D.unsigned_text(c))
	d.free()

func test_the_back_still_looks_like_a_folder_with_stickers_on_it() -> void:
	## "The back of the customer card should still look like a file folder or a
	## sheet of paper at least, with the headings as if they were stickers or
	## something. Also, I don't think we need the What you know section."
	var d := _instance()
	d.show_customer(_cust(&"karen", 1))
	var face := d.get_node(^"FrontViewport/DetailFront")
	var cover := face.get_node_or_null(^"Cover") as ColorRect
	h.check("the folder's manila cover", cover != null
		and cover.color == Palette.color(&"manila"))
	var tab := face.get_node_or_null(^"Tab") as Control
	h.check("and its tab, in the front's corner - the other is CLOSE SOON's",
		tab != null and tab.position.x + tab.size.x * 0.5 < DetailCard3D.FRONT_SIZE.x * 0.5)
	h.check("their name on it", tab != null and d._title.get_parent() == tab)
	h.check("and a sheet of paper on the cover", face.get_node_or_null(^"Sheet") != null)
	var body := face.get_node(^"Margin/Column/CustomerBody")
	for name in ["DoesTitle", "TableTitle"]:
		var spot := body.get_node_or_null(NodePath(name)) as Control
		var sticker := spot.get_node_or_null(^"Sticker") as PanelContainer if spot != null else null
		h.check("%s is a sticker - a filled label, not a line of grey type" % name,
			sticker != null and (sticker.get_theme_stylebox("panel") as StyleBoxFlat).bg_color.a > 0.9)
		if sticker != null:
			h.check("%s is stuck on a little crooked, by hand (%.1f degrees)"
				% [name, sticker.rotation_degrees],
				absf(sticker.rotation_degrees) > 0.5 and absf(sticker.rotation_degrees) < 5.0)
			# A container would lay a tilted child straight again - see
			# build_detail_front_scene.gd's _section().
			h.check("in a spot that keeps the tilt, not a container that resets it",
				not (spot is Container) and spot.custom_minimum_size.y > 0.0)
	h.check("no What you know section any more",
		body.get_node_or_null(^"KnownTitle") == null and body.get_node_or_null(^"KnownLabel") == null)
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
