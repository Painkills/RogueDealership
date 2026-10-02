extends SceneTree
## Balance probe: what a visit with each kind of customer is worth. Plays the
## starter deck through morning, midday and night shifts and, per archetype,
## prints how many sales a visit runs to, what it banks, how many ticks it took
## and so the money each tick spent on them earned.
##
##     godot --headless --path game --script res://tools/probe_visits.gd [-- fog]
##
## Ticks are the ones spent working that customer - placing, playing cards,
## closing, and cycling cards while looking for something to sell them. Waiting
## for someone to walk in is nobody's. `fog`: play on what a person can see
## (SimPlayer.fog).

const SEEDS := 400
const SPOTS := [[&"morning", 2], [&"midday", 4], [&"night", 6]]

func _init() -> void:
	var cfg: ShiftConfig = load("res://data/shift_config.tres")
	var pool: ShiftProfilePool = load("res://data/shift_profile_pool.tres")
	SimPlayer.fog = OS.get_cmdline_user_args().has("fog")
	SimPlayer.track = true
	var by_arch := {}
	var shift_ticks := 0
	var shift_banked := 0
	for spot in SPOTS:
		var profile: ShiftProfile = pool.by_id(spot[0])
		for seed_value in range(SEEDS):
			var run := RunState.new(cfg, load("res://data/interests/interest_pool.tres"),
				load("res://data/card_pool.tres"), load("res://data/archetype_pool.tres"),
				seed_value * 7919 + int(spot[1]))
			run.shift_number = int(spot[1])
			SimPlayer.visits = {}
			var s := run.start_shift(profile)
			SimPlayer.play(s)
			shift_ticks += s.tick_budget
			shift_banked += s.margin_banked
			for c: Customer in SimPlayer.visits:
				var v: Dictionary = SimPlayer.visits[c]
				var name := c.archetype.display_name
				if not by_arch.has(name):
					by_arch[name] = {"n": 0, "sales": 0, "banked": 0, "ticks": 0, "walked": 0,
						"hist": [0, 0, 0, 0]}
				var a: Dictionary = by_arch[name]
				a["n"] += 1
				a["sales"] += c.sales
				a["banked"] += int(v["banked"])
				a["ticks"] += int(v["ticks"])
				a["walked"] += 1 if c.state == "walked" else 0
				a["hist"][mini(c.sales, 3)] += 1
	print("%s - starter deck, morning d2 + midday d4 + night d6, %d shifts each."
		% ["Fog (what a person sees)" if SimPlayer.fog else "Perfect reader", SEEDS])
	print("On average a tick earns %d across the whole shift." % (shift_banked / maxi(1, shift_ticks)))
	print("")
	print("archetype          visits  sales/visit   0 / 1 / 2 / 3+ sales    walked  ticks  banked   $/tick")
	var names := by_arch.keys()
	names.sort()
	for name in names:
		var a: Dictionary = by_arch[name]
		var n := float(a["n"])
		var h: Array = a["hist"]
		print("%-18s %6d     %4.2f     %3.0f%% /%3.0f%% /%3.0f%% /%3.0f%%     %3.0f%%   %4.1f  %6d   %6d" % [
			name, a["n"], a["sales"] / n,
			h[0] / n * 100.0, h[1] / n * 100.0, h[2] / n * 100.0, h[3] / n * 100.0,
			a["walked"] / n * 100.0, a["ticks"] / n, a["banked"] / n,
			a["banked"] / maxf(1.0, float(a["ticks"]))])
	quit(0)
