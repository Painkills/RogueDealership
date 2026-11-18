extends SceneTree
## How near each day's dealt shifts come to the difficulty the ladder planned for
## them (ShiftProfile.planned - see DifficultyLadder), over many runs' calendars,
## and what each spent its points on: seats, quota, its customers, the rest.
## Read it after changing the ladder, the prices or who may come in.
##
##   godot --headless --path game --script res://tools/difficulty_report.gd -- <runs>

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var runs := int(args[0]) if not args.is_empty() else 200
	var cfg: ShiftConfig = load("res://data/shift_config.tres")
	var pool: ShiftProfilePool = load("res://data/shift_profile_pool.tres")
	var arch: ArchetypePool = load("res://data/archetype_pool.tres")
	var by_day := {}
	for seed in range(1, runs + 1):
		var week := Week.new(pool, cfg.shifts_in_run, seed, cfg.days_per_week, arch, cfg)
		for day in range(1, cfg.shifts_in_run + 1):
			for p in week.offers(day):
				if p.lineup.is_empty() or p.is_boss_day() or p.planned <= 0:
					continue
				var row: Dictionary = by_day.get(day, {"n": 0, "planned": 0, "off": 0, "missed": 0,
					"seats": 0, "quota": 0.0, "customers": 0, "modifiers": 0, "hard": 0})
				row["n"] += 1
				row["planned"] += p.planned
				var miss := absi(p.difficulty - p.planned)
				row["off"] += miss
				if miss > cfg.difficulty_tolerance:
					row["missed"] += 1
				row["seats"] += p.seats_on() if p.seats_on() > 0 else cfg.floor_size
				row["quota"] += float(p.quota_on(cfg.quota)) / float(cfg.quota)
				for a in p.lineup:
					row["customers"] += a.difficulty
					if a.hard:
						row["hard"] += 1
				for c in p.complicators:
					row["modifiers"] += c.points
				by_day[day] = row
	var days := by_day.keys()
	days.sort()
	print("day  planned  avg off  missed%  seats  quota x  customer pts  modifier pts  hard/shift")
	for day in days:
		var r: Dictionary = by_day[day]
		var n := float(r["n"])
		print("%3d  %7.1f  %7.2f  %7.1f  %5.2f  %7.2f  %12.1f  %12.1f  %10.2f" % [day,
			r["planned"] / n, r["off"] / n, 100.0 * r["missed"] / n, r["seats"] / n,
			r["quota"] / n, r["customers"] / n, r["modifiers"] / n, r["hard"] / n])
	quit()
