class_name CooldownPie extends Control
## How long a menu product has left to rest (Shift.board_cooldown_left): a pie
## that empties clockwise from twelve o'clock as the ticks pass, the ticks left
## in its middle.

var left := 0
var total := 1

func show_rest(p_left: int, p_total: int) -> void:
	left = p_left
	total = maxi(1, p_total)
	queue_redraw()

## The share of the rest still to go, 0..1.
func share() -> float:
	return clampf(float(left) / float(total), 0.0, 1.0)

func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5 - 3.0
	draw_circle(c, r, Palette.color(&"panel"))
	var wedge := PackedVector2Array([c])
	var steps := 32
	var sweep := TAU * share()
	for i in range(steps + 1):
		var a := -PI * 0.5 + sweep * float(i) / float(steps)
		wedge.append(c + Vector2(cos(a), sin(a)) * r)
	if share() > 0.0:
		draw_colored_polygon(wedge, Palette.color(&"text_dim"))
	draw_arc(c, r, 0.0, TAU, 48, Palette.color(&"neutral_1"), 3.0, true)
	var font := get_theme_default_font()
	if font == null or left <= 0:
		return
	var text := str(left)
	var fs := int(r * 0.95)
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var at := Vector2(c.x - w * 0.5, c.y + fs * 0.36)
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6,
		Palette.color(&"panel"))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Palette.color(&"neutral_1"))
