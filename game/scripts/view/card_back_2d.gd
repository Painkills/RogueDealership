class_name CardBack2D extends Control
## The face-down side of a card: one fixed, muted color plus one wrench,
## the same for every card regardless of type - a face-down card in the
## draw or discard pile is not a decision you are looking at, so unlike the
## front it has nothing to tell apart. setup() takes no argument for exactly
## that reason: there is nothing per-CardInstance left to show here.

var _background: ColorRect
var _icon: CardTypeIconControl
var _bound := false

func _ready() -> void:
	_bind()
	setup()

func _bind() -> void:
	if _bound:
		return
	_bound = true
	_background = $Background
	_icon = $IconWrap/TypeIcon

func setup() -> void:
	_bind()
	# neutral_2, not accent/action - those read fine as a small front badge but
	# are too saturated to sit behind a large glyph across the WHOLE back of
	# every card in the deck. text_dim on top of it for a soft, low-contrast
	# glyph rather than a loud one.
	_background.color = Palette.color(&"neutral_2")
	_icon.set_type(false, Palette.color(&"text_dim"))
