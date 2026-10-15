class_name ToggleSwitch extends Control
## A slider switch: green with the knob right when on, red with it left when off.
## Click or tap anywhere on it to flip it.

signal toggled(on: bool)

var on := true
## Where the knob is, 0 (off) to 1 (on) - eased between the two.
var _at := 1.0
var _slide: Tween = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(76, 36)

## Sets it without saying so - for what the game already knows.
func set_on(value: bool) -> void:
	on = value
	_at = 1.0 if on else 0.0
	queue_redraw()

func flip() -> void:
	on = not on
	if _slide != null and _slide.is_valid():
		_slide.kill()
	_slide = create_tween()
	_slide.tween_method(func(v: float):
		_at = v
		queue_redraw(), _at, 1.0 if on else 0.0, 0.15)
	toggled.emit(on)

func _gui_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventMouseButton and event.pressed
		and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed)
	if pressed:
		flip()
		accept_event()

func _draw() -> void:
	var h := size.y
	var r := h * 0.5
	var track := Color(Palette.color(&"alert")).lerp(Palette.color(&"patience_ok"), _at)
	draw_circle(Vector2(r, r), r, track)
	draw_circle(Vector2(size.x - r, r), r, track)
	draw_rect(Rect2(r, 0, size.x - h, h), track)
	var font := get_theme_default_font()
	var word := "ON" if on else "OFF"
	var fs := int(h * 0.42)
	var w := font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var x := r * 0.6 if on else size.x - r * 0.6 - w
	draw_string(font, Vector2(x, r + fs * 0.36), word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
		Palette.color(&"panel"))
	var knob := lerpf(r, size.x - r, _at)
	draw_circle(Vector2(knob, r), r - 4.0, Palette.color(&"panel"))
