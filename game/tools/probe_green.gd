extends SceneTree
## Balance probe: how far over their Line an offer is the first time it shows
## green - what Good Will has to work with. Plays the starter deck through
## midday and night shifts and, per archetype, prints how many offers went
## green, the average points over the Line, and the spread.
##
##     godot --headless --path game --script res://tools/probe_green.gd [-- fog n=400]
##
## `fog`: play on what a person can see (SimPlayer.fog). `n=`: shifts per spot.

const SPOTS := [[&"midday", 4], [&"night", 6]]

func _init() -> void:
	var cfg: ShiftConfig = load("res://data/shift_config.tres")
	var pool: ShiftProfilePool = load("res://data/shift_profile_pool.tres")
	var n := 400
	for arg in OS.get_cmdline_user_args():
		if arg == "fog":
			SimPlayer.fog = true
		elif arg.begins_with("n="):
			n = int(arg.substr(2))
	SimPlayer.track = true
	SimPlayer.greens = {}
	for spot in SPOTS:
		var profile: ShiftProfile = pool.by_id(spot[0])
		for seed_value in range(n):
			var run := RunState.new(cfg, load("res://data/interests/interest_pool.tres"),
				load("res://data/card_pool.tres"), load("res://data/archetype_pool.tres"),
				seed_value * 7919 + int(spot[1]))
			run.shift_number = int(spot[1])
			SimPlayer.play(run.start_shift(profile))
	print("mode %s, %d shifts per spot" % ["fog" if SimPlayer.fog else "clear", n])
	print("archetype,offers,mean over,min,max,share under 4,share 4 to 16,share over 16")
	for id in SimPlayer.greens:
		var over: Array = SimPlayer.greens[id]
		var total := 0
		var low := 9999
		var high := -9999
		var under := 0
		var mid := 0
		for v in over:
			total += v
			low = mini(low, v)
			high = maxi(high, v)
			if v < 4:
				under += 1
			elif v <= 16:
				mid += 1
		var count: int = over.size()
		print("%s,%d,%.1f,%d,%d,%.0f%%,%.0f%%,%.0f%%" % [id, count, float(total) / count, low, high,
			100.0 * under / count, 100.0 * mid / count, 100.0 * (count - under - mid) / count])
	quit(0)
