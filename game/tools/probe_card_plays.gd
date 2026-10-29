extends SceneTree
## Which cards SimPlayer actually plays. For each support card: how often a copy
## in the starter deck gets played per shift, over the same shifts as
## probe_card_value.gd. A card that reads 0.00 is one the sim has not been taught
## to use - its worth in that probe is only the dead slot it takes.
##
##     godot --headless --path game --script res://tools/probe_card_plays.gd
##     ... -- fog      (play on what a person can see - see SimPlayer.fog)

const SEEDS := 200
const SPOTS := [[&"midday", 4], [&"night", 6]]

var _cfg: ShiftConfig
var _pool: ShiftProfilePool
var _cards: CardPool

func _init() -> void:
	_cfg = load("res://data/shift_config.tres")
	_pool = load("res://data/shift_profile_pool.tres")
	_cards = load("res://data/card_pool.tres")
	SimPlayer.fog = OS.get_cmdline_user_args().has("fog")
	print("card                        ticks   plays/shift (3 copies)   upgraded")
	var never := []
	for c in _cards.cards:
		if c is ProductCardDef:
			continue
		var plain := _plays(c, false)
		var upgraded := _plays(c, true)
		print("%-26s %5d   %8.2f             %8.2f" % [c.display_name, c.ticks, plain, upgraded])
		if plain == 0.0:
			never.append(c.display_name)
	print("")
	print("never played: %s" % (", ".join(never) if not never.is_empty() else "none"))
	quit(0)

func _plays(card: CardDef, upgraded: bool) -> float:
	var played := 0
	var shifts := 0
	for spot in SPOTS:
		var profile: ShiftProfile = _pool.by_id(spot[0])
		for seed_value in range(SEEDS):
			var run := RunState.new(_cfg, load("res://data/interests/interest_pool.tres"), _cards,
				load("res://data/archetype_pool.tres"), seed_value * 7919 + int(spot[1]))
			run.shift_number = int(spot[1])
			# `-- menu`: menu runs - products on the menu, not in hand.
			if OS.get_cmdline_user_args().has("menu"):
				run.make_menu()
			for _i in range(3):
				var inst := run.deck.add(card)
				if upgraded:
					run.deck.upgrade(inst.uid)
			var s := run.start_shift(profile)
			SimPlayer.play(s)
			shifts += 1
			for entry in s.action_log:
				if bool(entry.get("yours", false)) and str(entry["name"]) == card.display_name:
					played += 1
	return float(played) / float(shifts)
