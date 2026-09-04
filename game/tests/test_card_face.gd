extends RefCounted
## The 3D card face. Its scene is hand-authored .tscn text rather than editor
## output, so these tests carry more weight than usual: they are what proves the
## inheritance link is real and the Label3D settings survived.
##
## What this cannot tell you is whether any of it is READABLE. Nothing headless
## can. That is still a question for someone with a screen.
var h: Harness

const SCENE := "res://scenes/cards/card_face_3d.tscn"

func _instance() -> CardFace3D:
	return (load(SCENE) as PackedScene).instantiate() as CardFace3D

func _card(id: StringName) -> CardInstance:
	var pool: CardPool = load("res://data/card_pool.tres")
	return CardInstance.new(pool.by_id(id), 1)

func test_the_scene_really_inherits_the_vendored_card() -> void:
	## If the .tscn were malformed, instantiate() would still give a Node3D - but
	## it would be an EMPTY one. These children come from card_3d.tscn, so their
	## presence is the actual proof that inheritance took.
	var c := _instance()
	h.check("instantiates as a CardFace3D", c != null)
	h.check("inherited CardMesh", c.get_node_or_null(^"CardMesh") != null)
	h.check("inherited CardFrontMesh", c.get_node_or_null(^"CardMesh/CardFrontMesh") != null)
	h.check("inherited CardBackMesh", c.get_node_or_null(^"CardMesh/CardBackMesh") != null)
	h.check("inherited the StaticBody3D that carries mouse input",
		c.get_node_or_null(^"StaticBody3D/CollisionShape3D") != null)
	h.check("and is a Card3D, so DragController will accept it", c is Card3D)
	c.free()

func test_the_labels_hang_off_cardmesh_so_face_down_hides_them() -> void:
	## face_down rotates CardMesh by PI. Text parented to the root instead would
	## keep facing the camera and float over the card's own back.
	var c := _instance()
	h.check("Front is a child of CardMesh, not of the root",
		c.get_node_or_null(^"CardMesh/Front") != null)
	h.check("nothing stray parented to the root",
		c.get_node_or_null(^"Front") == null)
	for label in ["NameLabel", "CostLabel", "KindLabel", "BodyLabel", "MarginLabel"]:
		h.check("%s exists" % label,
			c.get_node_or_null(NodePath("CardMesh/Front/" + label)) != null)
	c.free()

func test_setup_writes_a_products_words_onto_the_card() -> void:
	var c := _instance()
	c.setup(_card(&"vsc"))
	var front := c.get_node(^"CardMesh/Front")
	h.eq("name", (front.get_node(^"NameLabel") as Label3D).text, "Vehicle Service Contract")
	h.eq("kind", (front.get_node(^"KindLabel") as Label3D).text, "PRODUCT")
	h.eq("what need it answers", (front.get_node(^"BodyLabel") as Label3D).text,
		"Vehicle . Reliability")
	h.eq("margin, formatted the same way every other surface formats money",
		(front.get_node(^"MarginLabel") as Label3D).text, "$1,600")
	h.eq("tick cost", (front.get_node(^"CostLabel") as Label3D).text, "1t")
	c.free()

func test_setup_writes_a_support_cards_effects_onto_the_card() -> void:
	var c := _instance()
	c.setup(_card(&"discount"))
	var front := c.get_node(^"CardMesh/Front")
	h.eq("name", (front.get_node(^"NameLabel") as Label3D).text, "Offer a Discount")
	h.eq("kind", (front.get_node(^"KindLabel") as Label3D).text, "SUPPORT")
	h.check("body is built from the effects' own describe()",
		(front.get_node(^"BodyLabel") as Label3D).text.contains("Appeal"))
	h.eq("support cards carry no margin of their own",
		(front.get_node(^"MarginLabel") as Label3D).text, "")
	c.free()

func test_setup_works_before_the_card_is_in_the_tree() -> void:
	## Reconciliation instantiates a card and calls setup() on it before adding
	## it to a collection. If the label refs were @onready this would crash on a
	## null, so it is worth pinning rather than rediscovering.
	var c := _instance()
	h.check("not in the tree yet", not c.is_inside_tree())
	c.setup(_card(&"vsc"))
	h.eq("still rendered its text", (c.get_node(^"CardMesh/Front/NameLabel") as Label3D).text,
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
	## The reason the face is text and not a baked texture: ChangeMargin mutates
	## the offer while it sits on the table, and the card must not lie about it.
	var c := _instance()
	var inst := _card(&"vsc")
	c.setup(inst)
	var before: String = (c.get_node(^"CardMesh/Front/MarginLabel") as Label3D).text
	inst.upgraded = true
	c.setup(inst)
	var after: String = (c.get_node(^"CardMesh/Front/MarginLabel") as Label3D).text
	h.eq("upgraded margin is what the card now shows", after, "$1,900")
	h.check("and it genuinely changed", before != after)
	c.free()

func test_every_label_is_configured_for_legibility_not_defaults() -> void:
	## Label3D's defaults are wrong for pixel-ish text on an angled card, and a
	## later editor session could silently restore them.
	var c := _instance()
	var front := c.get_node(^"CardMesh/Front")
	for name in ["NameLabel", "CostLabel", "KindLabel", "BodyLabel", "MarginLabel"]:
		var l := front.get_node(NodePath(name)) as Label3D
		h.check("%s is unshaded, so it cannot go muddy at an angle" % name, not l.shaded)
		h.check("%s is single-sided, so it does not mirror through the back" % name,
			not l.double_sided)
		h.check("%s uses nearest filtering, like every other texture here" % name,
			l.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST)
		h.check("%s discards alpha rather than sorting as transparency" % name,
			l.alpha_cut == Label3D.ALPHA_CUT_DISCARD)
		h.check("%s is not billboarded - it should tilt with the card" % name,
			l.billboard == BaseMaterial3D.BILLBOARD_DISABLED)
		h.check("%s draws over the card mesh" % name, l.render_priority > 0)
		h.check("%s has an outline to survive foreshortening" % name, l.outline_size > 0)
		# 32-bit storage, so compare approximately rather than by identity.
		h.check("%s uses the shared pixel size" % name,
			is_equal_approx(l.pixel_size, CardFace3D.PIXEL_SIZE))
	c.free()

func test_the_wrapping_labels_are_the_ones_that_can_overflow() -> void:
	var c := _instance()
	var front := c.get_node(^"CardMesh/Front")
	for name in ["NameLabel", "BodyLabel"]:
		var l := front.get_node(NodePath(name)) as Label3D
		h.check("%s wraps by word" % name, l.autowrap_mode == TextServer.AUTOWRAP_WORD)
		h.check("%s has a width to wrap within" % name, l.width > 0.0)
	c.free()

func test_the_front_sits_just_off_the_mesh_face() -> void:
	## Coplanar text z-fights. A small positive Z is what prevents it, and +Z is
	## the direction CardFrontMesh faces.
	var front := _front_of_a_freed_instance()
	h.check("Front is offset toward the viewer", front > 0.0)
	h.check("but not so far it detaches from the card", front < 0.1)

func _front_of_a_freed_instance() -> float:
	var c := _instance()
	var z: float = (c.get_node(^"CardMesh/Front") as Node3D).position.z
	c.free()
	return z
