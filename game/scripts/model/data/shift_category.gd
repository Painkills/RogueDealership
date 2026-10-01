class_name ShiftCategory extends Resource
## A pool of premade shifts, and when they may be dealt onto the calendar -
## "only at night", "only on the first or last day of the week", "a boss day".
## Each shift in it says how likely it is to come up (ShiftProfile.chance);
## this says only WHEN, and whether one coming up takes the whole day. See
## Week for the dealing, and ShiftProfilePool.categories for where these live.

## The slots the regular tiers are worked in, in the order `slots` ticks them.
const SLOTS: Array[StringName] = [&"morning", &"midday", &"night"]

@export var display_name: String
## Days of the week its shifts may be dealt on. None ticked = any day.
@export_flags("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun") var days: int = 0
## The regular shifts' slots its shifts may take. None ticked = any of them.
@export_flags("Morning", "Midday", "Night") var slots: int = 0
## One of these coming up is the day's only shift - nothing else to pick.
@export var boss_day: bool = false
## Weeks of the run its shifts may be dealt in. None ticked = any week - a
## shift tuned for week one (a fixed quota, say) ticks only Week 1.
@export_flags("Week 1", "Week 2", "Week 3", "Week 4") var weeks: int = 0
@export var shifts: Array[ShiftProfile] = []

## `day` is the run's own 1-based day: day 1 is a Monday, and a new week starts
## every `week_length` days - so with a five-day week, day 6 is Monday again.
func allows_day(day: int, week_length: int = 7) -> bool:
	var length := maxi(1, week_length)
	var week := (day - 1) / length
	if weeks != 0 and (weeks & (1 << week)) == 0:
		return false
	return days == 0 or (days & (1 << ((day - 1) % length))) != 0

func allows_slot(slot: StringName) -> bool:
	var i := SLOTS.find(slot)
	return i >= 0 and (slots == 0 or (slots & (1 << i)) != 0)

## Every slot it allows, in the day's own order.
func allowed_slots() -> Array[StringName]:
	var out: Array[StringName] = []
	for slot in SLOTS:
		if allows_slot(slot):
			out.append(slot)
	return out
