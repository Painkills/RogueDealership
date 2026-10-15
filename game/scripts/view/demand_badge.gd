class_name DemandBadge extends Control
## The countdown on a customer's incoming action: a clock face with the ticks left
## in it, big, at the left end of the red banner across their folder. Pops and
## flashes when a new action comes up, so it pulls the eye from across the floor.

const NUMERAL := 34

var _ticks := -1

## Ticks left, or -1 for none (hidden).
func show_ticks(n: int) -> void:
	_ticks = n
	visible = n >= 0
	queue_redraw()

func ticks() -> int:
	return _ticks if visible else -1

func _draw() -> void:
	if _ticks < 0:
		return
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5 - 2.0
	draw_circle(c, r, Palette.color(&"panel"))
	draw_arc(c, r, 0.0, TAU, 40, Palette.color(&"ink"), 4.0, true)
	# Two small ticks at the top, like a stopwatch's crown.
	draw_line(c + Vector2(-6, -r - 2), c + Vector2(6, -r - 2), Palette.color(&"ink"), 5.0, true)
	var font := get_theme_default_font()
	var text := str(_ticks)
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, NUMERAL).x
	draw_string(font, Vector2(c.x - w * 0.5, c.y + NUMERAL * 0.36), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, NUMERAL, Palette.color(&"alert"))
