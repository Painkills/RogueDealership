class_name LingerBadges extends Control
## A small clock and a number for each of your cards still working on a customer:
## how many more ticks it keeps going. Drawn at the folder's top right, right-aligned
## so the soonest to end is nearest the edge.

const ICON := 40.0
const GAP := 8.0
const BETWEEN := 18.0
const NUMERAL := 40
## Past this many, the rest are folded into one "+n".
const MOST := 2

var _turns: Array[int] = []

## Ticks left on each lingering card, any order. Empty clears the badges.
func show_turns(turns: Array[int]) -> void:
	var sorted := turns.duplicate()
	sorted.sort()
	_turns.clear()
	for t in sorted:
		_turns.append(int(t))
	visible = not _turns.is_empty()
	queue_redraw()

## What is drawn, as text - for tests: "3" or "3 5" or "3 5 +1".
func shown_text() -> String:
	var parts: Array[String] = []
	for k in range(mini(_turns.size(), MOST)):
		parts.append(str(_turns[k]))
	if _turns.size() > MOST:
		parts.append("+%d" % (_turns.size() - MOST))
	return " ".join(parts)

func _draw() -> void:
	if _turns.is_empty():
		return
	var font := get_theme_default_font()
	var ink := Palette.color(&"action")
	var x := size.x
	var items: Array[String] = []
	for k in range(mini(_turns.size(), MOST)):
		items.append(str(_turns[k]))
	if _turns.size() > MOST:
		items.append("+%d" % (_turns.size() - MOST))
	# Right to left.
	for k in range(items.size() - 1, -1, -1):
		var text := items[k]
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, NUMERAL).x
		x -= w
		draw_string(font, Vector2(x, size.y * 0.5 + NUMERAL * 0.34), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, NUMERAL, ink)
		if text.begins_with("+"):
			x -= BETWEEN
			continue
		x -= GAP + ICON
		_draw_clock(Vector2(x + ICON * 0.5, size.y * 0.5), ICON * 0.5, ink)
		x -= BETWEEN

func _draw_clock(at: Vector2, radius: float, ink: Color) -> void:
	draw_circle(at, radius, Palette.color(&"paper_shade"))
	draw_arc(at, radius, 0.0, TAU, 32, ink, 4.0, true)
	draw_line(at, at + Vector2(0, -radius * 0.62), ink, 4.0, true)
	draw_line(at, at + Vector2(radius * 0.46, radius * 0.18), ink, 4.0, true)
