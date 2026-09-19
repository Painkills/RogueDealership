class_name CardPreview2D extends Control
## The shop's answer to "what does this actually look like" - the SAME
## card_front_2d.tscn face used everywhere else, minus the 3D mesh CardFace3D
## wraps it in. The shop is a plain 2D screen with no mesh to feed a texture
## into, so this reads the SubViewport straight into a TextureRect instead -
## the identical "author big, minify" trick CardFace3D already uses, one step
## shorter because there is no albedo material in the way.

const FRONT_SIZE := Vector2i(500, 700)

var _viewport: SubViewport
var _texture: TextureRect
var _background: ColorRect
var _name: Label
var _cost: Label
var _kind: Label
var _kind_icon: CardTypeIconControl
var _body: Label
var _body_icon: CategoryIconControl
var _margin: Label
var _bound := false

func _ready() -> void:
	_bind()
	clear()

func _bind() -> void:
	if _bound:
		return
	_bound = true
	_viewport = $SubViewport
	_texture = $TextureRect
	var front: Control = $SubViewport/CardFront
	_background = front.get_node(^"Background")
	_name = front.get_node(^"Margin/Column/Header/NameLabel")
	_cost = front.get_node(^"Margin/Column/Header/CostLabel")
	_kind = front.get_node(^"Margin/Column/KindRow/KindLabel")
	_kind_icon = front.get_node(^"Margin/Column/KindRow/KindIcon")
	_body = front.get_node(^"Margin/Column/BodyRow/BodyLabel")
	_body_icon = front.get_node(^"Margin/Column/BodyRow/BodyIcon")
	_margin = front.get_node(^"Margin/Column/MarginLabel")

	_viewport.size = FRONT_SIZE
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_texture.texture = _viewport.get_texture()
	# Set here rather than trusted to the .tscn's own stored value - the same
	# habit CardFace3D and friends already have of re-asserting the one
	# property that actually matters in code, not in a hand-authored resource.
	_texture.stretch_mode = TextureRect.STRETCH_SCALE
	# The actual bug: TextureRect.expand_mode defaults to EXPAND_KEEP_SIZE,
	# which floors the control's own minimum size at its TEXTURE's native
	# resolution (500x700) - no stretch_mode choice matters until this is
	# set, since the control never actually shrinks to this node's real
	# 260x364 box in the first place. Confirmed headless: before this line,
	# get_combined_minimum_size() reports (500, 700); after it, (0, 0), and
	# the control's own .size correctly becomes (260, 364). This is not a
	# renderer quirk - it is a plain Godot default nothing here had ever
	# overridden, and it was invisible to every existing check because they
	# all measure Control rects (global_position/size), never the actual
	# rendered pixels a screenshot would show.
	_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE

## What is actually in front of you right now, on the exact same card face the
## floor uses - so "what does this offer look like" or "what does upgrading
## this actually change" is never a guess from a row of plain button text.
func show_card(inst: CardInstance) -> void:
	_bind()
	_name.text = CardText.title(inst)
	_cost.text = CardText.cost(inst)
	_kind.text = CardText.kind(inst)
	_body.text = CardText.body(inst)
	# The same glyph the interest grid and every other card use for this
	# category, so a card previewed here is never a different visual language
	# from the one it will join.
	if inst.is_product():
		var p := inst.card as ProductCardDef
		_body_icon.set_category(p.interest.category.id, Palette.color(&"accent"))
	else:
		_body_icon.set_category(&"", Color.WHITE)
	_margin.text = CardText.margin(inst)
	var kind_color := Palette.color(&"accent") if inst.is_product() else Palette.color(&"action")
	_background.color = kind_color
	_kind.add_theme_color_override("font_color", kind_color)
	_kind_icon.set_type(inst.is_product(), kind_color)
	_name.add_theme_color_override("font_color",
		Palette.color(&"appeal") if inst.upgraded else Palette.color(&"text"))

## The same shape CustomerCard3D.setup(null) uses for an empty chair: one
## state on the SAME node rather than a second node to keep hidden and synced.
func clear() -> void:
	_bind()
	_name.text = "hover a card"
	_name.add_theme_color_override("font_color", Palette.color(&"text_dim"))
	_cost.text = ""
	_kind.text = ""
	_kind_icon.visible = false
	_background.color = Palette.color(&"panel")
	_body.text = "to see it here"
	_body_icon.set_category(&"", Color.WHITE)
	_margin.text = ""
