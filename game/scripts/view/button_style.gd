class_name ButtonStyle extends RefCounted
## Every button in the showroom, in two kinds: FILLED in a colour for the thing
## you are meant to press (OFFER in the house blue, CLOSE in red), and OUTLINED
## for everything else. Rounded, flat, a soft shadow - the look of an app, not
## of a form.
##
## One definition, used twice: the project theme (tools/build_theme.gd) gives
## every Button the neutral outline, and a builder that wants a particular one
## re-dresses it with filled() or outlined() rather than restating it.

const RADIUS := 10

static func box(fill: Color, edge: Color, width: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = edge
	s.set_border_width_all(width)
	s.set_corner_radius_all(RADIUS)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	s.shadow_color = Color(0, 0, 0, 0.14)
	s.shadow_size = 4
	s.shadow_offset = Vector2(0, 2)
	return s

## Solid `color` with white words - lighter under the pointer, darker pressed.
static func filled(b: Button, color: Color) -> void:
	b.add_theme_stylebox_override("normal", box(color, color, 0))
	b.add_theme_stylebox_override("hover", box(color.lightened(0.12), color, 0))
	b.add_theme_stylebox_override("pressed", box(color.darkened(0.18), color, 0))
	b.add_theme_stylebox_override("hover_pressed", box(color.darkened(0.12), color, 0))
	for item in ["font_color", "font_hover_color", "font_focus_color",
			"font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(item, Palette.color(&"paper"))

## A filled button that has to be pressed NOW: the same colour, ringed in the
## highlighter yellow the tutorial frames things in, and glowing. It used to
## shout by being tinted red, back when buttons were white - on a red button
## that tinted the word CLOSE red on red, exactly when it most needed reading.
## `on` false dresses it back to plain filled().
static func urgent(b: Button, color: Color, on: bool) -> void:
	filled(b, color)
	if not on:
		return
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		var s := b.get_theme_stylebox(state) as StyleBoxFlat
		s.border_color = Palette.color(&"sticky")
		s.set_border_width_all(4)
		s.shadow_color = Color(color, 0.6)
		s.shadow_size = 14
		s.shadow_offset = Vector2.ZERO

## White with a `color` border and `color` words - and filled in `color` while
## pressed, so a press still reads as a press.
static func outlined(b: Button, color: Color) -> void:
	var white := Palette.color(&"paper")
	b.add_theme_stylebox_override("normal", box(white, color, 2))
	b.add_theme_stylebox_override("hover", box(white.lerp(color, 0.08), color, 2))
	b.add_theme_stylebox_override("pressed", box(color, color, 2))
	b.add_theme_stylebox_override("hover_pressed", box(color.lightened(0.08), color, 2))
	for item in ["font_color", "font_hover_color", "font_focus_color"]:
		b.add_theme_color_override(item, color)
	for item in ["font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(item, white)
