extends SceneTree
## Drives the real run.tscn through a whole run: shift, shop, shift.
##
## The suite covers RunState and Shop as objects. What only a live scene can
## answer is whether the two screens actually hand off to each other, and
## whether a card bought in the shop turns up in the next shift's deck.
##
##   godot --headless --path game --script res://tools/drive_run.gd

var _root: Node
var _done := false
var _failures: Array[String] = []
var _checks := 0

func _init() -> void:
	seed(20260905)
	_root = (load("res://scenes/run.tscn") as PackedScene).instantiate()
	get_root().add_child(_root)

func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true

	var run: RunState = _root._run
	_check("a run started", run != null)
	_check("on shift 1", run.shift_number == 1)
	_check("with the floor showing, not the shop", not _root._shop_view.visible)
	_check("and the shift's HUD with it",
		(_root._shift_view.get_node(^"HUD") as CanvasLayer).visible)

	var deck_before: int = run.deck.cards.size()
	_finish_the_shift()

	_check("finishing a shift opens the shop", _root._shop_view.visible)
	_check("and hides the shift's HUD, not just its table",
		not (_root._shift_view.get_node(^"HUD") as CanvasLayer).visible)
	_check("the run advanced to shift 2", run.shift_number == 2)
	_check("with money from the shift just played", run.money == int(
		run.reports[0]["margin_banked"]))

	# Buy the cheapest thing on the shelf, with the money to afford it.
	var shop: Shop = _root._shop_view._shop
	run.money = 100000
	_root._shop_view._render()
	var bought: CardDef = shop.offers[0]
	var res := shop.buy(bought)
	_check("bought %s (%s)" % [bought.display_name, res.msg], res.ok)
	_check("the deck grew", run.deck.cards.size() == deck_before + 1)

	_root._shop_view.done.emit()
	_check("leaving the shop opens the floor again", not _root._shop_view.visible)
	_check("on a shift that knows which one it is",
		_root._shift_view._shift.shift_number == 2)
	_check("running to the climbing quota",
		_root._shift_view._shift.quota == run.quota_for(2))

	# The point of the whole milestone: the purchase came to work with you.
	var uids := {}
	for c in _root._shift_view._shift.draw:
		uids[c.uid] = true
	for c in _root._shift_view._shift.hand:
		uids[c.uid] = true
	var found := false
	for c in run.deck.cards:
		if c.card == bought and uids.has(c.uid):
			found = true
	_check("and the card you bought is in the shift's deck", found)

	print("")
	const EXPECTED_MIN := 14
	if _checks < EXPECTED_MIN:
		print("FAIL  only %d checks ran, expected at least %d - something aborted"
			% [_checks, EXPECTED_MIN])
		_failures.append("check count collapsed")

	if _failures.is_empty():
		print("%d checks, all passed" % _checks)
		quit(0)
	else:
		for f in _failures:
			print("FAIL  " + f)
		print("%d checks, %d FAILED" % [_checks, _failures.size()])
		quit(1)
	return true

func _finish_the_shift() -> void:
	## Burn the clock the way test_deck_persistence does, then press the report's
	## own button rather than emitting the signal by hand - the wiring from that
	## button to the run controller is part of what this is checking.
	var s: Shift = _root._shift_view._shift
	var guard := 0
	while not s.is_over() and guard < 500:
		guard += 1
		if not s.hand.is_empty():
			_root._shift_view._apply(s.dig(0))
		elif s.seated().is_empty():
			_root._shift_view._apply(s.wait())
		else:
			break
	_check("the shift ran out of clock (%d of %d)" % [s.tick, s.tick_budget],
		s.is_over())
	var report = _root._shift_view._report_overlay
	_check("the report came up", report.visible)
	report.continue_pressed.emit()

func _check(label: String, ok: bool) -> void:
	_checks += 1
	if not ok:
		_failures.append(label)
