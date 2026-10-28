extends SceneTree
## How near each slot's dealt shift comes to the difficulty target it was built
## for, over many runs' calendars - and how many hard archetypes they bring.
## Read it after changing who may come in, or the points.
##
##   godot --headless --path game --script res://tools/difficulty_report.gd -- <runs>

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var runs := int(args[0]) if not args.is_empty() else 200
	var cfg: ShiftConfig = load("res://data/shift_config.tres")
	var pool: ShiftProfilePool = load("res://data/shift_profile_pool.tres")
	var arch: ArchetypePool = load("res://data/archetype_pool.tres")
	# Per slot: shifts, |dealt - target| summed, off by more than the tolerance,
	# hard customers, and hard ones that came again (a second of the same).
	var by_slot := {}
	for seed in range(1, runs + 1):
		var week := Week.new(pool, cfg.shifts_in_run, seed, cfg.days_per_week, arch, cfg)
		for day in range(1, cfg.shifts_in_run + 1):
			for p in week.offers(day):
				if p.lineup.is_empty() or p.is_boss_day():
					continue
				var tier: ShiftProfile = null
				for t in pool.profiles:
					if t.worked_at() == p.worked_at():
						tier = t
				if tier == null:
					continue
				var key := "%s day %02d" % [p.worked_at(), day]
				var row: Dictionary = by_slot.get(key, {"n": 0, "target": tier.difficulty_on(day),
					"off": 0, "missed": 0, "hard": 0, "doubled": 0})
				row["n"] += 1
				var miss := absi(p.difficulty - tier.difficulty_on(day))
				row["off"] += miss
				if miss > cfg.difficulty_tolerance:
					row["missed"] += 1
				var seen := {}
				for a in p.lineup:
					if a.hard:
						row["hard"] += 1
						if seen.has(a.id):
							row["doubled"] += 1
						seen[a.id] = true
				by_slot[key] = row
	var keys := by_slot.keys()
	keys.sort()
	print("slot             target  avg off  missed%  hard/shift  repeats/100")
	for key in keys:
		var r: Dictionary = by_slot[key]
		print("%-16s %6d  %7.2f  %7.1f  %10.2f  %8.1f" % [key, r["target"],
			float(r["off"]) / r["n"], 100.0 * r["missed"] / r["n"],
			float(r["hard"]) / r["n"], 100.0 * r["doubled"] / r["n"]])
	quit()
