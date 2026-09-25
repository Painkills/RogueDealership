class_name CalendarDay extends Control
## One day on the shift picker's week view: the hour lines, and whatever shift
## sits on that day, placed by the hours it runs - the way a calendar app lays
## out its week. The same class draws the time gutter down the left edge, with
## the hours written in instead of a day's events.
##
## Events are anchored across the column's full width and placed vertically by
## the hour, so where they go never waits on a container's deferred layout.

const FIRST_HOUR := 8
const LAST_HOUR := 22
const HOUR_PX := 56.0

## Tints the column the way a calendar marks today.
var today := false
## Draw the hours' names instead of an empty day - the gutter.
var gutter := false

func _ready() -> void:
	custom_minimum_size.y = (LAST_HOUR - FIRST_HOUR) * HOUR_PX
	mouse_filter = Control.MOUSE_FILTER_PASS

## Puts `block` on this day from `start` to `end` o'clock.
func place(block: Control, start: float, end: float) -> void:
	add_child(block)
	block.anchor_left = 0.0
	block.anchor_right = 1.0
	block.offset_left = 6.0
	block.offset_right = -8.0
	block.offset_top = (start - FIRST_HOUR) * HOUR_PX + 2.0
	block.offset_bottom = (end - FIRST_HOUR) * HOUR_PX - 2.0

static func hour_label(h: int) -> String:
	var shown := h % 12
	return "%d %s" % [12 if shown == 0 else shown, "AM" if h < 12 else "PM"]

func _draw() -> void:
	var rule := Palette.color(&"neutral_2")
	if gutter:
		var font := get_theme_default_font()
		for h in range(FIRST_HOUR, LAST_HOUR + 1):
			var y := (h - FIRST_HOUR) * HOUR_PX
			var text := hour_label(h)
			var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
			draw_string(font, Vector2(size.x - w - 12.0, y + 6.0), text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.color(&"text_dim"))
		return
	if today:
		draw_rect(Rect2(Vector2.ZERO, size), Color(Palette.color(&"primary"), 0.05))
	for h in range(LAST_HOUR - FIRST_HOUR + 1):
		var y := h * HOUR_PX
		draw_line(Vector2(0, y), Vector2(size.x, y), rule, 1.0)
	draw_line(Vector2.ZERO, Vector2(0, size.y), rule, 1.0)
