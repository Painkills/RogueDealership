class_name DealershipArt extends Control
## The dealership from the parking lot, in flat shapes: sky, a glass showroom
## with its sign, a pylon, a string of pennants, a few cars on the lot and an
## inflatable tube man doing his best. Drawn, not imported - every colour is
## the palette's, so a repaint of Palette repaints this too.
##
## Behind the title screen. Scales with its own size; the showroom sits right
## of centre so a menu card fits on the left.

## The words on the banner under the showroom's sign.
var banner := "":
	set(v):
		banner = v
		queue_redraw()

var _t := 0.0

const CAR_COLORS := ["dc2626", "2563eb", "e2e6ec", "1b2330", "15803d", "f59e0b"]
const PENNANT_COLORS := ["dc2626", "facc15", "2563eb", "ffffff"]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visibility_changed.connect(func(): set_process(is_visible_in_tree()))
	set_process(is_visible_in_tree())

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	var horizon := h * 0.64

	# --- sky, sun, clouds ----------------------------------------------------
	var top := Color("7cc3f0")
	var low := Color("dff1fb")
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0),
		Vector2(w, horizon), Vector2(0, horizon)]),
		PackedColorArray([top, top, low, low]))
	draw_circle(Vector2(w * 0.9, h * 0.13), h * 0.06, Color("ffe08a"))
	draw_circle(Vector2(w * 0.9, h * 0.13), h * 0.045, Color("ffd34d"))
	for c in [Vector2(0.14, 0.12), Vector2(0.52, 0.08), Vector2(0.74, 0.2)]:
		var drift := fmod(_t * 6.0 + c.x * 900.0, w * 1.2) - w * 0.1
		_cloud(Vector2(drift, h * c.y), h * 0.035)

	# --- ground --------------------------------------------------------------
	draw_rect(Rect2(0, horizon - h * 0.02, w, h * 0.03), Color("6cae5a"))   # grass
	draw_rect(Rect2(0, horizon + h * 0.01, w, h), Color("4b5160"))          # lot
	draw_rect(Rect2(0, horizon + h * 0.01, w, h * 0.025), Color("c9ced6"))  # kerb
	for i in range(14):
		var x := w * 0.02 + i * w * 0.075
		draw_line(Vector2(x, h * 0.80), Vector2(x - w * 0.02, h * 0.97),
			Color(1, 1, 1, 0.75), maxf(2.0, h * 0.004))

	# --- the showroom --------------------------------------------------------
	var bx := w * 0.40
	var bw := w * 0.46
	var roof := h * 0.30
	var base := horizon + h * 0.01
	var body := Rect2(bx, roof, bw, base - roof)
	draw_rect(body, Palette.color(&"paper"))
	# The fascia, with the dealership's name on it.
	var fascia := Rect2(bx - w * 0.01, roof - h * 0.06, bw + w * 0.02, h * 0.075)
	draw_rect(fascia, Palette.color(&"primary"))
	draw_rect(Rect2(fascia.position.x, fascia.end.y - h * 0.008, fascia.size.x, h * 0.008),
		Palette.color(&"brass"))
	_text("ROGUE DEALERSHIP", fascia.get_center() + Vector2(0, h * 0.004),
		int(h * 0.045), Palette.color(&"paper"))
	# Glass: panes with mullions, sky reflected on them.
	var glass := Rect2(bx + bw * 0.04, roof + h * 0.04, bw * 0.92, base - roof - h * 0.04)
	draw_rect(glass, Color("9cc9e8"))
	var panes := 6
	for i in range(panes):
		var px := glass.position.x + glass.size.x * i / panes
		draw_line(Vector2(px, glass.position.y), Vector2(px, glass.end.y),
			Palette.color(&"window_frame"), maxf(3.0, w * 0.003))
		# A diagonal glint per pane.
		draw_line(Vector2(px + glass.size.x / panes * 0.25, glass.position.y + h * 0.02),
			Vector2(px + glass.size.x / panes * 0.55, glass.position.y + h * 0.12),
			Color(1, 1, 1, 0.45), maxf(2.0, w * 0.004))
	draw_rect(glass, Palette.color(&"window_frame"), false, maxf(3.0, w * 0.003))
	# A car on show inside.
	_car(Vector2(glass.position.x + glass.size.x * 0.3, base - h * 0.012), h * 0.11,
		Palette.color(&"stamp"))
	# The door.
	var door := Rect2(glass.position.x + glass.size.x * 0.68, base - h * 0.14,
		glass.size.x * 0.14, h * 0.14)
	draw_rect(door, Color("7fb5dc"))
	draw_rect(door, Palette.color(&"desk_frame"), false, maxf(3.0, w * 0.0025))
	draw_line(Vector2(door.get_center().x, door.position.y), Vector2(door.get_center().x, door.end.y),
		Palette.color(&"desk_frame"), maxf(2.0, w * 0.002))

	# The banner hung under the fascia.
	if banner != "":
		var bh := h * 0.05
		var bwid := bw * 0.62
		var brect := Rect2(bx + (bw - bwid) * 0.5, roof + h * 0.03, bwid, bh)
		draw_rect(brect, Palette.color(&"sticky"))
		draw_rect(brect, Palette.color(&"brass_dark"), false, 2.0)
		_text(banner, brect.get_center() + Vector2(0, h * 0.003), int(h * 0.028),
			Palette.color(&"ink"))

	# --- the pylon sign ------------------------------------------------------
	var px0 := bx + bw + w * 0.035
	draw_rect(Rect2(px0 - w * 0.004, h * 0.2, w * 0.008, base - h * 0.2), Palette.color(&"desk_frame"))
	var pylon := Rect2(px0 - w * 0.045, h * 0.16, w * 0.09, h * 0.14)
	draw_rect(pylon, Palette.color(&"stamp"))
	draw_rect(pylon, Palette.color(&"paper"), false, maxf(3.0, h * 0.004))
	_text("RD", pylon.get_center() + Vector2(0, -h * 0.018), int(h * 0.05), Palette.color(&"paper"))
	_text("0% APR*", pylon.get_center() + Vector2(0, h * 0.035), int(h * 0.022),
		Palette.color(&"sticky"))

	# --- pennants, from a flagpole to the showroom's corner ------------------
	var pole := Vector2(w * 0.372, h * 0.2)
	draw_line(pole, Vector2(pole.x, base), Palette.color(&"desk_frame"), maxf(3.0, w * 0.003))
	draw_circle(pole, maxf(4.0, h * 0.006), Palette.color(&"brass"))
	_pennants(pole, Vector2(bx - w * 0.01, roof - h * 0.06), 5, h)

	# --- the lot -------------------------------------------------------------
	var row_y := h * 0.86
	for i in range(5):
		var cx := w * 0.08 + i * w * 0.19
		_car(Vector2(cx + w * 0.03, row_y + (i % 2) * h * 0.06), h * 0.13,
			Color(CAR_COLORS[i % CAR_COLORS.size()]))
	_tube_man(Vector2(w * 0.955, horizon + h * 0.02), h)

func _cloud(at: Vector2, r: float) -> void:
	var c := Color(1, 1, 1, 0.9)
	draw_circle(at, r, c)
	draw_circle(at + Vector2(r * 0.9, r * 0.2), r * 0.8, c)
	draw_circle(at + Vector2(-r * 0.9, r * 0.25), r * 0.7, c)
	draw_circle(at + Vector2(r * 0.2, -r * 0.5), r * 0.75, c)

## A side-on car, `length` long, its wheels on `ground`.
func _car(ground: Vector2, length: float, color: Color) -> void:
	var l := length * 1.6
	var x := ground.x - l * 0.5
	var wheel := l * 0.09
	var body_top := ground.y - wheel - l * 0.16
	draw_rect(Rect2(x, body_top, l, l * 0.17), color)
	draw_colored_polygon(PackedVector2Array([
		Vector2(x + l * 0.22, body_top), Vector2(x + l * 0.32, body_top - l * 0.13),
		Vector2(x + l * 0.68, body_top - l * 0.13), Vector2(x + l * 0.8, body_top)]), color)
	var glass := Color("cfe6f6")
	draw_colored_polygon(PackedVector2Array([
		Vector2(x + l * 0.27, body_top), Vector2(x + l * 0.34, body_top - l * 0.1),
		Vector2(x + l * 0.49, body_top - l * 0.1), Vector2(x + l * 0.49, body_top)]), glass)
	draw_colored_polygon(PackedVector2Array([
		Vector2(x + l * 0.52, body_top), Vector2(x + l * 0.52, body_top - l * 0.1),
		Vector2(x + l * 0.66, body_top - l * 0.1), Vector2(x + l * 0.74, body_top)]), glass)
	draw_rect(Rect2(x + l * 0.93, body_top + l * 0.03, l * 0.05, l * 0.035), Color("fff3b0"))
	for wx in [x + l * 0.22, x + l * 0.78]:
		draw_circle(Vector2(wx, ground.y - wheel), wheel, Palette.color(&"desk_frame"))
		draw_circle(Vector2(wx, ground.y - wheel), wheel * 0.45, Color("c9ced6"))

## A sagging string of little flags from `a` to `b`, fluttering.
func _pennants(a: Vector2, b: Vector2, count: int, h: float) -> void:
	var pts := PackedVector2Array()
	for i in range(count + 1):
		var f := float(i) / count
		var p := a.lerp(b, f)
		p.y += sin(f * PI) * h * 0.04
		pts.append(p)
	draw_polyline(pts, Palette.color(&"desk_frame"), 2.0)
	var flag := h * 0.028
	for i in range(count):
		var p0 := pts[i]
		var p1 := pts[i + 1]
		var tip := (p0 + p1) * 0.5 + Vector2(sin(_t * 4.0 + i) * flag * 0.15, flag)
		draw_colored_polygon(PackedVector2Array([p0, p1, tip]),
			Color(PENNANT_COLORS[i % PENNANT_COLORS.size()]))

## The inflatable tube man. He never stops.
func _tube_man(feet: Vector2, h: float) -> void:
	var color := Color("f97316")
	var seg := h * 0.035
	var pts := PackedVector2Array([feet])
	var p := feet
	for i in range(6):
		var lean := sin(_t * 3.0 - i * 0.7) * (0.15 + i * 0.07)
		p += Vector2(sin(lean), -cos(lean)) * seg
		pts.append(p)
	draw_rect(Rect2(feet.x - h * 0.02, feet.y - h * 0.01, h * 0.04, h * 0.015),
		Palette.color(&"desk_frame"))
	draw_polyline(pts, color, h * 0.03, true)
	var shoulders := pts[4]
	for side in [-1.0, 1.0]:
		var flap := sin(_t * 5.0 + side) * 0.9
		var arm_end := shoulders + Vector2(side * h * 0.06, -h * 0.02 + flap * h * 0.04)
		draw_line(shoulders, arm_end, color, h * 0.015, true)
	var head := pts[pts.size() - 1]
	draw_circle(head, h * 0.02, color)
	draw_circle(head + Vector2(-h * 0.007, -h * 0.004), h * 0.004, Palette.color(&"ink"))
	draw_circle(head + Vector2(h * 0.007, -h * 0.004), h * 0.004, Palette.color(&"ink"))

func _text(s: String, centre: Vector2, px: int, color: Color) -> void:
	var font := get_theme_default_font()
	var width := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	draw_string(font, centre + Vector2(-width * 0.5, px * 0.35), s,
		HORIZONTAL_ALIGNMENT_LEFT, -1, px, color)
