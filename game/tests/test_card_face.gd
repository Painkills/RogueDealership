extends RefCounted
## The 3D card face. Its scene is hand-authored .tscn text rather than editor
## output, so these tests carry more weight than usual: they prove the
## inheritance link is real and the face is wired to the mesh.
##
## What they cannot tell you is whether it LOOKS right. Nothing headless can.
var h: Harness

const SCENE := "res://scenes/cards/card_face_3d.tscn"

func _instance() -> CardFace3D:
	return (load(SCENE) as PackedScene).instantiate() as CardFace3D

func _pool() -> CardPool:
	return load("res://data/card_pool.tres")

func _card(id: StringName) -> CardInstance:
	return CardInstance.new(_pool().by_id(id), 1)

func _front(c: CardFace3D) -> Node:
	return c.get_node(^"FrontViewport/CardFront/Margin/Column")

func test_the_scene_really_inherits_the_vendored_card() -> void:
	## A malformed .tscn would still instantiate - just empty. These children
	## come from card_3d.tscn, so their presence is what proves inheritance took.
	var c := _instance()
	h.check("instantiates as a CardFace3D", c != null)
	h.check("inherited CardMesh", c.get_node_or_null(^"CardMesh") != null)
	h.check("inherited CardFrontMesh", c.get_node_or_null(^"CardMesh/CardFrontMesh") != null)
	h.check("inherited CardBackMesh", c.get_node_or_null(^"CardMesh/CardBackMesh") != null)
	h.check("inherited the StaticBody3D that carries mouse input",
		c.get_node_or_null(^"StaticBody3D/CollisionShape3D") != null)
	h.check("and is a Card3D, so DragController will accept it", c is Card3D)
	c.free()

func test_the_face_is_a_subviewport_at_the_meshs_own_aspect() -> void:
	## 500x700 is exactly the 2.5 x 3.5 PlaneMesh, so nothing stretches. Drawing
	## the face large and minifying it is the whole reason the type is readable -
	## it is the approach Card3D's example_battle uses.
	var c := _instance()
	var vp := c.get_node_or_null(^"FrontViewport") as SubViewport
	h.check("there is a front viewport", vp != null)
	h.eq("sized to the card's aspect", vp.size, CardFace3D.FRONT_SIZE)
	h.check("and it does not render 3D it will never contain", vp.disable_3d)
	var front := c.get_node_or_null(^"FrontViewport/CardFront") as Control
	h.check("with the 2D face inside it", front != null)
	h.eq("at the same size", front.size, Vector2(CardFace3D.FRONT_SIZE))
	c.free()

func test_setup_writes_a_products_words_onto_the_face() -> void:
	var c := _instance()
	var vsc := _pool().by_id(&"vsc") as ProductCardDef
	c.setup(_card(&"vsc"))
	var col := _front(c)
	h.eq("name", (col.get_node(^"Header/NameLabel") as Label).text, vsc.display_name)
	h.eq("kind", (col.get_node(^"KindRow/KindLabel") as Label).text, "PRODUCT")
	h.eq("what need it answers", (col.get_node(^"BodyRow/BodyLabel") as Label).text,
		vsc.interest.category.display_name + " . " + vsc.interest.display_name)
	h.eq("margin, formatted the way every other surface formats money",
		(col.get_node(^"MarginLabel") as Label).text, Format.money(vsc.margin))
	h.eq("tick cost", (col.get_node(^"Header/CostLabel") as Label).text,
		"%dt" % vsc.ticks)
	c.free()

func test_a_products_body_carries_the_same_badge_the_interest_grid_uses() -> void:
	## "The cards should have that same icon next to their category name" - the
	## SAME glyph, not a lookalike: both read through CategoryIcon.draw().
	var c := _instance()
	var vsc := _pool().by_id(&"vsc") as ProductCardDef
	c.setup(_card(&"vsc"))
	var icon := _front(c).get_node(^"BodyRow/BodyIcon") as CategoryIconControl
	h.check("the badge is on the card", icon != null)
	h.check("and it is showing", icon.visible)
	h.eq("naming the product's own category", icon._category_id,
		vsc.interest.category.id)
	c.free()

func test_a_products_border_and_badge_share_the_products_own_color() -> void:
	var c := _instance()
	c.setup(_card(&"vsc"))
	var col := _front(c)
	var accent := Palette.color(&"accent")
	h.eq("the border reads product",
		(c.get_node(^"FrontViewport/CardFront/Background") as ColorRect).color, accent)
	h.eq("the kind label matches it",
		(col.get_node(^"KindRow/KindLabel") as Label).get_theme_color("font_color"), accent)
	var icon := col.get_node(^"KindRow/KindIcon") as CardTypeIconControl
	h.check("the type badge says product too", icon._is_product)
	c.free()

func test_a_support_cards_border_and_badge_share_the_support_color() -> void:
	var c := _instance()
	c.setup(_card(&"discount"))
	var col := _front(c)
	var action := Palette.color(&"action")
	h.eq("the border reads support",
		(c.get_node(^"FrontViewport/CardFront/Background") as ColorRect).color, action)
	h.eq("the kind label matches it",
		(col.get_node(^"KindRow/KindLabel") as Label).get_theme_color("font_color"), action)
	var icon := col.get_node(^"KindRow/KindIcon") as CardTypeIconControl
	h.check("the type badge says support too", not icon._is_product)
	c.free()

func test_the_back_shows_the_same_type_the_front_does() -> void:
	var product := _instance()
	product.setup(_card(&"vsc"))
	var product_back := product.get_node(^"BackViewport/CardBack") as CardBack2D
	h.check("the back agrees it is a product", product_back._icon._is_product)
	h.eq("tinted to match the front's own border",
		product_back._background.color, Palette.color(&"accent"))
	product.free()

	var support := _instance()
	support.setup(_card(&"discount"))
	var support_back := support.get_node(^"BackViewport/CardBack") as CardBack2D
	h.check("the back agrees it is support", not support_back._icon._is_product)
	h.eq("tinted to match the front's own border",
		support_back._background.color, Palette.color(&"action"))
	support.free()

func test_a_support_cards_body_carries_no_badge() -> void:
	## Its body is the effects' own describe() text, not a category - a badge
	## next to it would be a category that does not exist.
	var c := _instance()
	c.setup(_card(&"discount"))
	var icon := _front(c).get_node(^"BodyRow/BodyIcon") as CategoryIconControl
	h.check("no badge on a support card", not icon.visible)
	c.free()

func test_setup_writes_a_support_cards_effects_onto_the_face() -> void:
	var c := _instance()
	var discount := _pool().by_id(&"discount")
	c.setup(_card(&"discount"))
	var col := _front(c)
	h.eq("name", (col.get_node(^"Header/NameLabel") as Label).text, discount.display_name)
	h.eq("kind", (col.get_node(^"KindRow/KindLabel") as Label).text, "SUPPORT")
	h.check("body is built from the effects' own describe()",
		(col.get_node(^"BodyRow/BodyLabel") as Label).text.contains(
			(discount as SupportCardDef).effects[0].describe()))
	h.eq("support cards carry no margin of their own",
		(col.get_node(^"MarginLabel") as Label).text, "")
	c.free()

func test_setup_works_before_the_card_is_in_the_tree() -> void:
	## Reconciliation instantiates a card and calls setup() on it before adding
	## it to a collection, so nothing here may depend on _ready() having run.
	var c := _instance()
	var vsc := _pool().by_id(&"vsc")
	h.check("not in the tree yet", not c.is_inside_tree())
	c.setup(_card(&"vsc"))
	h.eq("still rendered its text",
		(_front(c).get_node(^"Header/NameLabel") as Label).text,
		vsc.display_name)
	c.free()

func test_setup_records_the_uid_the_whole_seam_runs_on() -> void:
	var c := _instance()
	var inst := CardInstance.new((load("res://data/card_pool.tres") as CardPool).by_id(&"vsc"), 4242)
	c.setup(inst)
	h.eq("uid is carried on the node", c.uid, 4242)
	h.check("and so is the instance", c.instance == inst)
	c.free()

func test_re_running_setup_updates_a_live_margin() -> void:
	## The reason the face is text and not baked art: ChangeMargin mutates the
	## offer while it sits on the table, and the card must not lie about it.
	var c := _instance()
	var inst := _card(&"vsc")
	c.setup(inst)
	var before: String = (_front(c).get_node(^"MarginLabel") as Label).text
	inst.upgraded = true
	c.setup(inst)
	var after: String = (_front(c).get_node(^"MarginLabel") as Label).text
	h.check("and it genuinely changed", before != after)
	h.eq("to the card's own upgraded margin, correctly formatted", after,
		Format.money(inst.margin()))
	c.free()

func test_the_face_is_authored_big_enough_to_survive_minification() -> void:
	## A card is only about a fifth of this on screen. Type sized for the final
	## card rather than for the source render is exactly what made the first
	## attempt at this unreadable.
	var c := _instance()
	var col := _front(c)
	for name in ["Header/NameLabel", "KindRow/KindLabel", "BodyRow/BodyLabel", "MarginLabel"]:
		var l := col.get_node(NodePath(name)) as Label
		h.check("%s is set well above default size (%d)"
			% [name, l.get_theme_font_size("font_size")],
			l.get_theme_font_size("font_size") >= 28)
		h.check("%s has a shadow to hold an edge when minified" % name,
			l.has_theme_color_override("font_shadow_color"))
	c.free()

func test_the_long_fields_wrap() -> void:
	var c := _instance()
	var col := _front(c)
	for name in ["Header/NameLabel", "BodyRow/BodyLabel"]:
		h.check("%s wraps by word" % name,
			(col.get_node(NodePath(name)) as Label).autowrap_mode == TextServer.AUTOWRAP_WORD)
	c.free()
