class_name CardBack2D extends Control
## The face-down side of a card: a solid color plus one big car or wrench,
## the same pairing (and the same CardTypeIcon glyphs) the front's kind
## badge uses. Unlike the front, nothing here changes per CardInstance
## beyond which of the two types it is - there is no name, cost, or margin
## to keep live - so setup() takes a bare bool rather than a CardInstance.

var _background: ColorRect
var _icon: CardTypeIconControl
var _bound := false

func _ready() -> void:
	_bind()

func _bind() -> void:
	if _bound:
		return
	_bound = true
	_background = $Background
	_icon = $IconWrap/TypeIcon

func set_type(is_product: bool) -> void:
	_bind()
	_background.color = Palette.color(&"accent") if is_product else Palette.color(&"action")
	# Dark against either accent or action - both read as a mid-bright color,
	# so one fixed dark glyph color contrasts against both rather than
	# needing its own per-type pairing.
	_icon.set_type(is_product, Palette.color(&"bg"))
