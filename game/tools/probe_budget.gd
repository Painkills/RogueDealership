extends SceneTree
## Balance probe: how each budget shift (ShiftProfile.budget_scale) plays out -
## quota made, how much of the room's budget gets captured, how long it runs,
## who walks - and, to set it against, how the regular morning, midday and night
## shifts play the same player over the same first week. SimPlayer on the run's
## starter deck, 100 seeds a shift.
##
##     godot --headless --path game --script res://tools/probe_budget.gd [-- fog]
##
## `fog`: play on what a person can see (SimPlayer.fog) - the other reads every
## customer perfectly, so it is the ceiling.

const SEEDS := 100
## The first week, which is where the budget shifts are dealt.
const WEEK_DAYS := 5

var _cfg: ShiftConfig
var _interests: InterestPool
var _cards: CardPool
var _archetypes: ArchetypePool
var _pool: ShiftProfilePool

func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "fog":
			SimPlayer.fog = true
	_cfg = load("res://data/shift_config.tres")
	_interests = load("res://data/interests/interest_pool.tres")
	_cards = load("res://data/card_pool.tres")
	_archetypes = load("res://data/archetype_pool.tres")
	_pool = load("res://data/shift_profile_pool.tres")
	var budget_shifts: Array[ShiftProfile] = []
	for category in _pool.categories:
		for p in category.shifts:
			if p.budget_scale > 0.0 and not budget_shifts.has(p):
				budget_shifts.append(p)
	print("%s player, %d seeds a shift" % ["Fair" if SimPlayer.fog else "Perfect-reader", SEEDS])
	print("")
	print("BUDGET SHIFTS")
	_header()
	var all_budget := _blank()
	for p in budget_shifts:
		var row := _play(p, 1)
		_merge(all_budget, row)
		_print(p.id, row)
	_print("all budget shifts", all_budget)
	print("")
	print("REGULAR SHIFTS, days 1-%d of the same week (midday and night from day 2)" % WEEK_DAYS)
	_header()
	var all_regular := _blank()
	for tier in _pool.profiles:
		var row := _blank()
		for day in range(tier.from_day, WEEK_DAYS + 1):
			_merge(row, _play(tier, day))
		_merge(all_regular, row)
		_print(tier.id, row)
	_print("all regular shifts", all_regular)
	quit(0)

func _blank() -> Dictionary:
	return {"n": 0, "quota": 0, "made": 0, "banked": 0, "seen": 0, "signed": 0,
		"walked": 0, "ticks": 0, "standing": 0, "budget_seen": 0, "captured": 0,
		"failed": 0}

func _merge(into: Dictionary, row: Dictionary) -> void:
	for k in row:
		into[k] += row[k]

## SEEDS plays of `profile` on `day` of a fresh run.
func _play(profile: ShiftProfile, day: int) -> Dictionary:
	var row := _blank()
	for seed_value in range(SEEDS):
		var run := RunState.new(_cfg, _interests, _cards, _archetypes,
			seed_value * 7919 + 3, null, _pool, null)
		run.shift_number = day
		var s := run.start_shift(profile)
		SimPlayer.play(s)
		var r := s.report()
		row["n"] += 1
		row["quota"] += int(r["quota"])
		row["made"] += 1 if r["made_quota"] else 0
		row["banked"] += int(r["margin_banked"])
		row["seen"] += int(r["customers_seen"])
		row["signed"] += int(r["customers_signed"])
		row["walked"] += int(r["customers_walked"])
		row["ticks"] += int(r["ticks"])
		row["standing"] += int(r["standing_delta"])
		row["budget_seen"] += int(r["budget_seen"])
		row["captured"] += int(r["budget_captured"])
		row["failed"] += int(r["failed_offers"])
	return row

func _header() -> void:
	print("%-20s %6s %6s %7s %6s %6s %7s %6s %9s %9s" % ["", "quota", "made",
		"banked", "seen", "signed", "walked", "ticks", "standing", "captured"])

func _print(label: String, row: Dictionary) -> void:
	var n := maxf(1.0, float(row["n"]))
	var captured := "-"
	if int(row["budget_seen"]) > 0:
		captured = "%d%%" % roundi(100.0 * int(row["captured"]) / float(row["budget_seen"]))
	print("%-20s %6d %5d%% %7d %6.1f %6.1f %7.2f %6.1f %+9.1f %9s" % [label,
		roundi(int(row["quota"]) / n), roundi(100.0 * int(row["made"]) / n),
		roundi(int(row["banked"]) / n), int(row["seen"]) / n, int(row["signed"]) / n,
		int(row["walked"]) / n, int(row["ticks"]) / n, int(row["standing"]) / n,
		captured])
