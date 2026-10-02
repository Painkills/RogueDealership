extends SceneTree
## Balance probe: what one support card is worth. Plays the same shifts with
## the starter deck, then with the starter deck plus one copy of each support
## card (plain, then upgraded), and prints how much more each banks a shift on
## average - next to a card that does nothing, which is the price of a dead
## slot in the hand every real card has to beat first.
##
##     godot --headless --path game --script res://tools/probe_card_value.gd
##
## SimPlayer plays: appeal, patience, concessions, cards that add margin and
## free draw cards. It reads every customer perfectly, so it needs appeal less
## than a person reading bands would, and it never plays Active Listening.

const SEEDS := 400
## Where to measure: [tier, day]. Averaged, so one context does not decide it.
const SPOTS := [[&"midday", 4], [&"night", 6]]

var _cfg: ShiftConfig
var _pool: ShiftProfilePool
var _cards: CardPool

func _init() -> void:
	_cfg = load("res://data/shift_config.tres")
	_pool = load("res://data/shift_profile_pool.tres")
	_cards = load("res://data/card_pool.tres")
	# `-- fog`: play on what a person can see - see SimPlayer.fog.
	SimPlayer.fog = OS.get_cmdline_user_args().has("fog")
	if SimPlayer.fog:
		print("Fog: playing on what a person can see.")
	var base := _banked(null, false)
	print("Starter deck banks %d a shift (midday day 4 and night day 6, %d shifts each)." % [base, SEEDS])
	print("")
	print("card                        ticks   +1 copy   +1 upgraded")
	var blank := SupportCardDef.new()
	blank.id = &"blank"
	print("%-26s %5s   %+6d" % ["(a card that does nothing)", "-", _banked(blank, false) - base])
	for c in _cards.cards:
		if c is ProductCardDef:
			continue
		print("%-26s %5d   %+6d    %+6d" % [c.display_name, c.ticks,
			_banked(c, false) - base, _banked(c, true) - base])
	quit(0)

func _banked(extra: CardDef, upgraded: bool) -> int:
	var total := 0
	for spot in SPOTS:
		var profile: ShiftProfile = _pool.by_id(spot[0])
		for seed_value in range(SEEDS):
			var run := RunState.new(_cfg, load("res://data/interests/interest_pool.tres"), _cards,
				load("res://data/archetype_pool.tres"), seed_value * 7919 + int(spot[1]))
			run.shift_number = int(spot[1])
			if extra != null:
				var inst := run.deck.add(extra)
				if upgraded:
					run.deck.upgrade(inst.uid)
			var s := run.start_shift(profile)
			SimPlayer.play(s)
			total += int(s.report()["margin_banked"])
	return total / (SEEDS * SPOTS.size())
