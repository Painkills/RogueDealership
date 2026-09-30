class_name Week extends RefCounted
## The run's calendar: which shifts each day offers, dealt once when the run
## starts - so opening the calendar again never deals a day differently.
##
## Mostly the regular tiers. A premade shift from one of the pool's categories
## takes a tier's slot on a day it comes up; a boss day's takes the whole day:
##
## 1. Boss categories that allow the day roll first. If one of their shifts
##    comes up, it is the day's only shift.
## 2. Otherwise each tier's slot rolls between the premade shifts allowed in it
##    and the tier itself. Each premade shift comes up with its own chance and
##    the tier with whatever is left - three night shifts at 0.2, 0.1 and 0.3
##    leave the regular night shift 0.4. Past 1 in total, they share it out
##    between them and the tier never comes up there.
##
## Pure like the rest of scripts/run - the pool is handed in.

var _days: Array = []   ## per day, from day 1: an Array[ShiftProfile]

func _init(pool: ShiftProfilePool, day_count: int, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for day in range(1, day_count + 1):
		_days.append(_deal(pool, day, rng))

## What day `day` (1-based) offers, in the day's own order. Nothing past the
## run's last day.
func offers(day: int) -> Array[ShiftProfile]:
	var out: Array[ShiftProfile] = []
	if day >= 1 and day <= _days.size():
		out.assign(_days[day - 1])
	return out

static func _deal(pool: ShiftProfilePool, day: int,
		rng: RandomNumberGenerator) -> Array[ShiftProfile]:
	var out: Array[ShiftProfile] = []
	var boss := _roll(_candidates(pool, day, true, &""), rng)
	if not boss.is_empty():
		out.append(_dealt(boss))
		return out
	for tier in pool.profiles:
		var premade := _roll(_candidates(pool, day, false, tier.id), rng)
		out.append(tier if premade.is_empty() else _dealt(premade))
	return out

## Every premade shift that may be dealt on `day` - boss days' or the rest's -
## as {shift, category, slot}. A boss day takes a slot of its own category's
## choosing; the rest are asked about `slot`. A shift in two categories that
## both allow it is only counted once.
static func _candidates(pool: ShiftProfilePool, day: int, bosses: bool,
		slot: StringName) -> Array:
	var out := []
	var seen := {}
	for category in pool.categories:
		if category == null or category.boss_day != bosses or not category.allows_day(day):
			continue
		var at: Array[StringName] = [slot]
		if bosses:
			at = category.allowed_slots()
		if at.is_empty() or not category.allows_slot(at[0]):
			continue
		for shift in category.shifts:
			if shift == null or seen.has(shift):
				continue
			seen[shift] = true
			out.append({"shift": shift, "category": category, "slots": at})
	return out

## One roll between `candidates` and nothing at all. Each comes up with its
## own chance and nothing with whatever is left; past 1 in total, they share
## it out between them instead.
static func _roll(candidates: Array, rng: RandomNumberGenerator) -> Dictionary:
	var total := 0.0
	for c in candidates:
		total += maxf(0.0, (c["shift"] as ShiftProfile).chance)
	if total <= 0.0:
		return {}
	var r := rng.randf() * maxf(1.0, total)
	for c in candidates:
		r -= maxf(0.0, (c["shift"] as ShiftProfile).chance)
		if r < 0.0:
			var picked: Dictionary = c.duplicate()
			var slots: Array = c["slots"]
			picked["slot"] = slots[rng.randi_range(0, slots.size() - 1)]
			return picked
	return {}

## The copy that goes on the calendar, carrying the slot it took and who
## dealt it - the authored resource itself is never marked.
static func _dealt(pick: Dictionary) -> ShiftProfile:
	var copy := (pick["shift"] as ShiftProfile).duplicate() as ShiftProfile
	copy.time_of_day = pick["slot"]
	copy.dealt_by = pick["category"]
	return copy
