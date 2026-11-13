extends SceneTree
## Balance probe: does building a deck feel like power? Plays the same shifts with
## the starter deck, then with a build added to it - a handful of cards, plain and
## upgraded, and the dealership perks that go with them - and prints how many
## times the starter deck's take each banks. The number a build has to move.
##
##     godot --headless --path game --script res://tools/probe_build.gd
##     ... -- fog      (play on what a person can see - see SimPlayer.fog)
##
## A build is cards by id with how many of each, and perks by id.

const SEEDS := 300
const SPOTS := [[&"midday", 4], [&"night", 6]]

## name -> {cards: {id: copies}, perks: [ids]}
const BUILDS := {
	"momentum: 7 cards": {"cards": {"hot_streak": 2, "stack_em_high": 2, "fast_talker": 1,
		"snowball": 1, "premium_package": 1}, "perks": []},
	"  + Spiff Board": {"cards": {"hot_streak": 2, "stack_em_high": 2, "fast_talker": 1,
		"snowball": 1, "premium_package": 1}, "perks": ["spiff_board"]},
	"  + Spiff Board and Morning Huddle": {"cards": {"hot_streak": 2, "stack_em_high": 2,
		"fast_talker": 1, "snowball": 1, "premium_package": 1},
		"perks": ["spiff_board", "morning_huddle"]},
	"Spiff Board alone": {"cards": {}, "perks": ["spiff_board"]},
}

var _cfg: ShiftConfig
var _pool: ShiftProfilePool
var _cards: CardPool

func _init() -> void:
	_cfg = load("res://data/shift_config.tres")
	_pool = load("res://data/shift_profile_pool.tres")
	_cards = load("res://data/card_pool.tres")
	SimPlayer.fog = OS.get_cmdline_user_args().has("fog")
	if SimPlayer.fog:
		print("Fog: playing on what a person can see.")
	var base := _banked({}, [], false)
	print("Starter deck banks %d a shift (midday day 4 and night day 6, %d shifts each)." % [base, SEEDS])
	print("")
	print("build|plain|x starter|upgraded|x starter")
	for name in BUILDS:
		var b: Dictionary = BUILDS[name]
		var plain := _banked(b["cards"], b["perks"], false)
		var up := _banked(b["cards"], b["perks"], true)
		print("%s|%d|%.2f|%d|%.2f" % [name, plain, float(plain) / base, up, float(up) / base])
	quit(0)

func _banked(cards: Dictionary, perks: Array, upgraded: bool) -> int:
	var total := 0
	for spot in SPOTS:
		var profile: ShiftProfile = _pool.by_id(spot[0])
		for seed_value in range(SEEDS):
			var run := RunState.new(_cfg, load("res://data/interests/interest_pool.tres"), _cards,
				load("res://data/archetype_pool.tres"), seed_value * 7919 + int(spot[1]))
			run.shift_number = int(spot[1])
			run.make_menu()
			for id in cards:
				for _i in range(int(cards[id])):
					var inst := run.deck.add(_cards.by_id(StringName(id)))
					if upgraded:
						run.deck.upgrade(inst.uid)
			for id in perks:
				run.dealership.append(load("res://data/dealership_upgrades/%s.tres" % id))
			var s := run.start_shift(profile)
			SimPlayer.play(s)
			total += int(s.report()["margin_banked"])
	return total / (SEEDS * SPOTS.size())
