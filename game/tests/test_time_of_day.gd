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

func _first_collider(node: Node) -> Node:
	for child in node.get_children():
		if child is CollisionObject3D:
			return child
		var found := _first_collider(child)
		if found != null:
			return found
	return null
