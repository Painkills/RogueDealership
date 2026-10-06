extends SceneTree
## Balance probe: how hard a shift is, in the points the calendar deals by
## (CustomerArchetype.difficulty, ShiftProfile.difficulty,
## ShiftComplicator.points). Prints suggestions - nothing is written to data.
##
##     godot --headless --path game --script res://tools/rate_shifts.gd [-- mode] [day=N] [seeds=N]
##
## How hard is measured the same way for everything: the standing a shift
## costs, on average, played by the fair player (SimPlayer.fog) with the
## starter deck on one reference day (day=3 by default, where most shifts are
## winnable some of the time). A rating is a comparison, never an absolute: "this
## plays like a 12-point shift" means it costs what a regular morning lineup of
## 12 points costs, on the same day, with the same deck.
##
## Modes:
## - (none)      the baseline - standing lost per points total - then a
##               suggested rating for every premade shift in the calendar's
##               non-boss categories (a fixed one: its rating; one that scales:
##               what its own rules add) and for every complicator.
## - archetypes  five of a kind of each archetype, and what that suggests each
##               is worth.
## - calendar    the calendar a couple of runs deal, day by day: each slot's
##               shift, its difficulty, who comes in and its complicators.

const SPAN := [8, 11, 14]       ## the regular lineups a rule is measured on top of

var _cfg: ShiftConfig
var _pool: ShiftProfilePool
var _interests: InterestPool
var _cards: CardPool
var _arch: ArchetypePool
var _day := 3
var _seeds := 200
## The yardstick: a regular morning lineup of `customers`, on the run's own
## quota - no morning discount - so a premade shift's own quota is what differs.
var _tier: ShiftProfile
## points total -> mean standing lost
var _baseline := {}

func _init() -> void:
	_cfg = load("res://data/shift_config.tres")
	_pool = load("res://data/shift_profile_pool.tres")
	_interests = load("res://data/interests/interest_pool.tres")
	_cards = load("res://data/card_pool.tres")
	_arch = load("res://data/archetype_pool.tres")
	SimPlayer.fog = true
	var mode := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("day="):
			_day = int(arg.substr(4))
		elif arg.begins_with("seeds="):
			_seeds = int(arg.substr(6))
		else:
			mode = arg
	_tier = (_pool.by_id(&"morning") if _pool.by_id(&"morning") != null
		else _pool.profiles[0]).duplicate() as ShiftProfile
	_tier.quota_offset = 0
	_tier.quota_scale = 1.0
	if _tier.customers <= 0:
		_tier.customers = 5
	match mode:
		"calendar":
			_calendar()
		"archetypes":
			_baseline_curve()
			_archetypes()
		_:
			_baseline_curve()
			_premade()
			_complicators()
	quit(0)

# ------------------------------------------------------------------ measuring
## Mean standing lost, quota made and walkouts over the seeds, the shift for
## each seed built by `build` (seed -> ShiftProfile).
func _measure(build: Callable) -> Dictionary:
	var lost := 0.0
	var made := 0.0
	var walked := 0.0
	for seed_value in range(_seeds):
		var run := RunState.new(_cfg, _interests, _cards, _arch, seed_value * 7919 + _day)
		run.shift_number = _day
		var s := run.start_shift(build.call(seed_value))
		SimPlayer.play(s)
		var report := s.report()
		lost -= float(report["standing_delta"])
		made += 1.0 if s.margin_banked >= s.quota else 0.0
		walked += float(s.stat["customers_walked"])
	var n := float(_seeds)
	return {"lost": lost / n, "made": made / n, "walked": walked / n}

func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 104729 + 13
	return rng

## The week the yardstick's lineups are drawn from: the run's last, so every
## archetype can be in one and the scale reaches the hardest - whichever day the
## shift itself is played on.
func _week() -> int:
	return Shift.week_of(_cfg.shifts_in_run, _cfg.days_per_week)

## A regular lineup of `points`, built fresh for each seed.
func _regular(points: int) -> Callable:
	return func(seed_value: int) -> ShiftProfile:
		return ShiftGenerator.fill(_tier, _tier, _day, _week(), points, _arch, [], 0.0,
			_rng(seed_value))

## `shift`'s own rules on a regular lineup of `points` (and `with`'s complicators).
func _ruled(shift: ShiftProfile, points: int, with: Array = []) -> Callable:
	return func(seed_value: int) -> ShiftProfile:
		var lineup := ShiftGenerator.fill(_tier, _tier, _day, _week(), points, _arch, [], 0.0,
			_rng(seed_value))
		var copy := shift.duplicate() as ShiftProfile
		copy.lineup = lineup.lineup
		copy.complicators.assign(with)
		return copy

func _baseline_curve() -> void:
	var low := 999
	var high := 0
	for a in Shift.eligible_archetypes(_arch, _week()):
		low = mini(low, a.difficulty)
		high = maxi(high, a.difficulty)
	print("Fair player, starter deck, day %d, %d seeds; a regular lineup of %d from every archetype."
		% [_day, _seeds, _tier.customers])
	print("points  standing lost  quota made  walkouts")
	for points in range(low * _tier.customers, high * _tier.customers + 1):
		var m := _measure(_regular(points))
		_baseline[points] = m["lost"]
		print("%5d   %8.1f       %4.0f%%     %4.2f" % [points, m["lost"], m["made"] * 100.0, m["walked"]])
	print("")

## The points total whose baseline costs nearest `lost` - in between two,
## pro rata - so a shift can be said to "play like" one.
func _plays_like(lost: float) -> float:
	var keys := _baseline.keys()
	keys.sort()
	if lost <= float(_baseline[keys[0]]):
		return float(keys[0])
	for i in range(keys.size() - 1):
		var a: float = _baseline[keys[i]]
		var b: float = _baseline[keys[i + 1]]
		if (lost >= a and lost <= b) or (lost <= a and lost >= b):
			return keys[i] + (0.0 if is_equal_approx(a, b) else (lost - a) / (b - a))
	return float(keys[keys.size() - 1])

## What a rule set adds, in points: played on top of each of SPAN's regular
## lineups, against what that lineup plays like on its own.
func _adds(shift: ShiftProfile, with: Array = []) -> float:
	var total := 0.0
	for points in SPAN:
		var m := _measure(_ruled(shift, points, with))
		total += _plays_like(m["lost"]) - _plays_like(float(_baseline.get(points, m["lost"])))
	return total / SPAN.size()

# ------------------------------------------------------------------ the modes
func _premade() -> void:
	print("Premade shifts (non-boss):")
	var seen := {}
	for category in _pool.categories:
		if category == null or category.boss_day:
			continue
		for shift in category.shifts:
			if shift == null or seen.has(shift):
				continue
			seen[shift] = true
			if shift.scales():
				var adds := _adds(shift)
				print("  %-22s scales  - its rules add %+.1f points   (set: %d)   %s"
					% [shift.display_name, adds, shift.difficulty, shift.rules_preview()])
			else:
				var m := _measure(func(_s): return shift)
				print("  %-22s fixed   - plays like %.1f points   (set: %d)   lost %.1f, made %.0f%%"
					% [shift.display_name, _plays_like(m["lost"]), shift.difficulty, m["lost"],
						m["made"] * 100.0])
	print("")

func _complicators() -> void:
	print("Complicators:")
	for c in _pool.complicators:
		if c == null:
			continue
		var adds := _adds(ShiftProfile.new(), [c])
		print("  %-22s adds %+.1f points   (set: %d)" % [c.display_text, adds, c.points])
	print("")

func _archetypes() -> void:
	print("Five of a kind - what each archetype plays like, per customer:")
	for a in _arch.archetypes:
		var five: Array[CustomerArchetype] = []
		for _i in range(_tier.customers):
			five.append(a)
		var m := _measure(func(_s):
			var p := _tier.duplicate() as ShiftProfile
			p.lineup = five
			return p)
		print("  %-18s lost %5.1f  made %3.0f%%  walkouts %.2f  -> %.1f points each   (set: %d, from week %d)"
			% [a.display_name, m["lost"], m["made"] * 100.0, m["walked"],
				_plays_like(m["lost"]) / _tier.customers, a.difficulty, a.from_week])

func _calendar() -> void:
	for seed_value in [1, 2]:
		var run := RunState.new(_cfg, _interests, _cards, _arch, seed_value, null, _pool)
		print("== a run's calendar, seed %d" % seed_value)
		for day in range(1, _cfg.shifts_in_run + 1):
			for p in run.week.offers(day):
				var who: Array[String] = []
				for a in p.lineup:
					who.append(a.display_name)
				var tag := "boss" if p.is_boss_day() else ("special" if p.is_premade() else "")
				print("  day %2d %-7s %-20s %-7s difficulty %2d  %s%s" % [day, p.worked_at(),
					p.display_name, tag, p.difficulty, ", ".join(who),
					("   [" + p.rules_preview() + "]") if p.rules_preview() != "" else ""])
		print("")
