class_name ArchetypeIcon extends RefCounted
## The little picture on an archetype's folder - one glyph per kind of customer,
## so who sat down reads before their name does.
##
## Drawn, not imported, like CategoryIcon: the project has no image assets, and a
## glyph built from a few filled shapes survives the downscale a folder gets on
## the carousel's side seats (about a third of its size) where a fine line would
## turn to a smudge. Every glyph is laid out on a unit square, so one number
## here moves one part of one picture, and each comes with its own tile colour
## and ink - an archetype names its glyph in its data (CustomerArchetype.icon).
##
## tools/render_archetype_icons.gd draws all of them to a PNG to look at.

## The glyph names, in the order they are shown on the contact sheet.
const NAMES: Array[StringName] = [&"mug", &"family", &"hawk", &"phone", &"bubble",
	&"tire", &"check", &"magnifier", &"stopwatch", &"chip", &"whale"]

## name -> {tile, ink, accent, light}: the tile behind it, the glyph's main colour,
## its second colour, and the pale that shows through it (a highlight, an eye).
const LOOKS := {
	&"mug": {"tile": "f6e7d3", "ink": "7a4a28", "accent": "d9a066", "light": "fff6ea"},
	&"family": {"tile": "dff1e5", "ink": "2f7d57", "accent": "f0a24f", "light": "f4fbf6"},
	&"hawk": {"tile": "ebe3d6", "ink": "5e3b1e", "accent": "e0a82e", "light": "fffaf0"},
	&"phone": {"tile": "fde3ec", "ink": "2b2d42", "accent": "ef476f", "light": "fff5f8"},
	&"bubble": {"tile": "fde9da", "ink": "d4452a", "accent": "ffffff", "light": "fff2ea"},
	&"tire": {"tile": "e5e8ed", "ink": "2a2e36", "accent": "ee6b1d", "light": "c9d0da"},
	&"check": {"tile": "e2f4e6", "ink": "2f9e44", "accent": "ffffff", "light": "f2fbf4"},
	&"magnifier": {"tile": "e4edfa", "ink": "3659d6", "accent": "e9830c", "light": "f4f8ff"},
	&"stopwatch": {"tile": "fff2d2", "ink": "36373d", "accent": "f08a00", "light": "fffaf0"},
	&"chip": {"tile": "dff3f5", "ink": "1b4d5a", "accent": "22b8cf", "light": "f1fbfc"},
	&"whale": {"tile": "e1ecf8", "ink": "1f3b63", "accent": "8fbdf0", "light": "f5f9ff"},
}

static func has(icon: StringName) -> bool:
	return LOOKS.has(icon)

## The tile a glyph sits on.
static func tile_color(icon: StringName) -> Color:
	return Color(String(LOOKS[icon]["tile"])) if has(icon) else Palette.color(&"photo_bg")

## Draws `icon` into `rect` (the whole tile - the glyph is inset to leave a
## margin). Nothing is drawn for a name nobody has a glyph for.
static func draw(ci: CanvasItem, rect: Rect2, icon: StringName) -> void:
	if not has(icon):
		return
	var look: Dictionary = LOOKS[icon]
	var ink := Color(String(look["ink"]))
	var accent := Color(String(look["accent"]))
	var light := Color(String(look["light"]))
	var side := minf(rect.size.x, rect.size.y) * 0.84
	var g := Rect2(rect.position + (rect.size - Vector2(side, side)) * 0.5, Vector2(side, side))
	match icon:
		&"mug": _mug(ci, g, ink, accent, light)
		&"family": _family(ci, g, ink, accent, light)
		&"hawk": _hawk(ci, g, ink, accent, light)
		&"phone": _phone(ci, g, ink, accent, light)
		&"bubble": _bubble(ci, g, ink, accent)
		&"tire": _tire(ci, g, ink, accent, light)
		&"check": _check(ci, g, ink, accent)
		&"magnifier": _magnifier(ci, g, ink, accent, light)
		&"stopwatch": _stopwatch(ci, g, ink, accent, light)
		&"chip": _chip(ci, g, ink, accent, light)
		&"whale": _whale(ci, g, ink, accent, light)

# ---------------------------------------------------------------- helpers
static func _p(g: Rect2, x: float, y: float) -> Vector2:
	return g.position + Vector2(x, y) * g.size

static func _len(g: Rect2, v: float) -> float:
	return v * g.size.x

static func _poly(ci: CanvasItem, g: Rect2, pts: Array, color: Color) -> void:
	var out := PackedVector2Array()
	for pt in pts:
		out.append(_p(g, pt.x, pt.y))
	ci.draw_colored_polygon(out, color)

static func _circle(ci: CanvasItem, g: Rect2, x: float, y: float, r: float, color: Color) -> void:
	ci.draw_circle(_p(g, x, y), _len(g, r), color, true, -1.0, true)

static func _line(ci: CanvasItem, g: Rect2, a: Vector2, b: Vector2, w: float, color: Color) -> void:
	ci.draw_line(_p(g, a.x, a.y), _p(g, b.x, b.y), color, _len(g, w), true)
	# Round ends, so a stroke reads as a shape and not a ruled line.
	ci.draw_circle(_p(g, a.x, a.y), _len(g, w) * 0.5, color, true, -1.0, true)
	ci.draw_circle(_p(g, b.x, b.y), _len(g, w) * 0.5, color, true, -1.0, true)

static func _stroke(ci: CanvasItem, g: Rect2, pts: Array, w: float, color: Color) -> void:
	for i in range(pts.size() - 1):
		_line(ci, g, pts[i], pts[i + 1], w, color)

static func _arc(ci: CanvasItem, g: Rect2, x: float, y: float, r: float, from: float, to: float,
		w: float, color: Color) -> void:
	ci.draw_arc(_p(g, x, y), _len(g, r), from, to, 28, color, _len(g, w), true)

static func _rrect(ci: CanvasItem, g: Rect2, x0: float, y0: float, x1: float, y1: float,
		radius: float, color: Color) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(maxi(1, roundi(_len(g, radius))))
	box.anti_aliasing = true
	ci.draw_style_box(box, Rect2(_p(g, x0, y0), Vector2(x1 - x0, y1 - y0) * g.size))

## Points along a circle's arc, in unit coordinates - for a polygon with a curve.
static func _arc_points(cx: float, cy: float, r: float, from: float, to: float, steps: int = 14) -> Array:
	var out := []
	for i in range(steps + 1):
		var a := from + (to - from) * float(i) / float(steps)
		out.append(Vector2(cx + cos(a) * r, cy + sin(a) * r))
	return out

# ----------------------------------------------------------------- glyphs
## Easygoing: a mug, steaming. Nothing here is in a hurry.
static func _mug(ci: CanvasItem, g: Rect2, ink: Color, accent: Color, light: Color) -> void:
	# Handle behind the cup.
	_arc(ci, g, 0.72, 0.56, 0.13, -PI * 0.5, PI * 0.5, 0.07, ink)
	_poly(ci, g, [Vector2(0.18, 0.38), Vector2(0.72, 0.38), Vector2(0.67, 0.74),
		Vector2(0.60, 0.80), Vector2(0.30, 0.80), Vector2(0.23, 0.74)], ink)
	# The coffee, and the light on the rim.
	_poly(ci, g, [Vector2(0.21, 0.42), Vector2(0.69, 0.42), Vector2(0.675, 0.50),
		Vector2(0.215, 0.50)], accent)
	_rrect(ci, g, 0.28, 0.58, 0.34, 0.72, 0.03, light)
	# The saucer.
	_rrect(ci, g, 0.10, 0.82, 0.80, 0.90, 0.04, accent)
	# Steam, in two lazy curves.
	for x in [0.35, 0.53]:
		var pts := []
		for i in range(9):
			var t := float(i) / 8.0
			pts.append(Vector2(x + sin(t * PI * 2.0) * 0.045, 0.30 - t * 0.22))
		_stroke(ci, g, pts, 0.055, accent)

## Family First: two grown-ups and a child between them.
static func _family(ci: CanvasItem, g: Rect2, ink: Color, accent: Color, light: Color) -> void:
	for side in [0.25, 0.75]:
		_circle(ci, g, side, 0.22, 0.10, ink)
		# Shoulders, then a body that narrows to the waist and a pair of legs.
		_poly(ci, g, [Vector2(side - 0.08, 0.35), Vector2(side + 0.08, 0.35),
			Vector2(side + 0.15, 0.42), Vector2(side + 0.14, 0.64),
			Vector2(side + 0.10, 0.64), Vector2(side + 0.10, 0.88),
			Vector2(side + 0.02, 0.88), Vector2(side + 0.02, 0.68),
			Vector2(side - 0.02, 0.68), Vector2(side - 0.02, 0.88),
			Vector2(side - 0.10, 0.88), Vector2(side - 0.10, 0.64),
			Vector2(side - 0.14, 0.64), Vector2(side - 0.15, 0.42)], ink)
	# The child, in front, outlined in the tile's pale so it stays apart.
	for pass_i in range(2):
		var grow := 0.025 if pass_i == 0 else 0.0
		var col := light if pass_i == 0 else accent
		_circle(ci, g, 0.5, 0.50, 0.085 + grow, col)
		_poly(ci, g, [Vector2(0.39 - grow, 0.58), Vector2(0.61 + grow, 0.58),
			Vector2(0.62 + grow, 0.74), Vector2(0.58 + grow, 0.74),
			Vector2(0.58 + grow, 0.88 + grow), Vector2(0.52, 0.88 + grow),
			Vector2(0.52, 0.76), Vector2(0.48, 0.76), Vector2(0.48, 0.88 + grow),
			Vector2(0.42 - grow, 0.88 + grow), Vector2(0.42 - grow, 0.74),
			Vector2(0.38 - grow, 0.74)], col)

## Budget Hawk: a hawk's head in profile, brow down and beak hooked.
static func _hawk(ci: CanvasItem, g: Rect2, ink: Color, accent: Color, light: Color) -> void:
	_poly(ci, g, [Vector2(0.30, 0.90), Vector2(0.14, 0.62), Vector2(0.16, 0.42),
		Vector2(0.26, 0.24), Vector2(0.44, 0.12), Vector2(0.62, 0.15),
		Vector2(0.72, 0.28), Vector2(0.84, 0.34), Vector2(0.92, 0.48),
		Vector2(0.90, 0.64), Vector2(0.84, 0.68), Vector2(0.82, 0.58),
		Vector2(0.70, 0.52), Vector2(0.64, 0.62), Vector2(0.68, 0.76),
		Vector2(0.78, 0.90)], ink)
	# The beak, in the other colour: the part that haggles.
	_poly(ci, g, [Vector2(0.70, 0.28), Vector2(0.84, 0.34), Vector2(0.92, 0.48),
		Vector2(0.90, 0.64), Vector2(0.84, 0.68), Vector2(0.82, 0.58),
		Vector2(0.70, 0.52)], accent)
	# The eye, under a heavy brow.
	_circle(ci, g, 0.55, 0.36, 0.075, light)
	_circle(ci, g, 0.575, 0.37, 0.035, ink)
	_poly(ci, g, [Vector2(0.40, 0.25), Vector2(0.70, 0.30), Vector2(0.70, 0.36),
		Vector2(0.44, 0.31)], ink)
	# Feathers on the chest.
	_stroke(ci, g, [Vector2(0.32, 0.66), Vector2(0.40, 0.78)], 0.045, accent)
	_stroke(ci, g, [Vector2(0.44, 0.62), Vector2(0.52, 0.76)], 0.045, accent)

## Influencer: a phone, filming - and the heart it is after.
static func _phone(ci: CanvasItem, g: Rect2, ink: Color, accent: Color, light: Color) -> void:
	_rrect(ci, g, 0.27, 0.08, 0.73, 0.92, 0.07, ink)
	_rrect(ci, g, 0.32, 0.17, 0.68, 0.78, 0.03, light)
	# The heart: two lobes and a point.
	_circle(ci, g, 0.455, 0.40, 0.065, accent)
	_circle(ci, g, 0.545, 0.40, 0.065, accent)
	_poly(ci, g, [Vector2(0.395, 0.43), Vector2(0.605, 0.43), Vector2(0.5, 0.58)], accent)
	# A record light, and the button under the screen.
	_circle(ci, g, 0.40, 0.25, 0.022, accent)
	_circle(ci, g, 0.5, 0.855, 0.03, light)

## The Karen: a speech bubble, and the one thing it says.
static func _bubble(ci: CanvasItem, g: Rect2, ink: Color, accent: Color) -> void:
	_rrect(ci, g, 0.10, 0.12, 0.90, 0.68, 0.12, ink)
	_poly(ci, g, [Vector2(0.24, 0.60), Vector2(0.50, 0.60), Vector2(0.22, 0.88)], ink)
	_rrect(ci, g, 0.455, 0.22, 0.545, 0.46, 0.04, accent)
	_circle(ci, g, 0.5, 0.56, 0.05, accent)

## Tire Kicker: a tire, and the dent of a boot.
static func _tire(ci: CanvasItem, g: Rect2, ink: Color, accent: Color, light: Color) -> void:
	var c := Vector2(0.44, 0.58)
	_circle(ci, g, c.x, c.y, 0.37, ink)
	# The groove round the tread, then the rim, and the lug nuts on it.
	_arc(ci, g, c.x, c.y, 0.305, 0.0, TAU, 0.035, light)
	_circle(ci, g, c.x, c.y, 0.235, light)
	_circle(ci, g, c.x, c.y, 0.205, ink)
	_circle(ci, g, c.x, c.y, 0.19, light)
	_circle(ci, g, c.x, c.y, 0.06, ink)
	for i in range(5):
		var a := TAU * float(i) / 5.0 - PI * 0.5
		_circle(ci, g, c.x + cos(a) * 0.12, c.y + sin(a) * 0.12, 0.024, ink)
	# The kick: three lines off the point it landed.
	_stroke(ci, g, [Vector2(0.80, 0.30), Vector2(0.93, 0.17)], 0.05, accent)
	_stroke(ci, g, [Vector2(0.84, 0.40), Vector2(0.98, 0.38)], 0.05, accent)
	_stroke(ci, g, [Vector2(0.72, 0.22), Vector2(0.76, 0.08)], 0.05, accent)

## Lay-Down Larry: yes. A tick in a badge.
static func _check(ci: CanvasItem, g: Rect2, ink: Color, accent: Color) -> void:
	_circle(ci, g, 0.5, 0.5, 0.43, ink)
	_stroke(ci, g, [Vector2(0.27, 0.52), Vector2(0.44, 0.69), Vector2(0.75, 0.33)], 0.12, accent)

## The Skeptic: a magnifying glass over a question.
static func _magnifier(ci: CanvasItem, g: Rect2, ink: Color, accent: Color, light: Color) -> void:
	_line(ci, g, Vector2(0.64, 0.64), Vector2(0.86, 0.86), 0.13, accent)
	_circle(ci, g, 0.42, 0.42, 0.34, ink)
	_circle(ci, g, 0.42, 0.42, 0.26, light)
	# The question: a hook, a stem, a dot.
	_arc(ci, g, 0.42, 0.34, 0.08, -PI * 0.95, PI * 0.5, 0.06, ink)
	_line(ci, g, Vector2(0.42, 0.42), Vector2(0.42, 0.47), 0.06, ink)
	_circle(ci, g, 0.42, 0.56, 0.035, ink)

## Speedster: a stopwatch, a quarter of a minute gone.
static func _stopwatch(ci: CanvasItem, g: Rect2, ink: Color, accent: Color, light: Color) -> void:
	_rrect(ci, g, 0.42, 0.06, 0.58, 0.18, 0.03, ink)
	_line(ci, g, Vector2(0.76, 0.26), Vector2(0.84, 0.18), 0.075, ink)
	_circle(ci, g, 0.5, 0.56, 0.36, ink)
	_circle(ci, g, 0.5, 0.56, 0.29, light)
	# The time that has gone, as a wedge.
	var wedge: Array = [Vector2(0.5, 0.56)]
	wedge.append_array(_arc_points(0.5, 0.56, 0.26, -PI * 0.5, 0.0, 12))
	_poly(ci, g, wedge, accent)
	_line(ci, g, Vector2(0.5, 0.56), Vector2(0.5, 0.33), 0.045, ink)
	_circle(ci, g, 0.5, 0.56, 0.04, ink)

## Tech Enthusiast: a chip, pins out on every side.
static func _chip(ci: CanvasItem, g: Rect2, ink: Color, accent: Color, light: Color) -> void:
	for t in [0.34, 0.5, 0.66]:
		_rrect(ci, g, t - 0.03, 0.10, t + 0.03, 0.30, 0.01, accent)
		_rrect(ci, g, t - 0.03, 0.70, t + 0.03, 0.90, 0.01, accent)
		_rrect(ci, g, 0.10, t - 0.03, 0.30, t + 0.03, 0.01, accent)
		_rrect(ci, g, 0.70, t - 0.03, 0.90, t + 0.03, 0.01, accent)
	_rrect(ci, g, 0.24, 0.24, 0.76, 0.76, 0.06, ink)
	_rrect(ci, g, 0.36, 0.36, 0.64, 0.64, 0.03, accent)
	_circle(ci, g, 0.30, 0.30, 0.02, light)

## The Whale: a whale, and the spout.
static func _whale(ci: CanvasItem, g: Rect2, ink: Color, accent: Color, light: Color) -> void:
	# Body, nose to the left, tail up on the right.
	var body: Array = [Vector2(0.08, 0.62), Vector2(0.10, 0.50), Vector2(0.20, 0.42),
		Vector2(0.38, 0.38), Vector2(0.58, 0.42), Vector2(0.72, 0.52),
		Vector2(0.80, 0.52), Vector2(0.84, 0.40), Vector2(0.80, 0.28),
		Vector2(0.88, 0.32), Vector2(0.92, 0.22), Vector2(0.96, 0.36),
		Vector2(0.90, 0.54), Vector2(0.80, 0.64), Vector2(0.62, 0.74),
		Vector2(0.38, 0.80), Vector2(0.20, 0.76), Vector2(0.10, 0.70)]
	_poly(ci, g, body, ink)
	# The pale belly.
	_poly(ci, g, [Vector2(0.16, 0.66), Vector2(0.36, 0.72), Vector2(0.58, 0.68),
		Vector2(0.50, 0.76), Vector2(0.36, 0.78), Vector2(0.22, 0.74)], accent)
	_circle(ci, g, 0.22, 0.54, 0.028, light)
	# The spout: a stem and two sprays, and drops.
	_stroke(ci, g, [Vector2(0.38, 0.38), Vector2(0.38, 0.22)], 0.05, accent)
	_stroke(ci, g, [Vector2(0.38, 0.22), Vector2(0.28, 0.12)], 0.05, accent)
	_stroke(ci, g, [Vector2(0.38, 0.22), Vector2(0.48, 0.12)], 0.05, accent)
	_circle(ci, g, 0.24, 0.20, 0.025, accent)
	_circle(ci, g, 0.52, 0.20, 0.025, accent)
