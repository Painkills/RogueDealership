extends SceneTree
## Balance probe: how each budget shift (ShiftProfile.budget_scale) plays out -
## quota made, how much of the room's budget gets captured, how long it runs,
## who walks. SimPlayer on the run's starter deck, 100 seeds a shift.
##
##     godot --headless --path game --script res://tools/probe_budget.gd [-- fog]
##
## `fog`: play on what a person can see (SimPlayer.fog) - the other reads every
## customer perfectly, so it is the ceiling.

const SEEDS := 100

func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "fog":
			SimPlayer.fog = true
	var cfg: ShiftConfig = load("res://data/shift_config.tres")
	var interests: InterestPool = load("res://data/interests/interest_pool.tres")
	var cards: CardPool = load("res://data/card_pool.tres")
	var archetypes: ArchetypePool = load("res://data/archetype_pool.tres")
	var pool: ShiftProfilePool = load("res://data/shift_profile_pool.tres")
	var shifts: Array[ShiftProfile] = []
	for category in pool.categories:
		for p in category.shifts:
			if p.budget_scale > 0.0 and not shifts.has(p):
				shifts.append(p)
	print("%s player, %d seeds a shift" % ["Fair" if SimPlayer.fog else "Perfect-reader", SEEDS])
	print("%-18s %6s %7s %9s %7s %7s %6s %7s" % ["shift", "quota",
		"made", "captured", "banked", "walked", "ticks", "failed"])
	for p in shifts:
		var made := 0
		var banked := 0
		var seen := 0
		var captured := 0
		var walked := 0
		var ticks := 0
		var failed := 0
		var quota := 0
		for seed_value in range(SEEDS):
			var run := RunState.new(cfg, interests, cards, archetypes,
				seed_value * 7919 + 3, null, pool, null)
			var s := run.start_shift(p)
			SimPlayer.play(s)
			var r := s.report()
			made += 1 if r["made_quota"] else 0
			banked += int(r["margin_banked"])
			seen += int(r["budget_seen"])
			captured += int(r["budget_captured"])
			walked += int(r["customers_walked"])
			ticks += int(r["ticks"])
			failed += int(r["failed_offers"])
			quota = int(r["quota"])
		print("%-18s %6d %6d%% %8d%% %7d %7.1f %6.1f %7.1f" % [p.id,
			quota, 100 * made / SEEDS,
			roundi(100.0 * captured / maxf(1.0, float(seen))),
			banked / SEEDS, float(walked) / SEEDS, float(ticks) / SEEDS,
			float(failed) / SEEDS])
	quit(0)
