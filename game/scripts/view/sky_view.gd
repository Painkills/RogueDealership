class_name SkyView extends Control
## What the office windows look out on: the sky at the time of day the shift is
## being worked, over the town's rooftops. Drawn rather than painted - a
## gradient, the sun or the moon, clouds or stars, and a skyline - into the one
## texture every pane of the window shows a slice of (see OfficeWindows).
##
## An illustration, not UI, so its colours are its own rather than Palette
## roles: a sky has no business being on-brand.
##
## Laid out in fractions of its own size, so the texture can be any resolution.
## The windows run up past the top of both framings, so nothing worth seeing is
## in the top fifth. The low morning sun and the moon keep to the right-hand
## pane, where a desk shows the most sky; the midday sun stands high in the
## middle one, over the head of the customer in front of you, the way noon
## would put it.

const LOOKS := {
	&"morning": {
		"top": Color("86b9ec"), "horizon": Color("ffd2a1"),
		"body": Color("ffb65c"), "halo": Color("ffd9a8"),
		"body_at": Vector2(0.9, 0.68), "body_r": 0.06, "moon": false,
		"clouds": Color(1.0, 0.95, 0.9, 0.85), "stars": false,
		"skyline": Color("71809c"), "lit": false,
	},
	&"midday": {
		"top": Color("2e7ed6"), "horizon": Color("aad8ff"),
		"body": Color("fffbe8"), "halo": Color("fff4b8"),
		"body_at": Vector2(0.5, 0.3), "body_r": 0.045, "moon": false,
		"clouds": Color(1.0, 1.0, 1.0, 0.92), "stars": false,
		"skyline": Color("56688a"), "lit": false,
	},
	&"night": {
		"top": Color("050a1c"), "horizon": Color("2a2a5e"),
		"body": Color("f2eed8"), "halo": Color(0.95, 0.93, 0.85, 0.35),
		"body_at": Vector2(0.86, 0.4), "body_r": 0.042, "moon": true,
		"clouds": Color(0, 0, 0, 0), "stars": true,
		"skyline": Color("0b0e19"), "lit": true,
	},
}
## The same town every time: the skyline, the stars and the lit windows are
## scattered from this seed rather than re-rolled per draw.
const SEED := 20260926
## Where the rooftops start, as a fraction of the height from the top.
const SKYLINE_TOP := 0.74

var time_of_day: StringName = &"midday":
	set(v):
		time_of_day = v
		queue_redraw()

func look() -> Dictionary:
	return LOOKS.get(time_of_day, LOOKS[&"midday"])

func _draw() -> void:
	var l := look()
	var w := size.x
	var h := size.y
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]),
		PackedColorArray([l["top"], l["top"], l["horizon"], l["horizon"]]))

	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	if l["stars"]:
		for _i in range(90):
			var at := Vector2(rng.randf() * w, rng.randf_range(0.2, SKYLINE_TOP) * h)
			draw_circle(at, rng.randf_range(1.0, 2.4), Color(1, 1, 1, rng.randf_range(0.45, 1.0)))
	else:
		for _i in range(90):   # the same draws, so the town below never moves
			rng.randf(); rng.randf(); rng.randf(); rng.randf()

	_draw_body(l, w, h)
	if (l["clouds"] as Color).a > 0.0:
		for spec in [[0.14, 0.44, 1.0], [0.63, 0.40, 0.9], [0.76, 0.56, 1.1], [0.97, 0.28, 0.8]]:
			_cloud(Vector2(spec[0] * w, spec[1] * h), spec[2] * h * 0.05, l["clouds"])
	_draw_skyline(l, w, h, rng)

## The sun, with a halo - or the moon, with a bite out of it.
func _draw_body(l: Dictionary, w: float, h: float) -> void:
	var at := Vector2(l["body_at"].x * w, l["body_at"].y * h)
	var r: float = l["body_r"] * h
	var halo: Color = l["halo"]
	for k in range(6, 0, -1):
		draw_circle(at, r * (1.0 + k * 0.45), Color(halo, halo.a * 0.1))
	draw_circle(at, r, l["body"])
	if l["moon"]:
		# The sky's own colour at that height, over most of the disc: a crescent.
		var behind: Color = (l["top"] as Color).lerp(l["horizon"], at.y / h)
		draw_circle(at + Vector2(r * 0.45, -r * 0.2), r * 0.92, behind)

func _cloud(at: Vector2, r: float, color: Color) -> void:
	for puff in [Vector2(0, 0), Vector2(1.1, 0.25), Vector2(-1.1, 0.3), Vector2(0.55, -0.45),
			Vector2(-0.5, -0.35), Vector2(2.0, 0.45), Vector2(-1.9, 0.5)]:
		draw_circle(at + puff * r, r * (1.0 if puff == Vector2.ZERO else 0.8), color)

## Rooftops along the bottom, all the way across - and at night, their lights.
func _draw_skyline(l: Dictionary, w: float, h: float, rng: RandomNumberGenerator) -> void:
	var x := 0.0
	while x < w:
		var bw := rng.randf_range(0.03, 0.075) * w
		var top := rng.randf_range(SKYLINE_TOP, 0.9) * h
		draw_rect(Rect2(x, top, bw + 1.0, h - top), l["skyline"])
		if l["lit"]:
			var cols := int(bw / (0.012 * w))
			var rows := int((h - top) / (0.05 * h))
			for cx in range(cols):
				for cy in range(rows):
					if rng.randf() < 0.28:
						draw_rect(Rect2(x + (cx + 0.3) * 0.012 * w, top + (cy + 0.35) * 0.05 * h,
							0.006 * w, 0.022 * h), Color("ffd27a"))
		else:
			# The same draws either way, so a building is the same building by day.
			var cols := int(bw / (0.012 * w))
			var rows := int((h - top) / (0.05 * h))
			for _k in range(cols * rows):
				rng.randf()
		x += bw
