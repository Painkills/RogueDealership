class_name TickClock extends Control
## A card's tick cost on a little stopwatch - a crown, a face with its hour marks,
## and the number in the middle.

var ticks := 1
## Marked in highlighter yellow - what an upgrade changes (CardFront.highlight_changes()).
var highlighted := false

func show_ticks(n: int) -> void:
	ticks = n
	queue_redraw()

func _draw() -> void:
	var ink := Palette.color(&"neutral_1")
	var c := size * 0.5 + Vector2(0, 3)
	var r := minf(size.x, size.y) * 0.5 - 6.0
	if highlighted:
		draw_circle(c, r + 10.0, Palette.color(&"sticky"))
	draw_rect(Rect2(c.x - 7, c.y - r - 9, 14, 7), ink)
	# Marked, the whole face is the highlighter's yellow - a cost that changed is
	# the one thing on the card you must not miss.
	draw_circle(c, r, Palette.color(&"sticky") if highlighted else Palette.color(&"panel"))
	draw_arc(c, r, 0.0, TAU, 48, ink, 5.0, true)
	for k in range(12):
		var a := TAU * k / 12.0
		var d := Vector2(cos(a), sin(a))
		draw_line(c + d * (r - 4.0), c + d * (r - (9.0 if k % 3 == 0 else 6.0)), ink, 2.0, true)
	var font := get_theme_default_font()
	var text := str(ticks)
	var fs := int(r * 1.15)
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, Vector2(c.x - w * 0.5, c.y + fs * 0.36), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
