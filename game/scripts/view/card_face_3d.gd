class_name CardFace3D extends Card3D
## One physical card on the table.
##
## The face is ordinary 2D UI (card_front_2d.tscn, 500x700) rendered into a
## SubViewport and used as the front mesh's albedo. This is the pattern Card3D's
## own example_battle uses, and it is why the type is readable: the face is
## authored large and minified onto the card, rather than being drawn at final
## size like Label3D text is.
##
## UPDATE_ALWAYS: continuous rather than baked-once-per-write. UPDATE_ONCE
## raced dynamic card creation on the Web export - hand cards, instantiated
## during reconciliation rather than once at scene load, rendered blank there
## while statically-created customer cards (identical technique) did not. A
## handful of small 500x700 viewports rendering every frame is cheap enough
## that trading the optimization for a mode no platform can race is the right
## call - this is a card game, not a scene starved for frame budget.

const FRONT_SIZE := Vector2i(500, 700)   ## exactly the mesh's 2.5 x 3.5 aspect

var uid: int = -1
var instance: CardInstance

var _material := StandardMaterial3D.new()
var _back_material := StandardMaterial3D.new()
var _bound := false
var _viewport: SubViewport
var _back_viewport: SubViewport
var _back: CardBack2D
var _name: Label
var _cost: Label
var _kind: Label
var _kind_icon: CardTypeIconControl
var _body: Label
var _body_icon: CategoryIconControl
var _flavor: Label
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
	_kind = front.get_node(^"Margin/Column/KindRow/KindLabel")
	_kind_icon = front.get_node(^"Margin/Column/KindRow/KindIcon")
	_body = front.get_node(^"Margin/Column/BodyRow/BodyLabel")
	_body_icon = front.get_node(^"Margin/Column/BodyRow/BodyIcon")
	_flavor = front.get_node(^"Margin/Column/FlavorLabel")
	_margin = front.get_node(^"Margin/Column/MarginLabel")

	_viewport.size = FRONT_SIZE
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_material.albedo_texture = _viewport.get_texture()
	$CardMesh/CardFrontMesh.set_surface_override_material(0, _material)

	_back_viewport = $BackViewport
	_back = $BackViewport/CardBack
	_back_viewport.size = FRONT_SIZE
	_back_viewport.disable_3d = true
	_back_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_back_material.albedo_texture = _back_viewport.get_texture()
	$CardMesh/CardBackMesh.set_surface_override_material(0, _back_material)

func setup(inst: CardInstance) -> void:
	_bind()
	instance = inst
	uid = inst.uid

	_name.text = CardText.title(inst)
	_cost.text = CardText.cost(inst)
	_kind.text = CardText.kind(inst)
	_body.text = CardText.body(inst)
	# The same glyph the interest grid uses for this row, so a Vehicle Service
	# Contract and a Vehicle-lit row on a customer's card read as the same fact.
	if inst.is_product():
		var p := inst.card as ProductCardDef
		_body_icon.set_category(p.interest.category.id, Palette.color(&"accent"))
	else:
		_body_icon.set_category(&"", Color.WHITE)
	_flavor.text = CardText.flavor(inst)
	_margin.text = CardText.margin(inst)

	# The badge and label share one color per type - accent for a product,
	# action for a support card - so "what kind of card is this" reads at a
	# glance, not just from the word itself.
	var kind_color := Palette.color(&"accent") if inst.is_product() else Palette.color(&"action")
	_kind.add_theme_color_override("font_color", kind_color)
	_kind_icon.set_type(inst.is_product(), kind_color)
	_back.setup()
	# An upgraded card should be obvious without reading it.
	_name.add_theme_color_override("font_color",
		Palette.color(&"appeal") if inst.upgraded else Palette.color(&"text"))

	_redraw()

func _redraw() -> void:
	if _viewport != null:
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if _back_viewport != null:
		_back_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
