extends Control
## Fixed-scale bar: fill = appeal / scale, marker = the Line. When a band (not a
## number) is all that is known, draws a flat translucent stripe with the marker
## still shown - matching m2's CLI behaviour of hiding the number, not the bar.
##
## Vertical by default now: the offer panel stands beside the product on the
## table, and a column reads more like "how far up their list this has climbed"
## than a horizontal bar does.

@export var vertical: bool = true

var _appeal: int = 0
var _line: int = 0
var _scale: int = 40
var _band: String = ""

## `full_scale`, not `scale` - Control already has a `scale` property and
## shadowing it here produced a warning on every load.
func set_state(appeal: int, line: int, full_scale: int, band: String) -> void:
	_appeal = appeal
	_line = line
	_scale = max(1, full_scale)
	_band = band
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Palette.color(&"panel_hi"))
	var frac: float = clamp(float(_appeal) / float(_scale), 0.0, 1.0)
	var mark: float = clamp(float(_line) / float(_scale), 0.0, 1.0)

	if vertical:
		if _band != "":
			draw_rect(Rect2(0, 0, size.x, size.y), Color(Palette.color(&"text_dim"), 0.3))
		else:
			# Grows upward, so "climbing toward the Line" is literal.
			var fh: float = size.y * frac
			draw_rect(Rect2(0, size.y - fh, size.x, fh), Palette.color(&"appeal"))
		var my: float = size.y - (size.y * mark)
		draw_line(Vector2(0, my), Vector2(size.x, my), Palette.color(&"text"), 3.0)
		return

	if _band != "":
		draw_rect(Rect2(0, 0, size.x, size.y), Color(Palette.color(&"text_dim"), 0.3))
	else:
		draw_rect(Rect2(0, 0, size.x * frac, size.y), Palette.color(&"appeal"))
	var mx: float = size.x * mark
	draw_line(Vector2(mx, 0), Vector2(mx, size.y), Palette.color(&"text"), 2.0)
