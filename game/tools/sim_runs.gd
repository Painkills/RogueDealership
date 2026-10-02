extends SceneTree
## Balance probe: whole runs, start to finish, under a few strategies for
## which shift to pick each day - shopping in between like a sensible player.
##
##     godot --headless --path game --script res://tools/sim_runs.gd
##
## What-ifs, without touching the data, the same way sim_tiers.gd takes them:
## tier.field=value (a ShiftProfile) or cfg.field=value (the ShiftConfig) after
## a `--`, e.g.
##
##     ... --script res://tools/sim_runs.gd -- night.commission=0.5 cfg.quota_growth=0.12
##
## The player is SimPlayer - optimistic, it reads every customer perfectly - so
## "how many runs make it" is an upper bound for a sharp human, not a forecast.
## The shop policy: the free pick is the rarest card on offer; then buy the
## rarest cards you can afford; then upgrade with whatever is left.

const SEEDS := 200
const TIERS: Array[StringName] = [&"morning", &"midday", &"night"]

var _cfg: ShiftConfig
var _pool: ShiftProfilePool
var _interests: InterestPool
var _cards: CardPool
var _arch: ArchetypePool
## shop=greedy (default): free pick, buy, upgrade. shop=upgrades: free pick and
## upgrades only. shop=none: nothing at all - the starter deck all run.
var _shop_mode := "greedy"

## Each strategy: which tiers it would rather work on `day`, best first.
var _strategies := {
	"all morning": func(_d: int): return [&"morning", &"midday", &"night"],
	"all midday": func(_d: int): return [&"midday", &"morning", &"night"],
	"all night": func(_d: int): return [&"night", &"midday", &"morning"],
	"midday, then night": func(d: int):
		return [&"midday", &"morning", &"night"] if d <= 5 else [&"night", &"midday", &"morning"],
	"alternate mid/night": func(d: int):
		return [&"midday", &"night", &"morning"] if d % 2 == 1 else [&"night", &"midday", &"morning"],
}

func _init() -> void:
	_cfg = (load("res://data/shift_config.tres") as ShiftConfig).duplicate()
	_pool = load("res://data/shift_profile_pool.tres")
	_interests = load("res://data/interests/interest_pool.tres")
	_cards = load("res://data/card_pool.tres")
	_arch = load("res://data/archetype_pool.tres")
	_what_ifs()
	print("strategy              survive  avg_day  banked   earned  bought upgr  deck  score   standing@day: 2   4   6   8  10")
	for name in _strategies:
		_report(name, _runs(_strategies[name]))
	quit(0)

func _what_ifs() -> void:
	for arg in OS.get_cmdline_user_args():
		var parts: PackedStringArray = arg.split("=")
		var path: PackedStringArray = parts[0].split(".")
		if parts.size() == 2 and parts[0] == "shop":
			_shop_mode = parts[1]
			print("shop policy: %s" % _shop_mode)
			continue
		# card.<id>.<field>=value - a card's own numbers, e.g. a product's margin.
		if parts.size() == 2 and path.size() == 3 and path[0] == "card":
			var card := _cards.by_id(StringName(path[1]))
			if card == null:
				print("ignoring %s - no such card" % arg)
				continue
			card.set(path[2], str_to_var(parts[1]))
			print("what-if: %s.%s = %s" % [path[1], path[2], card.get(path[2])])
			continue
		if parts.size() != 2 or path.size() != 2:
			print("ignoring %s - expected tier.field=value or cfg.field=value" % arg)
			continue
		var target: Resource = _cfg if path[0] == "cfg" else _profile(StringName(path[0]))
		if target == null:
			print("ignoring %s - no such tier" % arg)
			continue
		target.set(path[1], str_to_var(parts[1]))
		print("what-if: %s.%s = %s" % [path[0], path[1], target.get(path[1])])

## A standard tier, edited in place: the pool's profiles are the cached
## resources, so this lasts for this process only - never saved.
func _profile(id: StringName) -> ShiftProfile:
	return _pool.by_id(id)

func _runs(strategy: Callable) -> Array:
	var out := []
	for seed_value in range(SEEDS):
		out.append(_one_run(strategy, seed_value * 104729 + 17))
	return out

func _one_run(strategy: Callable, seed_value: int) -> Dictionary:
	var run := RunState.new(_cfg, _interests, _cards, _arch, seed_value, null, _pool)
	var r := {"days": 0, "earned": 0, "bought": 0, "upgraded": 0, "standing": {},
		"banked_on": {}, "quota_on": {}}
	while not run.is_over():
		var day := run.shift_number
		var profile := _choose(run.todays_shifts(), strategy.call(day))
		var s := run.start_shift(profile)
		SimPlayer.play(s)
		var report := s.report()
		r["banked_on"][day] = int(report["margin_banked"])
		r["quota_on"][day] = int(report["quota"])
		run.finish_shift(report)
		r["days"] = day if run.standing > 0 else day - 1
		r["earned"] += run.last_bonus
		r["standing"][day] = run.standing
		if not run.is_over():
			_shop(Shop.new(run, profile), r)
	r["survived"] = run.standing > 0
	r["reached_last"] = r["banked_on"].has(_cfg.shifts_in_run)
	r["unspent"] = run.money
	r["banked"] = run.banked_total
	r["deck"] = run.deck.cards.size()
	r["score"] = int(Score.tally(run)["total"])
	return r

## The first tier the strategy wants that today offers; a day with nothing
## else (a boss) gets what it has.
func _choose(offers: Array[ShiftProfile], wants: Array) -> ShiftProfile:
	for id in wants:
		for p in offers:
			if p.id == id:
				return p
	return offers[0]

func _shop(shop: Shop, r: Dictionary) -> void:
	if _shop_mode == "none":
		return
	if not shop.free_cards.is_empty():
		var best: CardDef = shop.free_cards[0]
		for c in shop.free_cards:
			if c.rarity > best.rarity:
				best = c
		shop.take_free(best)
	# Products first, best margin first - money is what quota wants - then the
	# rarest support cards.
	var shelf := shop.offers.duplicate()
	shelf.sort_custom(func(a, b):
		var pa := a is ProductCardDef
		var pb := b is ProductCardDef
		if pa != pb:
			return pa
		if pa:
			return (a as ProductCardDef).margin > (b as ProductCardDef).margin
		return a.rarity > b.rarity)
	for c in shelf:
		if _shop_mode == "greedy" and shop.buy(c).ok:
			r["bought"] += 1
	for uid in shop.upgrade_offers.duplicate():
		if shop.upgrade(uid).ok:
			r["upgraded"] += 1

func _report(name: String, runs: Array) -> void:
	var n := float(runs.size())
	var survived := 0.0
	var reached := 0.0
	var unspent := 0.0
	var t := {"days": 0.0, "banked": 0.0, "earned": 0.0, "bought": 0.0, "upgraded": 0.0,
		"deck": 0.0, "score": 0.0}
	var standing := {}
	for r in runs:
		survived += 1.0 if r["survived"] else 0.0
		reached += 1.0 if r["reached_last"] else 0.0
		unspent += float(r["unspent"])
		for k in t:
			t[k] += float(r[k])
		for d in [2, 4, 6, 8, 10]:
			# A run already over by day d counts as 0 standing that day.
			standing[d] = standing.get(d, 0.0) + float(r["standing"].get(d, 0))
	var line := "%-21s %5.0f%%  %6.1f  %6d  %6d   %4.1f %4.1f  %4.1f %6d               " % [name,
		survived / n * 100.0, t["days"] / n, t["banked"] / n, t["earned"] / n,
		t["bought"] / n, t["upgraded"] / n, t["deck"] / n, t["score"] / n]
	for d in [2, 4, 6, 8, 10]:
		line += "%4.0f" % (standing[d] / n)
	print(line)
	print("    reached the last day: %.0f%%   money left unspent at the end: %d"
		% [reached / n * 100.0, unspent / n])
	# Day by day, among the runs still going: banked against quota.
	var by_day := "    banked/quota by day:"
	for d in range(1, _cfg.shifts_in_run + 1):
		var alive := 0
		var b := 0.0
		var q := 0.0
		for r in runs:
			if r["banked_on"].has(d):
				alive += 1
				b += r["banked_on"][d]
				q += r["quota_on"][d]
		if alive > 0:
			by_day += " %d:%.1f/%.1f" % [d, b / alive / 1000.0, q / alive / 1000.0]
	print(by_day)
