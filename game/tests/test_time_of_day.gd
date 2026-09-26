extends RefCounted
## What time of day a shift is worked at, everywhere it shows: ShiftHours'
## clock, the sky the office windows look out on, and the windows themselves.
var h: Harness

# ------------------------------------------------------------------ the clock
func test_each_shift_runs_the_hours_the_calendar_gives_it() -> void:
	h.eq("morning runs eight till noon", ShiftHours.of(&"morning"), [8.0, 12.0])
	h.eq("midday runs noon till four", ShiftHours.of(&"midday"), [12.0, 16.0])
	h.eq("night runs six till ten", ShiftHours.of(&"night"), [18.0, 22.0])
	h.eq("anything else runs through the middle of the day", ShiftHours.of(&"brunch"),
		ShiftHours.of(&"midday"))

func test_the_clock_moves_with_the_ticks() -> void:
	h.eq("a morning opens at eight", ShiftHours.clock(&"morning", 0, 24), "8:00 AM")
	h.eq("ten minutes a tick, over a four-hour, 24-tick shift",
		ShiftHours.clock(&"morning", 1, 24), "8:10 AM")
	h.eq("half way through a morning", ShiftHours.clock(&"morning", 12, 24), "10:00 AM")
	h.eq("and the bell at noon", ShiftHours.clock(&"morning", 24, 24), "12:00 PM")
	h.eq("a midday shift in the afternoon", ShiftHours.clock(&"midday", 12, 24), "2:00 PM")
	h.eq("a night shift in the evening", ShiftHours.clock(&"night", 3, 24), "6:30 PM")
	h.eq("never past its own end", ShiftHours.clock(&"night", 99, 24), "10:00 PM")
	h.eq("and a longer shift takes smaller steps", ShiftHours.clock(&"morning", 3, 30),
		"8:24 AM")

# -------------------------------------------------------------------- the sky
func test_the_sky_knows_all_three_shifts() -> void:
	for id in [&"morning", &"midday", &"night"]:
		h.check("a look for %s" % id, SkyView.LOOKS.has(id))
	var sky := SkyView.new()
	sky.time_of_day = &"brunch"
	h.eq("anything else looks out on the middle of the day", sky.look(),
		SkyView.LOOKS[&"midday"])
	sky.free()

func test_each_time_of_day_is_its_own_sky() -> void:
	var tops := {}
	for id in SkyView.LOOKS:
		tops[SkyView.LOOKS[id]["top"]] = id
	h.eq("three skies, three colours", tops.size(), 3)
	var night: Dictionary = SkyView.LOOKS[&"night"]
	var midday: Dictionary = SkyView.LOOKS[&"midday"]
	h.check("night is darker than midday",
		(night["top"] as Color).get_luminance() < (midday["top"] as Color).get_luminance())
	h.check("with stars, a moon, and the town's lights on",
		night["stars"] and night["moon"] and night["lit"])
	h.check("which the day has none of",
		not midday["stars"] and not midday["moon"] and not midday["lit"])
	h.check("the morning sun sits lower than midday's",
		SkyView.LOOKS[&"morning"]["body_at"].y > midday["body_at"].y)

# ---------------------------------------------------------------- the windows
func test_the_office_has_windows_on_the_back_wall() -> void:
	## "Add some windows visible behind the customers that suggest the morning /
	## midday / night shift thing we did."
	var s: Node3D = (load("res://scenes/shift.tscn") as PackedScene).instantiate()
	var w := s.get_node_or_null(^"OfficeWindows") as OfficeWindows
	h.check("there are windows", w != null)
	if w == null:
		s.free()
		return
	var wall := s.get_node(^"Wall") as Node3D
	h.check("on the back wall, just in front of it (%.2f vs %.2f)"
		% [w.position.z, wall.position.z],
		w.position.z > wall.position.z and w.position.z - wall.position.z < 0.2)
	var panes := w.get_node(^"Panes").get_children()
	h.check("several panes (%d)" % panes.size(), panes.size() >= 3)
	var seat := s.get_node(^"Table/Carousel/Seat0") as Node3D
	h.check("behind every customer, not among them",
		w.position.z < seat.position.z - 10.0)
	h.check("and nothing in them can take a click",
		_first_collider(w) == null)
	var sky := w.get_node(^"SkyViewport/Sky") as SkyView
	h.check("they look out on a drawn sky", sky != null)
	w.show_time(&"night")
	h.eq("which follows the shift being worked", w.time_of_day(), &"night")
	h.eq("all the way to the drawing", sky.time_of_day, &"night")
	w.show_time(&"morning")
	h.eq("and back", sky.time_of_day, &"morning")
	s.free()

func test_every_pane_shows_its_own_slice_of_the_one_sky() -> void:
	## One picture cut across all of them, so the view carries on behind the
	## frames between them - not the same square of sky repeated five times.
	var s: Node3D = (load("res://scenes/shift.tscn") as PackedScene).instantiate()
	var w := s.get_node(^"OfficeWindows") as OfficeWindows
	w._bind()
	var panes := w.get_node(^"Panes").get_children()
	var offsets := {}
	for p in panes:
		var m := (p as MeshInstance3D).material_override as StandardMaterial3D
		h.check("%s has the sky on it" % p.name, m != null and m.albedo_texture != null)
		if m == null:
			continue
		h.check("%s shines by its own light" % p.name,
			m.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED)
		h.check("%s shows a fifth-wide slice" % p.name,
			is_equal_approx(m.uv1_scale.x, 1.0 / panes.size()))
		offsets[m.uv1_offset.x] = true
	h.eq("and every slice is a different one", offsets.size(), panes.size())
	s.free()

func _first_collider(node: Node) -> Node:
	for child in node.get_children():
		if child is CollisionObject3D:
			return child
		var found := _first_collider(child)
		if found != null:
			return found
	return null
