class_name ShopCardButton extends Button
## A real card face you can click. The shelf ("click to buy") and the deck
## browser ("click to manage") both use this exact widget - only what the
## caller connects to `pressed` differs - so a card looks like the SAME
## thing everywhere it appears, on the floor or in the shop.
##
## Same SubViewport-to-TextureRect trick card_preview_2d.gd already
## established: card_front_2d.tscn authored at 500x700, minified onto
## whatever this button's own size is.

const FRONT_SIZE := Vector2i(500, 700)

var _viewport: SubViewport
var _texture: TextureRect
var _name: Label
var _cost: Label
var _kind: Label
var _body: Label
var _body_icon: CategoryIconControl
var _margin: Label
var _bound := false

func _ready() -> void:
	_bind()

func _bind() -> void:
	if _bound:
		return
	_bound = true
	_viewport = $SubViewport
	_texture = $TextureRect
	var front: Control = $SubViewport/CardFront
	_name = front.get_node(^"Margin/Column/Header/NameLabel")
	_cost = front.get_node(^"Margin/Column/Header/CostLabel")
	_kind = front.get_node(^"Margin/Column/KindLabel")
	_body = front.get_node(^"Margin/Column/BodyRow/BodyLabel")
	_body_icon = front.get_node(^"Margin/Column/BodyRow/BodyIcon")
	_margin = front.get_node(^"Margin/Column/MarginLabel")

	_viewport.size = FRONT_SIZE
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_texture.texture = _viewport.get_texture()
	_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

func show_card(inst: CardInstance) -> void:
	_bind()
	_name.text = CardText.title(inst)
	_cost.text = CardText.cost(inst)
	_kind.text = CardText.kind(inst)
	_body.text = CardText.body(inst)
	# The same glyph the interest grid and every other card use for this
	# category, so a card here is never a different visual language from the
	# one it will join.
	if inst.is_product():
		var p := inst.card as ProductCardDef
		_body_icon.set_category(p.interest.category.id, Palette.color(&"accent"))
	else:
		_body_icon.set_category(&"", Color.WHITE)
	_margin.text = CardText.margin(inst)
	if inst.is_product():
		_kind.add_theme_color_override("font_color", Palette.color(&"accent"))
	else:
		_kind.add_theme_color_override("font_color", Palette.color(&"action"))
	# An upgraded card (or a preview of one) reads the same appeal colour the
	# hand and table already use for it.
	_name.add_theme_color_override("font_color",
		Palette.color(&"appeal") if inst.upgraded else Palette.color(&"text"))
