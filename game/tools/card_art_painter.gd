extends Control
## Draws a placeholder picture for a card - a few flat shapes that say what the
## card is about - for tools/render_card_art.gd to save as its art. Stand-ins
## until real pictures are made; each is replaced by dropping a new image in.

const W := 900
const H := 258

const BG := Color("f7f1e4")
const NAVY := Color("23395b")
const BLUE := Color("3a6ea8")
const ORANGE := Color("e05a2b")
const YELLOW := Color("f2c14e")
const GREEN := Color("5b7a5a")
const SKIN := Color("f2b07a")
const BROWN := Color("6b4a3a")
const WHITE := Color("fffdf8")
const GREY := Color("b9b2a3")
const RED := Color("c8452f")

var id := ""

func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), BG)
	draw_rect(Rect2(0, 222, W, 36), Color("ece3cf"))
	match id:
		"bump": _tag(330, 130, 1.2, ORANGE); _arrow(560, 130, 1.2, GREEN, true)
		"bundle": _gift(330, 150, 0.8, ORANGE); _gift(450, 120, 1.0, BLUE); _gift(570, 150, 0.8, GREEN)
		"checknotes": _person(300, 150, 1.0, NAVY, BROWN); _book(530, 130, 1.2)
		"coffee": _person(300, 150, 1.0, GREEN, BROWN); _cup(540, 150, 1.2)
		"comp": _gift(370, 140, 1.1, ORANGE); _shield(560, 125, 1.0, NAVY, "W")
		"discount": _tag(330, 130, 1.2, GREEN); _arrow(560, 130, 1.2, RED, false)
		"empathize": _person(300, 150, 1.0, GREEN, BROWN); _heart(450, 100, 0.9); _person(600, 150, 1.0, NAVY, NAVY)
		"fearmonger": _cloud(330, 75, 1.0, GREY); _bolt(330, 105, 1.0); _car(590, 175, 0.9, BLUE)
		"framing": _person(270, 150, 1.0, GREEN, BROWN); _bubble(450, 90, 0.9, WHITE); _person(630, 150, 1.0, NAVY, NAVY)
		"goodwill": _heart(380, 120, 1.2); _coins(560, 160, 1.1)
		"hardclose": _person(320, 150, 1.0, NAVY, NAVY); _bubble(520, 90, 1.1, WHITE); _question(520, 90, 1.0)
		"jtt": _target(450, 130, 1.3)
		"keep_it_coming": _arrow(330, 160, 0.8, GREEN, true); _arrow(450, 130, 1.0, GREEN, true); _arrow(570, 100, 1.2, GREEN, true)
		"pad": _tag(380, 130, 1.2, ORANGE); _plus(560, 130, 1.0)
		"servicefee": _document(370, 125, 1.1); _coins(560, 160, 1.0)
		"readroom": _person(320, 150, 1.0, GREEN, BROWN); _magnifier(540, 120, 1.1)
		"rwrt": _bulb(380, 120, 1.1); _bubble(560, 100, 1.0, WHITE)
		"smalltalk": _person(280, 150, 1.0, GREEN, BROWN); _bubble(450, 80, 0.8, WHITE); _person(620, 150, 1.0, NAVY, NAVY)
		"smile": _face(450, 125, 1.3)
		"jazz": _notes(380, 110, 1.2); _speaker(570, 135, 1.0)
		"thinkonit": _person(330, 150, 1.0, GREEN, BROWN); _cloud(530, 90, 0.8, WHITE); _clock(530, 90, 0.6)
		"appearance": _car(430, 170, 1.1, BLUE); _sparkles(640, 80, 1.0); _sparkles(220, 100, 0.7)
		"concierge": _phone(330, 125, 1.1); _car(560, 175, 0.9, BLUE)
		"flex": _calendar(360, 125, 1.1); _coins(570, 160, 1.0)
		"gap": _car(330, 175, 0.9, BLUE); _document(580, 120, 1.0)
		"perf": _mountain(560, 200, 1.2); _car(330, 175, 0.9, ORANGE)
		"ppp": _umbrella(450, 100, 1.2); _coins(450, 185, 0.9)
		"theft": _key(360, 130, 1.2); _shield(580, 125, 1.0, NAVY, "")
		"tlp": _shield(330, 120, 1.1, NAVY, "W"); _car(570, 175, 0.9, BLUE)
		"tvp": _car(360, 175, 0.9, BLUE); _arrow(580, 120, 1.1, GREEN, true)
		"vsc": _wrench(350, 130, 1.2); _car(580, 175, 0.9, BLUE)
		"wap": _shield(330, 120, 1.1, ORANGE, "W"); _person(560, 150, 1.0, NAVY, NAVY)
		_: _car(450, 170, 1.0, BLUE)

# --- motifs -----------------------------------------------------------------

func _poly(points: Array, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array(points), color)

func _car(x: float, y: float, s: float, color: Color) -> void:
	var b := Vector2(x, y)
	_poly([b + Vector2(-150, 20) * s, b + Vector2(-150, -15) * s, b + Vector2(-90, -25) * s,
		b + Vector2(-50, -70) * s, b + Vector2(60, -70) * s, b + Vector2(110, -25) * s,
		b + Vector2(150, -15) * s, b + Vector2(150, 20) * s], color)
	_poly([b + Vector2(-35, -60) * s, b + Vector2(50, -60) * s, b + Vector2(85, -28) * s,
		b + Vector2(-70, -28) * s], Color(WHITE, 0.85))
	for wx: float in [-90.0, 90.0]:
		draw_circle(b + Vector2(wx, 22) * s, 30 * s, NAVY)
		draw_circle(b + Vector2(wx, 22) * s, 13 * s, GREY)

func _person(x: float, y: float, s: float, shirt: Color, hair: Color) -> void:
	_poly([Vector2(x - 60 * s, 222), Vector2(x - 50 * s, y + 10 * s), Vector2(x, y - 5 * s),
		Vector2(x + 50 * s, y + 10 * s), Vector2(x + 60 * s, 222)], shirt)
	draw_circle(Vector2(x, y - 50 * s), 38 * s, SKIN)
	draw_arc(Vector2(x, y - 55 * s), 38 * s, PI, TAU, 24, hair, 22 * s)

func _shield(x: float, y: float, s: float, color: Color, mark: String) -> void:
	_poly([Vector2(x - 60 * s, y - 70 * s), Vector2(x + 60 * s, y - 70 * s),
		Vector2(x + 60 * s, y), Vector2(x, y + 80 * s), Vector2(x - 60 * s, y)], color)
	if mark != "":
		var f := get_theme_default_font()
		var fs := int(80 * s)
		var w := f.get_string_size(mark, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(f, Vector2(x - w / 2, y + 20 * s), mark, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, WHITE)
	else:
		draw_line(Vector2(x - 25 * s, y), Vector2(x - 5 * s, y + 22 * s), WHITE, 10 * s)
		draw_line(Vector2(x - 5 * s, y + 22 * s), Vector2(x + 30 * s, y - 25 * s), WHITE, 10 * s)

func _tag(x: float, y: float, s: float, color: Color) -> void:
	_poly([Vector2(x - 80 * s, y - 45 * s), Vector2(x + 50 * s, y - 45 * s), Vector2(x + 90 * s, y),
		Vector2(x + 50 * s, y + 45 * s), Vector2(x - 80 * s, y + 45 * s)], color)
	draw_circle(Vector2(x + 45 * s, y), 9 * s, BG)
	_text("$", Vector2(x - 25 * s, y), int(64 * s), WHITE)

func _arrow(x: float, y: float, s: float, color: Color, up: bool) -> void:
	var d := -1.0 if up else 1.0
	draw_rect(Rect2(x - 18 * s, y - 50 * s, 36 * s, 100 * s), color)
	_poly([Vector2(x - 50 * s, y + d * 40 * s), Vector2(x + 50 * s, y + d * 40 * s),
		Vector2(x, y + d * 95 * s)], color)

func _gift(x: float, y: float, s: float, color: Color) -> void:
	draw_rect(Rect2(x - 50 * s, y - 40 * s, 100 * s, 80 * s), color)
	draw_rect(Rect2(x - 8 * s, y - 40 * s, 16 * s, 80 * s), YELLOW)
	draw_circle(Vector2(x - 14 * s, y - 48 * s), 12 * s, YELLOW)
	draw_circle(Vector2(x + 14 * s, y - 48 * s), 12 * s, YELLOW)

func _book(x: float, y: float, s: float) -> void:
	draw_rect(Rect2(x - 90 * s, y - 60 * s, 85 * s, 120 * s), BLUE)
	draw_rect(Rect2(x + 5 * s, y - 60 * s, 85 * s, 120 * s), NAVY)
	for k in range(4):
		draw_line(Vector2(x - 75 * s, y - 35 * s + k * 22 * s), Vector2(x - 20 * s, y - 35 * s + k * 22 * s), WHITE, 5 * s)

func _cup(x: float, y: float, s: float) -> void:
	draw_rect(Rect2(x - 45 * s, y - 50 * s, 90 * s, 90 * s), WHITE)
	draw_arc(Vector2(x + 50 * s, y - 5 * s), 22 * s, -PI / 2, PI / 2, 16, WHITE, 10 * s)
	draw_rect(Rect2(x - 45 * s, y - 50 * s, 90 * s, 14 * s), BROWN)
	for k in range(3):
		var sx := x - 25 * s + k * 25 * s
		draw_line(Vector2(sx, y - 65 * s), Vector2(sx + 8 * s, y - 95 * s), GREY, 6 * s)

func _heart(x: float, y: float, s: float) -> void:
	draw_circle(Vector2(x - 25 * s, y - 15 * s), 30 * s, RED)
	draw_circle(Vector2(x + 25 * s, y - 15 * s), 30 * s, RED)
	_poly([Vector2(x - 54 * s, y - 5 * s), Vector2(x + 54 * s, y - 5 * s), Vector2(x, y + 55 * s)], RED)

func _cloud(x: float, y: float, s: float, color: Color) -> void:
	for p: Vector2 in [Vector2(-50, 10), Vector2(0, -15), Vector2(50, 10), Vector2(0, 20)]:
		draw_circle(Vector2(x, y) + p * s, 40 * s, color)

func _bolt(x: float, y: float, s: float) -> void:
	_poly([Vector2(x - 10 * s, y), Vector2(x + 20 * s, y), Vector2(x, y + 35 * s),
		Vector2(x + 25 * s, y + 35 * s), Vector2(x - 20 * s, y + 85 * s), Vector2(x - 5 * s, y + 45 * s),
		Vector2(x - 25 * s, y + 45 * s)], YELLOW)

func _bubble(x: float, y: float, s: float, color: Color) -> void:
	draw_circle(Vector2(x - 35 * s, y), 45 * s, color)
	draw_circle(Vector2(x + 35 * s, y), 45 * s, color)
	draw_rect(Rect2(x - 35 * s, y - 45 * s, 70 * s, 90 * s), color)
	_poly([Vector2(x - 40 * s, y + 35 * s), Vector2(x - 10 * s, y + 40 * s), Vector2(x - 55 * s, y + 70 * s)], color)
	for k in range(3):
		draw_circle(Vector2(x - 30 * s + k * 30 * s, y), 8 * s, NAVY)

func _question(x: float, y: float, s: float) -> void:
	draw_rect(Rect2(x - 70 * s, y - 25 * s, 140 * s, 50 * s), WHITE)
	_text("?", Vector2(x, y), int(80 * s), ORANGE)

func _target(x: float, y: float, s: float) -> void:
	for k in range(4):
		draw_circle(Vector2(x, y), (90 - k * 22) * s, RED if k % 2 == 0 else WHITE)
	draw_line(Vector2(x + 160 * s, y - 70 * s), Vector2(x, y), NAVY, 8 * s)
	_poly([Vector2(x + 150 * s, y - 85 * s), Vector2(x + 185 * s, y - 80 * s), Vector2(x + 165 * s, y - 55 * s)], ORANGE)

func _plus(x: float, y: float, s: float) -> void:
	draw_rect(Rect2(x - 15 * s, y - 55 * s, 30 * s, 110 * s), GREEN)
	draw_rect(Rect2(x - 55 * s, y - 15 * s, 110 * s, 30 * s), GREEN)

func _document(x: float, y: float, s: float) -> void:
	draw_rect(Rect2(x - 60 * s, y - 80 * s, 120 * s, 160 * s), WHITE)
	draw_rect(Rect2(x - 60 * s, y - 80 * s, 120 * s, 160 * s), NAVY, false, 4 * s)
	for k in range(5):
		draw_line(Vector2(x - 40 * s, y - 50 * s + k * 25 * s), Vector2(x + 40 * s, y - 50 * s + k * 25 * s), GREY, 6 * s)

func _coins(x: float, y: float, s: float) -> void:
	for k in range(3):
		var c := Vector2(x - 40 * s + k * 40 * s, y - k * 10 * s)
		draw_circle(c, 32 * s, YELLOW)
		draw_arc(c, 32 * s, 0, TAU, 24, Color("c99a2e"), 4 * s)
		_text("$", c, int(36 * s), Color("8a6516"))

func _magnifier(x: float, y: float, s: float) -> void:
	draw_circle(Vector2(x, y), 50 * s, Color(WHITE, 0.9))
	draw_arc(Vector2(x, y), 50 * s, 0, TAU, 32, NAVY, 12 * s)
	draw_line(Vector2(x + 36 * s, y + 36 * s), Vector2(x + 90 * s, y + 90 * s), NAVY, 18 * s)

func _bulb(x: float, y: float, s: float) -> void:
	draw_circle(Vector2(x, y - 15 * s), 50 * s, YELLOW)
	draw_rect(Rect2(x - 22 * s, y + 30 * s, 44 * s, 35 * s), GREY)
	for a: float in [-2.4, -1.57, -0.7]:
		var d := Vector2(cos(a), sin(a))
		draw_line(Vector2(x, y - 15 * s) + d * 65 * s, Vector2(x, y - 15 * s) + d * 90 * s, YELLOW, 8 * s)

func _face(x: float, y: float, s: float) -> void:
	draw_circle(Vector2(x, y), 85 * s, YELLOW)
	draw_circle(Vector2(x - 30 * s, y - 20 * s), 10 * s, NAVY)
	draw_circle(Vector2(x + 30 * s, y - 20 * s), 10 * s, NAVY)
	draw_arc(Vector2(x, y + 5 * s), 45 * s, 0.3, PI - 0.3, 20, NAVY, 10 * s)

func _notes(x: float, y: float, s: float) -> void:
	for n: Vector2 in [Vector2(-40, 40), Vector2(40, 20)]:
		var c := Vector2(x, y) + n * s
		draw_circle(c, 20 * s, NAVY)
		draw_line(c + Vector2(18, 0) * s, c + Vector2(18, -90) * s, NAVY, 7 * s)
	draw_line(Vector2(x - 22 * s, y - 50 * s), Vector2(x + 58 * s, y - 70 * s), NAVY, 14 * s)

func _speaker(x: float, y: float, s: float) -> void:
	draw_rect(Rect2(x - 55 * s, y - 75 * s, 110 * s, 150 * s), BROWN)
	draw_circle(Vector2(x, y + 25 * s), 32 * s, NAVY)
	draw_circle(Vector2(x, y - 40 * s), 16 * s, NAVY)

func _clock(x: float, y: float, s: float) -> void:
	draw_circle(Vector2(x, y), 50 * s, WHITE)
	draw_arc(Vector2(x, y), 50 * s, 0, TAU, 32, NAVY, 8 * s)
	draw_line(Vector2(x, y), Vector2(x, y - 32 * s), NAVY, 7 * s)
	draw_line(Vector2(x, y), Vector2(x + 24 * s, y + 8 * s), NAVY, 7 * s)

func _sparkles(x: float, y: float, s: float) -> void:
	for a: float in [0.4, 1.2, 2.0]:
		var d := Vector2(cos(a), -sin(a))
		draw_line(Vector2(x, y) + d * 20 * s, Vector2(x, y) + d * 60 * s, YELLOW, 10 * s)

func _phone(x: float, y: float, s: float) -> void:
	draw_rect(Rect2(x - 40 * s, y - 75 * s, 80 * s, 150 * s), NAVY)
	draw_rect(Rect2(x - 30 * s, y - 60 * s, 60 * s, 105 * s), Color("8fb4de"))
	draw_circle(Vector2(x, y + 60 * s), 7 * s, GREY)

func _calendar(x: float, y: float, s: float) -> void:
	draw_rect(Rect2(x - 70 * s, y - 60 * s, 140 * s, 130 * s), WHITE)
	draw_rect(Rect2(x - 70 * s, y - 60 * s, 140 * s, 32 * s), ORANGE)
	for r in range(3):
		for c in range(4):
			draw_rect(Rect2(x - 58 * s + c * 32 * s, y - 18 * s + r * 28 * s, 20 * s, 18 * s),
				GREEN if r == 1 and c == 2 else GREY)

func _mountain(x: float, y: float, s: float) -> void:
	_poly([Vector2(x - 200 * s, y), Vector2(x - 40 * s, y - 150 * s), Vector2(x + 60 * s, y - 60 * s),
		Vector2(x + 120 * s, y - 110 * s), Vector2(x + 240 * s, y)], GREEN)
	_poly([Vector2(x - 70 * s, y - 122 * s), Vector2(x - 40 * s, y - 150 * s), Vector2(x - 12 * s, y - 122 * s)], WHITE)

func _umbrella(x: float, y: float, s: float) -> void:
	_poly([Vector2(x - 120 * s, y), Vector2(x - 85 * s, y - 50 * s), Vector2(x, y - 75 * s),
		Vector2(x + 85 * s, y - 50 * s), Vector2(x + 120 * s, y)], BLUE)
	draw_line(Vector2(x, y), Vector2(x, y + 50 * s), NAVY, 8 * s)

func _key(x: float, y: float, s: float) -> void:
	draw_circle(Vector2(x - 60 * s, y), 40 * s, YELLOW)
	draw_circle(Vector2(x - 60 * s, y), 15 * s, BG)
	draw_rect(Rect2(x - 25 * s, y - 10 * s, 120 * s, 20 * s), YELLOW)
	draw_rect(Rect2(x + 60 * s, y + 10 * s, 15 * s, 25 * s), YELLOW)
	draw_rect(Rect2(x + 30 * s, y + 10 * s, 15 * s, 18 * s), YELLOW)

func _wrench(x: float, y: float, s: float) -> void:
	draw_line(Vector2(x - 80 * s, y + 60 * s), Vector2(x + 50 * s, y - 40 * s), GREY, 26 * s)
	draw_circle(Vector2(x + 60 * s, y - 50 * s), 38 * s, GREY)
	draw_circle(Vector2(x + 78 * s, y - 68 * s), 18 * s, BG)

func _text(t: String, center: Vector2, fs: int, color: Color) -> void:
	var f := get_theme_default_font()
	var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(f, Vector2(center.x - w / 2, center.y + fs * 0.36), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)
