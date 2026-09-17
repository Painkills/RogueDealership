class_name SpeechBubble extends Control
## A customer's own words, popping up ABOVE their card for a few seconds
## instead of living only in the shift log - the log is scrollback you have
## to go read; the table is what you glance at to decide who needs you next,
## and until now nothing there told you a customer had just said something.
##
## Rendered by build_speech_bubble_scene.gd into its own small SubViewport,
## used as the texture for a billboard plane customer_card_3d.tscn positions
## above CardMesh (see customer_card_3d.gd's _bubble_material) - a texture
## baked onto the card's OWN mesh can never draw outside that mesh's edges,
## so floating clear of the card at all needed a second, smaller mesh of its
## own rather than a row on the card's face.
const SHOW_SECONDS := 6.0
## The tail: a small triangle under the panel, pointing down at whoever said
## it - one draw call, not a shape worth a whole extra node.
const TAIL_WIDTH := 32.0
const TAIL_HEIGHT := 22.0

@onready var _panel: PanelContainer = $Panel
@onready var _label: Label = $Panel/Label
@onready var _timer: Timer = $HideTimer

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_timer.one_shot = true
	_timer.timeout.connect(func(): visible = false)
	visible = false
	queue_redraw()

func say(text: String) -> void:
	if text == "":
		return
	_label.text = text
	visible = true
	_timer.start(SHOW_SECONDS)

func _draw() -> void:
	var tail_top: float = _panel.position.y + _panel.size.y
	var cx: float = size.x / 2.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - TAIL_WIDTH / 2.0, tail_top),
		Vector2(cx + TAIL_WIDTH / 2.0, tail_top),
		Vector2(cx, tail_top + TAIL_HEIGHT),
	]), Palette.color(&"panel_hi"))
