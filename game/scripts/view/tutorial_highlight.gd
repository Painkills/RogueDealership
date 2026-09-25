class_name TutorialHighlight extends Control
## A pulsing frame around whatever the tutorial is talking about right now -
## a card, a pile, the clock, a button. Drawn over everything and blocking
## nothing: the thing it frames is the thing you are meant to click.
##
## Yellow like a highlighter, with a dark rule outside it so it still reads
## over the cream paper most of the game is printed on.

const WIDTH := 6.0
const PAD := 8.0
const PULSE_HZ := 1.4

var _rects: Array[Rect2] = []
var _t := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_rects(rects: Array[Rect2]) -> void:
	_rects = rects
	queue_redraw()

func rects() -> Array[Rect2]:
	return _rects

func _process(delta: float) -> void:
	_t += delta
	if not _rects.is_empty():
		queue_redraw()

func _draw() -> void:
	var glow := 0.55 + 0.45 * (0.5 + 0.5 * sin(_t * TAU * PULSE_HZ))
	var ink := Color(Palette.color(&"neutral_1"), 0.7 * glow)
	var marker := Color(Palette.color(&"sticky"), glow)
	for r in _rects:
		if r.size.x <= 0.0 or r.size.y <= 0.0:
			continue
		var frame := r.grow(PAD)
		draw_rect(frame.grow(WIDTH * 0.5 + 1.5), ink, false, 3.0)
		draw_rect(frame, marker, false, WIDTH)
