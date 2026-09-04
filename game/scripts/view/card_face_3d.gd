class_name CardFace3D extends Card3D
## One physical card on the table.
##
## The face is ordinary 2D UI (card_front_2d.tscn, 500x700) rendered into a
## SubViewport and used as the front mesh's albedo. This is the pattern Card3D's
## own example_battle uses, and it is why the type is readable: the face is
## authored large and minified onto the card, rather than being drawn at final
## size like Label3D text is.
##
## The viewport only re-renders when something changed - UPDATE_ONCE after every
## write - so four cards in hand are not four extra viewports rendering forever.

const FRONT_SIZE := Vector2i(500, 700)   ## exactly the mesh's 2.5 x 3.5 aspect

var uid: int = -1
var instance: CardInstance

var _material := StandardMaterial3D.new()
var _bound := false
var _viewport: SubViewport
var _name: Label
var _cost: Label
var _kind: Label
var _body: Label
var _margin: Label

func _ready() -> void:
	_bind()
	# Deferred because a SubViewport has not rendered a frame yet at _ready, and
	# binding its texture before that leaves the card blank until something else
	# happens to dirty it.
	_redraw.call_deferred()

## Child nodes exist from instantiate(), but the viewport's texture is only
## meaningful once we are in the tree - so text can be written any time, while
## the material is attached here.
func _bind() -> void:
	if _bound:
		return
	_bound = true
	_viewport = $FrontViewport
	var front: Control = $FrontViewport/CardFront
	_name = front.get_node(^"Margin/Column/Header/NameLabel")
	_cost = front.get_node(^"Margin/Column/Header/CostLabel")
	_kind = front.get_node(^"Margin/Column/KindLabel")
	_body = front.get_node(^"Margin/Column/BodyLabel")
	_margin = front.get_node(^"Margin/Column/MarginLabel")

	_viewport.size = FRONT_SIZE
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_material.albedo_texture = _viewport.get_texture()
	$CardMesh/CardFrontMesh.set_surface_override_material(0, _material)

func setup(inst: CardInstance) -> void:
	_bind()
	instance = inst
	uid = inst.uid

	_name.text = CardText.title(inst)
	_cost.text = CardText.cost(inst)
	_kind.text = CardText.kind(inst)
	_body.text = CardText.body(inst)
	_margin.text = CardText.margin(inst)

	if inst.is_product():
		_kind.add_theme_color_override("font_color", Palette.color(&"accent"))
	else:
		_kind.add_theme_color_override("font_color", Palette.color(&"action"))
	# An upgraded card should be obvious without reading it.
	_name.add_theme_color_override("font_color",
		Palette.color(&"appeal") if inst.upgraded else Palette.color(&"text"))

	_redraw()

func _redraw() -> void:
	if _viewport != null:
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
