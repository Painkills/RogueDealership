class_name CardFront extends Control
## The face of a card (card_front_2d.tscn): what every place that shows one - the
## table (CardFace3D), the store (ShopCardButton), the preview (CardPreview2D) -
## does to it beyond writing its words. The picture, when the card has one; the
## tick cost on a clock; and a product's body laid out as a small category
## line, its effect, and its price.

## How big a product's category line is, and its flag - it says what kind of
## product this is, which matters less than what it does and what it pays.
const CATEGORY_FONT := 34
const CATEGORY_ICON := 40
## A support card's effect, and a product's: the line that says what it does.
const EFFECT_FONT := 46
const PRODUCT_EFFECT_FONT := 44
## Whether cards show their pictures at all. Off while the art is being made:
## the cards keep their pictures (CardDef.art, art/cards/), they just don't
## show them until this is turned back on.
const SHOW_ART := false

@onready var _art: Control = $Margin/Column/Art
@onready var _picture: TextureRect = $Margin/Column/Art/Clip/Picture
@onready var _clock: TickClock = $TickClock
@onready var _ticks_label: Label = $Margin/Column/Header/TicksLabel
@onready var _body_icon: Control = $Margin/Column/BodyRow/BodyIcon
@onready var _body: Label = $Margin/Column/BodyRow/BodyLabel
@onready var _effect: Label = $Margin/Column/FlavorLabel
@onready var _price: Label = $Margin/Column/MarginLabel

## Everything about `inst`'s face but its words, which its owner writes.
func dress(inst: CardInstance) -> void:
	if not is_node_ready():
		await ready
	var art: Texture2D = inst.card.art
	_art.visible = SHOW_ART and art != null
	_picture.texture = art

	_clock.show_ticks(inst.ticks())
	_ticks_label.visible = false

	if inst.is_product():
		# The flag beside its category, one line, smaller and dimmer.
		_body_icon.visible = true
		_body_icon.custom_minimum_size = Vector2(CATEGORY_ICON, CATEGORY_ICON)
		_body.add_theme_font_size_override("font_size", CATEGORY_FONT)
		_body.add_theme_color_override("font_color", Palette.color(&"text_dim"))
		_body.autowrap_mode = TextServer.AUTOWRAP_OFF
		_body.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	else:
		_body_icon.visible = false
		_body.add_theme_font_size_override("font_size", EFFECT_FONT)
		_body.add_theme_color_override("font_color", Palette.color(&"text"))
		_body.autowrap_mode = TextServer.AUTOWRAP_WORD
		_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# A product's effect, as big as a support card's - and nothing at all when it
	# has none.
	_effect.visible = _effect.text != ""
	# Only a product has a price; a support card gives the room to its words.
	_price.visible = inst.is_product()

## Marks in highlighter yellow what is different on this face from `before` -
## the store's upgrade preview, so an upgrade that only takes a tick off the
## cost is as plain as one that changes what the card does. Null: nothing marked.
func highlight_changes(before: CardInstance) -> void:
	if not is_node_ready():
		await ready
	var shown := _clock.ticks
	_clock.highlighted = before != null and before.ticks() != shown
	_clock.queue_redraw()
	_mark(_body, before != null and CardText.body(before) != _body.text)
	_mark(_effect, before != null and CardText.flavor(before) != _effect.text)
	_mark(_price, before != null and CardText.margin(before) != _price.text)

## What highlight_changes() marked, by part - for checks.
func highlighted() -> Array[StringName]:
	var out: Array[StringName] = []
	if _clock.highlighted:
		out.append(&"ticks")
	if _body.has_theme_stylebox_override("normal"):
		out.append(&"body")
	if _effect.has_theme_stylebox_override("normal"):
		out.append(&"effect")
	if _price.has_theme_stylebox_override("normal"):
		out.append(&"price")
	return out

func _mark(label: Label, on: bool) -> void:
	if not on:
		label.remove_theme_stylebox_override("normal")
		return
	var marker := StyleBoxFlat.new()
	marker.bg_color = Palette.color(&"sticky")
	marker.set_corner_radius_all(8)
	marker.content_margin_left = 8
	marker.content_margin_right = 8
	label.add_theme_stylebox_override("normal", marker)

## Whether the picture is showing - for checks.
func shows_art() -> bool:
	return _art.visible

func ticks_shown() -> int:
	return _clock.ticks
