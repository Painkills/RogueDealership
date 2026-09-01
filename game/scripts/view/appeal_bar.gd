extends Control
## Fixed-scale bar: fill = appeal / scale, marker = line / scale. When a band
## (not a number) is all that's known, draws a flat "?" fill with the marker
## still shown, matching m2's CLI behaviour of hiding the number, not the bar.

var _appeal: int = 0
var _line: int = 0
var _scale: int = 40
var _band: String = ""

func set_state(appeal: int, line: int, scale: int, band: String) -> void:
	_appeal = appeal
	_line = line
	_scale = max(1, scale)
	_band = band
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(Vector2.ZERO, size), Palette.color(&"panel_hi"))
	if _band != "":
		var stripe := Color(Palette.color(&"text_dim"), 0.3)
		draw_rect(Rect2(0, 0, w, h), stripe)
	else:
		var fill_w: float = w * clamp(float(_appeal) / float(_scale), 0.0, 1.0)
		draw_rect(Rect2(0, 0, fill_w, h), Palette.color(&"appeal"))
	var mark_x: float = w * clamp(float(_line) / float(_scale), 0.0, 1.0)
	draw_line(Vector2(mark_x, 0), Vector2(mark_x, h), Palette.color(&"text"), 2.0)
