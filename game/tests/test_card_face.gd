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
