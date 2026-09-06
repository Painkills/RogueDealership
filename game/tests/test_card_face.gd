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

func _card(id: StringName) -> CardInstance:
	var pool: CardPool = load("res://data/card_pool.tres")
	return CardInstance.new(pool.by_id(id), 1)

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
	c.setup(_card(&"vsc"))
	var col := _front(c)
	h.eq("name", (col.get_node(^"Header/NameLabel") as Label).text,
		"Vehicle Service Contract")
	h.eq("kind", (col.get_node(^"KindLabel") as Label).text, "PRODUCT")
	h.eq("what need it answers", (col.get_node(^"BodyLabel") as Label).text,
		"Vehicle . Reliability")
	h.eq("margin, formatted the way every other surface formats money",
		(col.get_node(^"MarginLabel") as Label).text, "$1,600")
	h.eq("tick cost", (col.get_node(^"Header/CostLabel") as Label).text, "1t")
	c.free()

func test_setup_writes_a_support_cards_effects_onto_the_face() -> void:
	var c := _instance()
	c.setup(_card(&"discount"))
	var col := _front(c)
	h.eq("name", (col.get_node(^"Header/NameLabel") as Label).text, "Offer a Discount")
	h.eq("kind", (col.get_node(^"KindLabel") as Label).text, "SUPPORT")
	h.check("body is built from the effects' own describe()",
		(col.get_node(^"BodyLabel") as Label).text.contains("Appeal"))
	h.eq("support cards carry no margin of their own",
		(col.get_node(^"MarginLabel") as Label).text, "")
	c.free()

func test_setup_works_before_the_card_is_in_the_tree() -> void:
	## Reconciliation instantiates a card and calls setup() on it before adding
	## it to a collection, so nothing here may depend on _ready() having run.
	var c := _instance()
	h.check("not in the tree yet", not c.is_inside_tree())
	c.setup(_card(&"vsc"))
	h.eq("still rendered its text",
		(_front(c).get_node(^"Header/NameLabel") as Label).text,
		"Vehicle Service Contract")
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
	h.eq("upgraded margin is what the card now shows",
		(_front(c).get_node(^"MarginLabel") as Label).text, "$2,000")
	h.check("and it genuinely changed", before != "$1,900")
	c.free()

func test_the_face_is_authored_big_enough_to_survive_minification() -> void:
	## A card is only about a fifth of this on screen. Type sized for the final
	## card rather than for the source render is exactly what made the first
	## attempt at this unreadable.
	var c := _instance()
	var col := _front(c)
	for name in ["Header/NameLabel", "KindLabel", "BodyLabel", "MarginLabel"]:
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
	for name in ["Header/NameLabel", "BodyLabel"]:
		h.check("%s wraps by word" % name,
			(col.get_node(NodePath(name)) as Label).autowrap_mode == TextServer.AUTOWRAP_WORD)
	c.free()
