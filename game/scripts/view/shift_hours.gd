class_name ShiftHours extends RefCounted
## When each kind of shift runs, in hours of the day: where its event sits on
## the picker's calendar, what the clock on the desk's tablet reads as the
## shift goes, and what the office windows show. Keyed by ShiftProfile.id the
## way the picker's own colours are (Palette's shift_<id> roles) - a profile
## this does not name runs through the middle of the day.

const HOURS := {
	&"morning": [8.0, 12.0],
	&"midday": [12.0, 16.0],
	&"night": [18.0, 22.0],
}
const DEFAULT := [12.0, 16.0]

## [start, end] of the day this kind of shift works, in hours.
static func of(id: StringName) -> Array:
	return HOURS.get(id, DEFAULT)

## The time of day `tick` ticks into a shift of `budget` ticks, as a clock
## reads it: "10:20 AM". Each tick is an even share of the shift's hours, so a
## 24-tick, four-hour shift moves the clock ten minutes a tick.
static func clock(id: StringName, tick: int, budget: int) -> String:
	var h: Array = of(id)
	var t := clampf(float(tick) / float(maxi(1, budget)), 0.0, 1.0)
	var minutes := roundi(lerpf(float(h[0]), float(h[1]), t) * 60.0)
	var hour := (minutes / 60) % 24
	var shown := hour % 12
	return "%d:%02d %s" % [12 if shown == 0 else shown, minutes % 60,
		"AM" if hour < 12 else "PM"]
