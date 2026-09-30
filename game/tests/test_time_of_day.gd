extends RefCounted
## What time of day a shift is worked at, everywhere it shows: ShiftHours'
## clock, the sky the office windows look out on, and the windows themselves.
var h: Harness

# ------------------------------------------------------------------ the clock
func test_each_shift_runs_hours_inside_one_day() -> void:
	## Whatever hours each shift is given - read from the table, never pinned.
	for id in ShiftHours.HOURS:
		var span: Array = ShiftHours.of(id)
		h.check("%s starts before it ends, inside the day (%s)" % [id, str(span)],
			span[0] >= 0.0 and span[0] < span[1] and span[1] <= 24.0)
	h.eq("anything else runs the default hours", ShiftHours.of(&"no_such_shift"),
		ShiftHours.DEFAULT)

func test_the_clock_moves_with_the_ticks() -> void:
	## Against each shift's own hours: its first hour at the start, its last at
	## the bell, half way at half time, and never past its end.
	for id in ShiftHours.HOURS:
		var span: Array = ShiftHours.of(id)
		h.eq("%s opens on its first hour" % id, ShiftHours.clock(id, 0, 24), _label(span[0]))
		h.eq("%s half way at half time" % id, ShiftHours.clock(id, 12, 24),
			_label((span[0] + span[1]) * 0.5))
		h.eq("%s closes on its last" % id, ShiftHours.clock(id, 24, 24), _label(span[1]))
		h.eq("%s never runs past its end" % id, ShiftHours.clock(id, 99, 24), _label(span[1]))
	var first: StringName = ShiftHours.HOURS.keys()[0]
	h.check("and a longer shift takes smaller steps",
		_minutes(ShiftHours.clock(first, 1, 30)) < _minutes(ShiftHours.clock(first, 1, 24)))

## An hour of the day on a 12-hour clock face - "8:10 AM" for 8.1667.
func _label(hour: float) -> String:
	var minutes := roundi(hour * 60.0)
	var hr := (minutes / 60) % 24
	var shown := hr % 12
	return "%d:%02d %s" % [12 if shown == 0 else shown, minutes % 60, "AM" if hr < 12 else "PM"]

func _minutes(clock: String) -> int:
	var parts := clock.split(" ")
	var hm := parts[0].split(":")
	return (int(hm[0]) % 12 + (12 if parts[1] == "PM" else 0)) * 60 + int(hm[1])

# -------------------------------------------------------------------- the sky
func test_the_sky_knows_all_three_shifts() -> void:
	for id in ShiftHours.HOURS:
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

func test_the_midday_sun_is_in_the_middle_window() -> void:
	## "For the midday shift sky, the sun should be in the middle window."
	## Measured against the real panes: the middle one shows the middle fifth
	## of the sky, and the sun has to be in that slice, above the rooftops.
	var s: Node3D = (load("res://scenes/shift.tscn") as PackedScene).instantiate()
	var panes := (s.get_node(^"OfficeWindows/Panes") as Node).get_child_count()
	var middle := panes / 2
	var sun: Vector2 = SkyView.LOOKS[&"midday"]["body_at"]
	var r: float = SkyView.LOOKS[&"midday"]["body_r"]
	h.check("the midday sun is in pane %d of %d (%.2f in %.2f..%.2f)"
		% [middle + 1, panes, sun.x, float(middle) / panes, float(middle + 1) / panes],
		sun.x - r > float(middle) / panes and sun.x + r < float(middle + 1) / panes)
	h.check("high up, over the rooftops", sun.y < SkyView.SKYLINE_TOP - 0.2)
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
