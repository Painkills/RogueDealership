class_name DetailCard3D extends Card3D
## The back of a customer's folder: what their archetype does to you, and what
## they have already agreed to. What you have worked out about their priorities
## used to be here too; the interest grid on the front says all of it.
##
## It sits flush behind the folder at the same x and y, facing the other way,
## so at rest it is simply occluded and costs nothing. Hovering the customer
## turns the pair over (see FlipPair), and then this is the side facing you.
##
## There used to be a second one behind every product slot, which slid out
## beside the product with its appeal meter. That job is the tablet's now (see
## OfferTablet): it was a card saying the product's name again in smaller type,
## beside a card that already said it.
##
## Never dragged, never dropped on. Collision is disabled for its whole life, so
## it can never intercept a pointer aimed at the folder it sits behind.

## The folder's own size and face, since that is the only thing this is ever
## the back of - a back that is not the same shape as its front is not a back.
const FRONT_SIZE := Vector2i(800, 700)
const CARD_SIZE := Vector2(4.0, 3.5)
## The card's size in the world and its face's in pixels. build_shift_scene.gd
## sets both to the customer's folder's own, CustomerCard3D's.
@export var card_size := CARD_SIZE
@export var face_size := FRONT_SIZE

var _material := StandardMaterial3D.new()
var _bound := false
var _viewport: SubViewport
var _title: Label
var _sub: Label
var _customer_body: Control
var _does: Label
var _table: Label

func _ready() -> void:
	disable_collision()
	_bind()
	_redraw.call_deferred()

func _bind() -> void:
	if _bound:
		return
	_bound = true
	_viewport = $FrontViewport
	var col: Node = $FrontViewport/DetailFront/Margin/Column
	# Their name is on the folder's tab; their kind of buyer heads the sheet.
	_title = $FrontViewport/DetailFront/Tab/TitleLabel
	_sub = col.get_node(^"SubLabel")
	_customer_body = col.get_node(^"CustomerBody")
	_does = _customer_body.get_node(^"DoesLabel")
	_table = _customer_body.get_node(^"TableLabel")

	_viewport.size = face_size
	($FrontViewport/DetailFront as Control).size = Vector2(face_size)
	CustomerCard3D.resize_quads(self, card_size)
	_viewport.disable_3d = true
	# UPDATE_ALWAYS, not UPDATE_ONCE: see card_face_3d.gd - the one-shot bake
	# raced dynamic card creation on the Web export.
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_material.albedo_texture = _viewport.get_texture()
	$CardMesh/CardFrontMesh.set_surface_override_material(0, _material)

## Their sheet: what their archetype does to you, and what they have already
## agreed to.
func show_customer(c) -> void:
	_bind()
	_customer_body.visible = c != null
	if c == null:
		_title.text = "- empty -"
		_sub.text = "nobody in this chair"
		_redraw()
		return
	_title.text = c.display_name
	_sub.text = c.archetype.display_name
	_does.text = CustomerCard3D.behaviour_text(c)
	_table.text = CustomerCard3D.unsigned_text(c)
	_redraw()

func _redraw() -> void:
	if _viewport != null:
		# UPDATE_ALWAYS, not UPDATE_ONCE: see card_face_3d.gd - the one-shot bake
		# raced dynamic card creation on the Web export.
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
