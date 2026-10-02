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
	# `-- only=midday`: one tier, at many more days, so who walked in is the
	# only thing that differs between shifts.
	var spots: Array = SPOTS
	var seeds := SEEDS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("only="):
			var tier := StringName(arg.substr(5))
			spots = [[tier, 3], [tier, 4], [tier, 5], [tier, 6]]
			print("Only %s shifts, days 3-6." % tier)
	var by_arch := {}
	var shift_ticks := 0
	var shift_banked := 0
	## How a shift went against how many of each archetype it saw: archetype
	## -> count -> {"n", "banked", "made"}.
	var by_count := {}
	for spot in spots:
		var profile: ShiftProfile = pool.by_id(spot[0])
		for seed_value in range(seeds):
			var run := RunState.new(cfg, load("res://data/interests/interest_pool.tres"),
				load("res://data/card_pool.tres"), load("res://data/archetype_pool.tres"),
				seed_value * 7919 + int(spot[1]))
			run.shift_number = int(spot[1])
			SimPlayer.visits = {}
			var s := run.start_shift(profile)
			SimPlayer.play(s)
			shift_ticks += s.tick_budget
			shift_banked += s.margin_banked
			var seen := {}
			for c: Customer in SimPlayer.visits:
				var aname := c.archetype.display_name
				seen[aname] = int(seen.get(aname, 0)) + 1
			var made := s.margin_banked >= s.quota
			for aname in _names(pool):
				var k := mini(int(seen.get(aname, 0)), 3)
				if not by_count.has(aname):
					by_count[aname] = {}
				var cell: Dictionary = by_count[aname].get(k, {"n": 0, "banked": 0, "made": 0,
					"quota": 0})
				cell["n"] += 1
				cell["banked"] += s.margin_banked
				cell["quota"] += s.quota
				cell["made"] += 1 if made else 0
				by_count[aname][k] = cell
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
				if not a.has("by"):
					a["by"] = {}
				for kind in v.get("by", {}):
					a["by"][kind] = int(a["by"].get(kind, 0)) + int(v["by"][kind])
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
	print("")
	print("Where a visit's ticks go, per visit:")
	for name in names:
		var a: Dictionary = by_arch[name]
		var by: Dictionary = a.get("by", {})
		var kinds := by.keys()
		kinds.sort_custom(func(x, y): return int(by[x]) > int(by[y]))
		var parts: Array[String] = []
		for kind in kinds:
			parts.append("%s %.1f" % [kind, float(by[kind]) / float(a["n"])])
		print("%-18s %s" % [name, ", ".join(parts)])
	print("")
	print("How a shift went by how many of each came in (0 / 1 / 2 / 3+): banked, quota made")
	for name in names:
		var line := "%-18s" % name
		for k in range(4):
			var cell: Dictionary = by_count.get(name, {}).get(k, {})
			if cell.is_empty() or int(cell["n"]) < 20:
				line += "        -          "
				continue
			var n := float(cell["n"])
			line += "  %5d %3.0f%% (n=%4d)" % [cell["banked"] / n, cell["made"] / n * 100.0, cell["n"]]
		print(line)
	quit(0)

## Every archetype that can come in, by display name.
func _names(_pool: ShiftProfilePool) -> Array:
	var out := []
	for a in (load("res://data/archetype_pool.tres") as ArchetypePool).archetypes:
		out.append(a.display_name)
	return out
