class_name CardBack2D extends Control
## The face-down side of a card: the dealership's own card stock - navy, a
## brass rule inset from the edge, and one brass car - the same for every card
## regardless of type. A face-down card in the draw or discard pile is not a
## decision you are looking at, so unlike the front it has nothing to tell
## apart. setup() takes no argument for exactly that reason: there is nothing
## per-CardInstance left to show here.

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
	# Navy stock with brass on it, the one pairing in the office that says
	# "ours" - and dark, so a face-down pile reads at a glance as the opposite
	# of the cream faces you are actually meant to be reading.
	_background.color = Palette.color(&"ink")
	_icon.set_type(true, Palette.color(&"brass"))
