extends SceneTree
## Balance probe: how strong does a support card have to be to earn its place?
##
## Builds made-up, single-purpose support cards - pure appeal, pure margin,
## margin bought with appeal, appeal bought with patience, pure patience - at a
## range of strengths, adds ONE copy to the starter deck, and prints how much
## more (or less) a shift banks than the starter deck alone. A card that does
## nothing at all is in the list too: that is the price of a dead slot in the
## hand, which every real card has to beat first.
##
##     godot --headless --path game --script res://tools/probe_support.gd
##
## SimPlayer plays it: it reads every customer perfectly, so it needs appeal
## less than a person reading bands would. Treat the appeal rows as a floor.

const SEEDS := 400
## Where to measure: [tier, day]. Averaged, so one context does not decide it.
const SPOTS := [[&"midday", 4], [&"night", 6]]

var _cfg: ShiftConfig
var _pool: ShiftProfilePool
var _cards: CardPool
var _base := 0

func _init() -> void:
	_cfg = load("res://data/shift_config.tres")
	_pool = load("res://data/shift_profile_pool.tres")
	_cards = load("res://data/card_pool.tres")
	# `-- fog`: play on what a person can see - see SimPlayer.fog.
	SimPlayer.fog = OS.get_cmdline_user_args().has("fog")
	if SimPlayer.fog:
		print("Fog: playing on what a person can see.")
	_base = _banked(null)
	_base_walked = _last_walked
	_base_standing = _last_standing
	print("Starter deck banks %d a shift (midday day 4 and night day 6, %d shifts each)." % [_base, SEEDS])
	print("A tick is worth about %d; the shift has %d." % [_base / _cfg.shift_ticks, _cfg.shift_ticks])
	print("")
	print("card (1 tick unless noted)              banked  walkouts  standing   (change, per shift)")
	_row("does nothing (a dead slot)", [])
	for a in [4, 6, 8, 10, 12, 15, 20]:
		_row("+%d appeal" % a, [_fx(ChangeAppeal, a)])
	for a in [8, 12, 16, 20]:
		_row("+%d appeal, -2 patience" % a, [_fx(ChangeAppeal, a), _fx(ChangePatience, -2)])
	for m in [200, 400, 600, 800, 1000, 1500]:
		_row("+$%d to the deal" % m, [_fx(ChangeMargin, m)])
	for m in [400, 800, 1200, 1600]:
		_row("-5 appeal, +$%d to the deal" % m, [_fx(ChangeAppeal, -5), _fx(ChangeMargin, m)])
	for p in [2, 3, 5, 8]:
		_row("+%d patience" % p, [_fx(ChangePatience, p)], false)
	quit(0)

func _fx(kind, amount: int) -> Effect:
	var e: Effect = kind.new()
	e.amount = amount
	return e

func _row(label: String, effects: Array, needs_offer: bool = true) -> void:
	var card := SupportCardDef.new()
	card.id = &"probe"
	card.display_name = label
	card.needs_offer = needs_offer
	var typed: Array[Effect] = []
	for e in effects:
		typed.append(e)
	card.effects = typed
	var banked := _banked(card) - _base
	print("%-38s %+6d    %+5.2f      %+5.1f" % [label, banked,
		_last_walked - _base_walked, _last_standing - _base_standing])

var _last_walked := 0.0
var _last_standing := 0.0
var _base_walked := 0.0
var _base_standing := 0.0

func _banked(extra: CardDef) -> int:
	var total := 0
	var walked := 0.0
	var standing := 0.0
	for spot in SPOTS:
		var profile: ShiftProfile = _pool.by_id(spot[0])
		for seed_value in range(SEEDS):
			var run := RunState.new(_cfg, load("res://data/interests/interest_pool.tres"), _cards,
				load("res://data/archetype_pool.tres"), seed_value * 7919 + int(spot[1]))
			run.shift_number = int(spot[1])
			if extra != null:
				run.deck.add(extra)
			var s := run.start_shift(profile)
			SimPlayer.play(s)
			var r := s.report()
			total += int(r["margin_banked"])
			walked += float(r["customers_walked"])
			standing += float(r["standing_delta"])
	var n := float(SEEDS * SPOTS.size())
	_last_walked = walked / n
	_last_standing = standing / n
	return total / (SEEDS * SPOTS.size())
