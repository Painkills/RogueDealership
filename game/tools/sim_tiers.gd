extends SceneTree
## Balance probe: plays the standard shifts - morning, midday, night - many
## times each with one fixed, reasonably sharp policy, and prints how they
## come out, day by day of the week.
##
##     godot --headless --path game --script res://tools/sim_tiers.gd
##
## What-ifs, without touching the data: tier.field=value after a `--`, on a
## copy of the profile - e.g.
##
##     ... --script res://tools/sim_tiers.gd -- midday.patience_scale=0.85
##
## Every shift starts from the STARTER deck with full standing, so the tier and
## the day are the only differences between them - the numbers compare tiers,
## they do not predict a real run (where the deck grows in the store).
##
## The player here knows every customer's true priorities and Line - a sharp
## human reads most of that from bands and Read the Room, at a cost this
## skips - so absolute results run optimistic. It answers demands it can,
## signs anyone about to walk, and leaves Family First alone when asked.

const SEEDS := 300
const TIERS: Array[StringName] = [&"morning", &"midday", &"night"]

var _cfg: ShiftConfig
var _pool: ShiftProfilePool

func _init() -> void:
	_cfg = load("res://data/shift_config.tres")
	_pool = load("res://data/shift_profile_pool.tres")
	var days: int = _cfg.shifts_in_run
	var profiles := {}
	for tier in TIERS:
		profiles[tier] = _pool.by_id(tier).duplicate()
	for arg in OS.get_cmdline_user_args():
		if arg == "fog":
			SimPlayer.fog = true
			print("Fog: playing on what a person can see.")
			continue
		var parts: PackedStringArray = arg.split("=")
		var path: PackedStringArray = parts[0].split(".")
		if parts.size() != 2 or path.size() != 2 or not profiles.has(StringName(path[0])):
			print("ignoring %s - expected tier.field=value" % arg)
			continue
		var p: ShiftProfile = profiles[StringName(path[0])]
		p.set(path[1], str_to_var(parts[1]))
		print("what-if: %s.%s = %s" % [path[0], path[1], p.get(path[1])])
	var rows := []
	for tier in TIERS:
		var profile: ShiftProfile = profiles[tier]
		for day in range(1, days + 1):
			if day >= profile.from_day:     # only the days the calendar offers it
				rows.append(_cell(profile, day))
	_print(rows)
	quit(0)

## SEEDS shifts of one tier on one day of the week, summed up.
func _cell(profile: ShiftProfile, day: int) -> Dictionary:
	var sum := {"margin": 0.0, "made": 0.0, "walked": 0.0, "signed": 0.0, "seen": 0.0,
		"standing": 0.0, "bonus": 0.0, "missed": 0.0, "met": 0.0, "lost_bell": 0.0,
		"quota": 0.0, "st_quota": 0.0, "st_walk": 0.0, "st_product": 0.0, "st_heal": 0.0}
	for seed_value in range(SEEDS):
		var run := RunState.new(_cfg, load("res://data/interests/interest_pool.tres"),
			load("res://data/card_pool.tres"), load("res://data/archetype_pool.tres"),
			seed_value * 7919 + day)
		run.shift_number = day
		var s := run.start_shift(profile)
		SimPlayer.play(s)
		var r := s.report()
		sum["margin"] += r["margin_banked"]
		sum["quota"] += r["quota"]
		sum["made"] += 1.0 if r["made_quota"] else 0.0
		sum["walked"] += r["customers_walked"]
		sum["signed"] += r["customers_signed"]
		sum["seen"] += r["customers_seen"]
		sum["standing"] += r["standing_delta"]
		# The same total, by cause: walkouts, the product quota, a heal, and
		# whatever is left over - the quota itself.
		var walk: int = -int(r["standing_lost_to_walkouts"])
		var product: int = -int(r.get("category_quota_cost", 0))
		var heal: int = int(r.get("standing_healed", 0))
		sum["st_walk"] += walk
		sum["st_product"] += product
		sum["st_heal"] += heal
		sum["st_quota"] += int(r["standing_delta"]) - walk - product - heal
		sum["bonus"] += RunState.bonus_from(r)
		sum["missed"] += r["demands_missed"]
		sum["met"] += r["demands_met"]
		sum["lost_bell"] += r["margin_lost_to_closing"]
	for k in sum:
		sum[k] /= SEEDS
	sum["tier"] = profile.id
	sum["day"] = day
	return sum

# --- the table ----------------------------------------------------------------

func _print(rows: Array) -> void:
	print("tier     day  quota   banked  made%  bonus   stand  seen  signed walked  dem_met dem_miss lost@bell")
	for r in rows:
		print("%-8s %3d  %5d  %6d  %4.0f%%  %5d  %+5.1f  %4.1f  %4.1f  %4.2f   %4.2f    %4.2f    %5d" % [
			r["tier"], r["day"], r["quota"], r["margin"], r["made"] * 100.0, r["bonus"],
			r["standing"], r["seen"], r["signed"], r["walked"], r["met"], r["missed"],
			r["lost_bell"]])
	print("")
	print("tier     banked  made%  bonus   stand  seen  signed walked  (averaged over the days it is offered)")
	for tier in TIERS:
		var n := 0
		var t := {"margin": 0.0, "made": 0.0, "bonus": 0.0, "standing": 0.0, "seen": 0.0,
			"signed": 0.0, "walked": 0.0}
		for r in rows:
			if r["tier"] != tier:
				continue
			n += 1
			for k in t:
				t[k] += r[k]
		for k in t:
			t[k] /= n
		print("%-8s %6d  %4.0f%%  %5d  %+5.1f  %4.1f  %4.1f  %4.2f" % [tier, t["margin"],
			t["made"] * 100.0, t["bonus"], t["standing"], t["seen"], t["signed"], t["walked"]])
	print("")
	print("standing by cause, per shift:  day  total   quota  walkouts  product-quota")
	for r in rows:
		print("%-8s                        %3d  %+5.1f  %+6.1f    %+5.1f      %+5.1f" % [
			r["tier"], r["day"], r["standing"], r["st_quota"], r["st_walk"], r["st_product"]])
