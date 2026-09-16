class_name SpeechBubble extends Control
## A customer's own words, popping up over their card for a few seconds
## instead of living only in the shift log - the log is scrollback you have
## to go read; the table is what you glance at to decide who needs you next,
## and until now nothing there told you a customer had just said something.
##
## Drawn over the top of the name/archetype row rather than given a row of
## its own: the face is already full at 500x700 (see
## build_customer_front_scene.gd), and a bubble that shows for a few seconds
## and then gets out of the way costs nothing permanent to make room for.

const SHOW_SECONDS := 4.0
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
