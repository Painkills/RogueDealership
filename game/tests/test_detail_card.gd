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

func test_an_empty_chair_says_so() -> void:
	var d := _instance()
	d.show_customer(null)
	h.eq("nobody's name", d._title.text, "- empty -")
	h.check("and no sheet about nobody", not d._customer_body.visible)
	d.free()
