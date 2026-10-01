extends SceneTree
## Balance probe: what a shift PAYS against what the shop CHARGES.
##
##     godot --headless --path game --script res://tools/pay_ladder.gd
##
## Pure arithmetic, no play: for every standard shift and boss, on a few days of
## the run, the pay at a few multiples of quota (base salary + commission on the
## dollars over), and which rungs of the price ladder that covers. It reads the
## config and the profiles, so retune either and re-run it.
##
## The one design target it checks is ONE_CARD below - "players should be able
## to purchase one card every shift if they go over quota by at least 1.25".
## It is a probe, not a test: retuning is meant to be easy, so a miss prints a
## flag rather than failing anything.

## The rung one shift's pay at TARGET_OVER of quota has to cover.
const ONE_CARD := CardDef.Rarity.VALUE
const TARGET_OVER := 1.25
const OVERS: Array[float] = [1.0, 1.25, 1.5, 2.0]
const RUNGS: Array[String] = ["Basic", "Economy", "Value", "Preferred"]

func _init() -> void:
	var cfg: ShiftConfig = load("res://data/shift_config.tres")
	var pool: ShiftProfilePool = load("res://data/shift_profile_pool.tres")
	var ladder := cfg.card_prices
	var ladder_text: Array[String] = []
	for i in range(ladder.size()):
		ladder_text.append("%s %s (upgrade %s)" % [RUNGS[i], Format.money(ladder[i]),
			Format.money(roundi(ladder[i] * cfg.upgrade_price_share))])
	print("Ladder: " + ", ".join(ladder_text))
	print("Base pay: %s, +%s a week. Target: %.2fx quota buys one %s card.\n"
		% [Format.money(cfg.paycheck), Format.money(cfg.paycheck_raise_per_week),
			TARGET_OVER, RUNGS[ONE_CARD]])

	var profiles: Array[ShiftProfile] = []
	for id in [&"morning", &"midday", &"night"]:
		profiles.append(pool.by_id(id))
	for category in pool.categories:
		if category.boss_day:
			profiles.append_array(category.shifts)

	var misses := 0
	for profile in profiles:
		print("%s  (%d%% commission)" % [profile.display_name, roundi(profile.commission * 100.0)])
		for day in _days(cfg, profile):
			var quota := profile.quota_on(RunState.new(cfg, load("res://data/interests/interest_pool.tres"),
				load("res://data/card_pool.tres"), load("res://data/archetype_pool.tres"), 1).quota_for(day))
			var week := (day - 1) / maxi(1, cfg.days_per_week) + 1
			var cells: Array[String] = []
			for over in OVERS:
				var pay := _pay(cfg, profile, quota, over, week)
				cells.append("%.2fx %s [%s]" % [over, Format.money(pay), _covers(pay, ladder)])
				if is_equal_approx(over, TARGET_OVER) and pay < ladder[ONE_CARD]:
					misses += 1
					cells[-1] += " <-- short of one %s" % RUNGS[ONE_CARD]
			print("  day %2d  quota %-8s %s" % [day, Format.money(quota), "   ".join(cells)])
		print("")
	print("%s: %d day(s) where %.2fx quota does not buy one %s card."
		% ["ALL CLEAR" if misses == 0 else "FLAGGED", misses, TARGET_OVER, RUNGS[ONE_CARD]])
	quit(0)

## Base salary for the week, plus commission on the dollars over quota.
func _pay(cfg: ShiftConfig, profile: ShiftProfile, quota: int, over: float, week: int) -> int:
	return RunState.bonus_from({"paycheck": cfg.paycheck_in_week(week),
		"quota": quota, "margin_banked": roundi(quota * over),
		"commission": profile.commission})

## The days worth showing: its first day, then the first of each later week and
## the last of the run - or just the one day a fixed-quota shift is dealt on.
func _days(cfg: ShiftConfig, profile: ShiftProfile) -> Array[int]:
	var out: Array[int] = []
	var first := maxi(1, profile.from_day)
	var per_week := maxi(1, cfg.days_per_week)
	for d in [first, first + 2, per_week + 1, per_week + 3, cfg.shifts_in_run]:
		if d >= first and d <= cfg.shifts_in_run and not out.has(d):
			out.append(d)
	if profile.is_premade() and profile.quota > 0:
		return [first]
	return out

## "B E V P": which rungs this pay covers, as the letters of those it buys.
func _covers(pay: int, ladder: Array[int]) -> String:
	var s := ""
	for i in range(ladder.size()):
		s += RUNGS[i][0] if pay >= ladder[i] else "-"
	return s
