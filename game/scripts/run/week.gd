class_name Week extends RefCounted
## The run's calendar: which shifts each day offers, dealt once when the run
## starts - so opening the calendar again never deals a day differently.
##
## Each slot - morning, midday, night - has a difficulty target that climbs
## over the run (ShiftProfile.difficulty_on()), and what is dealt there is built
## to it:
##
## 1. Boss categories that allow the day roll first. If one of their shifts
##    comes up, it takes the place of one of the day's shifts, at random -
##    a regular one where it can, and only in a slot its category allows - so
##    it is a choice on the calendar, not the whole day.
## 2. Each tier offered that day - from its own from_day on - rolls
##    its slot between the premade shifts that fit there and a shift of its
##    own. Each premade shift comes up with its own chance and the tier with
##    whatever is left - three night shifts at 0.2, 0.1 and 0.3 leave the
##    regular night shift 0.4. Past 1 in total, they share it out between them
##    and the tier never comes up there. A tier not yet offered takes no
##    premade shift into its slot either.
##
## What fits a slot (see _fits()): a premade shift with a lineup, rated within
## ShiftConfig.difficulty_tolerance of the target, or unrated; one that scales,
## wherever the target leaves its customers enough to work with - it is then
## filled to the target with customers and complicators (ShiftGenerator). Each
## comes up at most once a week. The tier's own shift is a lineup of its
## `customers`, filled to the target the same way; a tier with none is the old
## random door.
##
## A premade shift that is not a boss is paid like the slot it took - see
## ShiftProfile.take_rewards_from().
##
## Days of the week are counted within the run's own week: with five days to a
## week, day 6 is Monday again.
##
## Pure like the rest of scripts/run - the pools are handed in. Built without
## archetypes, nothing is filled or rated: the tiers and premade shifts are
## dealt as they are, by chance alone.

var _days: Array = []   ## per day, from day 1: an Array[ShiftProfile]

var _archetypes: ArchetypePool = null
var _tolerance := 1
var _share := 0.3
var _week_length := 7
## The premade shifts dealt so far this week - each comes up once a week.
var _this_week := {}

func _init(pool: ShiftProfilePool, day_count: int, seed_value: int,
		week_length: int = 7, archetypes: ArchetypePool = null,
		cfg: ShiftConfig = null) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	_archetypes = archetypes
	_week_length = maxi(1, week_length)
	if cfg != null:
		_tolerance = cfg.difficulty_tolerance
		_share = cfg.complicator_share
	for day in range(1, day_count + 1):
		if (day - 1) % _week_length == 0:
			_this_week = {}
		_days.append(_deal(pool, day, rng))

## What day `day` (1-based) offers, in the day's own order. Nothing past the
## run's last day.
func offers(day: int) -> Array[ShiftProfile]:
	var out: Array[ShiftProfile] = []
	if day >= 1 and day <= _days.size():
		out.assign(_days[day - 1])
	return out

func _deal(pool: ShiftProfilePool, day: int, rng: RandomNumberGenerator) -> Array[ShiftProfile]:
	var out: Array[ShiftProfile] = []
	var boss := _roll(_candidates(pool, day, true, &"", _week_length), rng)
	var tiers: Array[ShiftProfile] = []
	tiers.assign(pool.profiles.filter(func(t): return day >= t.from_day))
	# A day with nothing to pick would stop the run dead - misauthored from_days
	# give way rather than softlock, the way the archetype gate does.
	if tiers.is_empty():
		tiers = pool.profiles.duplicate()
	var week := Shift.week_of(day, _week_length)
	for tier in tiers:
		var target := tier.difficulty_on(day)
		# A premade shift allowed in more than one slot still comes up once a
		# day - and once a week.
		var candidates: Array = _candidates(pool, day, false, tier.id, _week_length).filter(
			func(c): return not _this_week.has(c["shift"]) \
				and _fits(c["shift"], tier, target, week, pool.complicators, day))
		var premade := _roll(candidates, rng)
		if premade.is_empty():
			out.append(_regular(tier, day, week, target, pool.complicators, rng))
			continue
		var shift: ShiftProfile = premade["shift"]
		_this_week[shift] = true
		var copy: ShiftProfile
		if _builds(tier) and shift.scales():
			copy = ShiftGenerator.fill(shift, tier, day, week, target, _archetypes,
				pool.complicators, _share, rng)
		else:
			copy = shift.duplicate() as ShiftProfile
		out.append(_dealt(premade, copy))
		copy.take_rewards_from(tier)
	if not boss.is_empty():
		_seat_the_boss(out, boss, rng)
	return out

## Whether this calendar builds `tier`'s shifts to a difficulty target - it has
## archetypes to build them from, and the tier says how many customers.
func _builds(tier: ShiftProfile) -> bool:
	return _archetypes != null and tier.customers > 0

## The tier's own shift on `day`: a lineup built to `target`, or the tier
## itself where this calendar builds none.
func _regular(tier: ShiftProfile, day: int, week: int, target: int,
		complicators: Array, rng: RandomNumberGenerator) -> ShiftProfile:
	if not _builds(tier):
		return tier
	return ShiftGenerator.fill(tier, tier, day, week, target, _archetypes, complicators, _share, rng)

## Whether premade `shift` may be dealt into `tier`'s slot at `target` - see the
## top of this file. Every one fits a calendar that builds nothing.
func _fits(shift: ShiftProfile, tier: ShiftProfile, target: int, week: int,
		complicators: Array, day: int) -> bool:
	if not _builds(tier):
		return true
	# Never into a slot that keeps out someone it brings - "Speedster and
	# Family First never show at night" holds for a premade lineup too.
	if shift.lineup.any(func(a): return tier.excluded_archetypes.has(a)):
		return false
	# And nobody comes in before their week (CustomerArchetype.from_week),
	# named or not: a premade shift that brings someone from a later week waits
	# for it. Only a boss brings them early.
	if (shift.lineup + shift.only_archetypes).any(
			func(a): return a != null and a.from_week > week):
		return false
	if not shift.scales():
		return shift.difficulty == 0 or absi(shift.difficulty - target) <= _tolerance
	# What the slot leaves its customers once the shift's own rules are paid
	# for - enough for the cheapest lineup, and no more than the dearest one
	# and every complicator could make up.
	var count := shift.customers if shift.customers > 0 else tier.customers
	var excluded: Array = tier.excluded_archetypes + shift.excluded_archetypes
	var pool := Shift.eligible_archetypes(_archetypes, week, shift.only_archetypes, excluded)
	if pool.is_empty() or pool.any(func(a): return excluded.has(a)):
		return false
	var low := pool[0].difficulty
	var high := pool[0].difficulty
	for a in pool:
		low = mini(low, a.difficulty)
		high = maxi(high, a.difficulty)
	var extra := 0
	for c in complicators:
		if c != null and c.points > 0 and c.from_day <= day:
			extra += c.points
	var left := target - shift.difficulty
	return left >= low * count - _tolerance and left <= high * count + extra + _tolerance

## Puts `boss` in the place of one of `out`'s shifts, at random: one its
## category allows the slot of, and a regular tier's where there is one - a
## special shift already dealt that day keeps its place if it can.
static func _seat_the_boss(out: Array[ShiftProfile], boss: Dictionary,
		rng: RandomNumberGenerator) -> void:
	var category: ShiftCategory = boss["category"]
	var places: Array[int] = []
	for i in range(out.size()):
		if not out[i].is_premade() and category.allows_slot(out[i].worked_at()):
			places.append(i)
	if places.is_empty():
		for i in range(out.size()):
			if category.allows_slot(out[i].worked_at()):
				places.append(i)
	if places.is_empty():
		return
	var at: int = places[rng.randi_range(0, places.size() - 1)]
	boss["slot"] = out[at].worked_at()
	var fight := _dealt(boss, (boss["shift"] as ShiftProfile).duplicate() as ShiftProfile)
	# A boss that takes the whole day is the one thing offered.
	if category.takes_the_day:
		out.clear()
		out.append(fight)
		return
	out[at] = fight

## Every premade shift that may be dealt on `day` - boss days' or the rest's -
## as {shift, category, slot}. A boss day takes a slot of its own category's
## choosing; the rest are asked about `slot`. A shift in two categories that
## both allow it is only counted once.
static func _candidates(pool: ShiftProfilePool, day: int, bosses: bool,
		slot: StringName, week_length: int) -> Array:
	var out := []
	var seen := {}
	for category in pool.categories:
		if category == null or category.boss_day != bosses \
				or not category.allows_day(day, week_length):
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

## `copy` - of the picked shift, never the authored resource itself - marked
## with the slot it took and who dealt it, for the calendar.
static func _dealt(pick: Dictionary, copy: ShiftProfile) -> ShiftProfile:
	copy.time_of_day = pick["slot"]
	copy.dealt_by = pick["category"]
	return copy
