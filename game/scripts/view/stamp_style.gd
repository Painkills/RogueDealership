class_name StampStyle extends RefCounted
## The rubber stamp every button in the office wears: an inked border with
## rounded corners on a sheet of paper, pressed solid when you stamp it.
##
## One definition, used twice: the project theme (tools/build_theme.gd) gives
## every Button the navy stamp, and a builder that wants one in a particular
## ink - the shift's red CLOSE - re-inks it with ink() rather than restating it.
##
## Paper-filled rather than hollow, because the shift's buttons sit over the
## office's dark wall, and a hollow stamp there would be ink on near-black.

static func box(fill: Color, edge: Color, width: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = edge
	s.set_border_width_all(width)
	s.set_corner_radius_all(6)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	s.shadow_color = Color(0, 0, 0, 0.3)
	s.shadow_size = 3
	s.shadow_offset = Vector2(1, 2)
	return s

## Re-inks one button's stamp: the border and the word in `ink`, on paper, and
## pressed solid in it with the word knocked out in paper.
static func ink(b: Button, ink_color: Color) -> void:
	b.add_theme_stylebox_override("normal", box(Palette.color(&"paper"), ink_color, 3))
	b.add_theme_stylebox_override("hover", box(Palette.color(&"panel_hi"), ink_color, 4))
	b.add_theme_stylebox_override("pressed", box(ink_color, ink_color, 3))
	b.add_theme_stylebox_override("hover_pressed", box(ink_color, ink_color, 4))
	for item in ["font_color", "font_hover_color", "font_focus_color"]:
		b.add_theme_color_override(item, ink_color)
	for item in ["font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(item, Palette.color(&"paper"))
