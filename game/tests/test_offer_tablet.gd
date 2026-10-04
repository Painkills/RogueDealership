extends RefCounted
## OfferTablet: the tablet a product stands on while you pitch it. Its shape
## and layout are constants the table's geometry leans on, and what its screen
## says is plain data on its labels and meter - so both are checkable without
## ever rendering it. Whether it LOOKS like a tablet is for eyes.
var h: Harness

const SCENE := "res://scenes/offer_tablet.tscn"
const CFG := {"appeal_step": 5, "line_per_sale": 3, "leaving_soon_at": 4}
const CARD := Vector2(2.5, 3.5)          ## the Card3D plane, from card_3d.tscn

func _instance() -> OfferTablet:
	return (load(SCENE) as PackedScene).instantiate() as OfferTablet

func _meter_scale() -> int:
	return (load("res://data/shift_config.tres") as ShiftConfig).appeal_meter_scale

func test_it_only_draws_while_it_is_on() -> void:
	var t := _instance()
	var vp := t.get_node(^"ScreenViewport") as SubViewport
	t.switch_on(false)
	h.check("off, it is out of sight", not t.visible and not t.is_on())
	h.eq("and its screen stops redrawing", vp.render_target_update_mode,
		SubViewport.UPDATE_DISABLED)
	t.switch_on(true)
	h.check("on, it is showing", t.visible and t.is_on())
	h.eq("and its screen redraws every frame, as every card face does",
		vp.render_target_update_mode, SubViewport.UPDATE_ALWAYS)
	t.free()

func test_an_empty_chair_shows_nobodys_numbers() -> void:
	var t := _instance()
	t.show_offer(null, "", _meter_scale())
	h.eq("an empty meter", t._bar._appeal, 0)
	h.eq("no combo from nobody", t._combo.text, "×1.00")
	h.eq("and no knobs to read", t._knobs.text, "")
	t.free()

func _find_collider(node: Node) -> Node:
	for child in node.get_children():
		if child is CollisionObject3D:
			return child
		var found := _find_collider(child)
		if found != null:
			return found
	return null
