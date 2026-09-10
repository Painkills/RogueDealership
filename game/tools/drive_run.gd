extends SceneTree
## Drives the real run.tscn through a whole run: shift, shop, shift.
##
## The suite covers RunState and Shop as objects. What only a live scene can
## answer is whether the two screens actually hand off to each other, and
## whether a card bought in the shop turns up in the next shift's deck - and,
## since the shop screen is BUILT rather than hand-tuned, whether its layout
## actually fits the screen it is built for.

const VIEWPORT := Vector2(1920, 1080)

var _root: Node
var _phase := 0
var _settle_frames := 0
var _failures: Array[String] = []
var _checks := 0

var _run: RunState
var _deck_before: int

func _init() -> void:
	seed(20260905)
	_root = (load("res://scenes/run.tscn") as PackedScene).instantiate()
	get_root().add_child(_root)

func _process(_delta: float) -> bool:
	if _phase == 0:
		_phase_0_open_and_finish_shift()
		_phase = 1
		return false

	if _phase == 1:
		# Container resorts (and therefore every child's real global_position)
		# are deferred, not synchronous with setup()/_render() - the exact gap
		# that let the shop's DoneButton render off-screen without a single
		# check ever catching it. A few idle frames flush that queue; one is
		# probably enough, but this costs nothing to be generous with.
		_settle_frames += 1
		if _settle_frames < 5:
			return false
		_check_shop_layout_fits_on_screen()
		_phase = 2
		return false

	if _phase == 2:
		_phase_2_buy_and_leave()

		print("")
		const EXPECTED_MIN := 20
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

	return true

func _phase_0_open_and_finish_shift() -> void:
	_run = _root._run
	_check("a run started", _run != null)
	_check("on shift 1", _run.shift_number == 1)
	_check("with the floor showing, not the shop", not _root._shop_view.visible)
	_check("and the shift's HUD with it",
		(_root._shift_view.get_node(^"HUD") as CanvasLayer).visible)

	_deck_before = _run.deck.cards.size()
	_finish_the_shift()

	_check("finishing a shift opens the shop", _root._shop_view.visible)
	_check("and hides the shift's HUD, not just its table",
		not (_root._shift_view.get_node(^"HUD") as CanvasLayer).visible)
	_check("the run advanced to shift 2", _run.shift_number == 2)
	var r0: Dictionary = _run.reports[0]
	_check("with only what that shift banked OVER quota (%d banked, %d quota)"
		% [int(r0["margin_banked"]), int(r0["quota"])],
		_run.money == RunState.bonus_from(r0))
	# This driver digs the clock away rather than selling anything, so it always
	# lands on the missed-quota branch. Pin that down, or the check above is
	# 0 == max(0, 0 - 3600) and proves nothing about the subtraction.
	_check("which after a shift that banked nothing is nothing",
		not bool(r0["made_quota"]) and _run.money == 0 and _run.last_bonus == 0)
	# The total wipeout costs standing too - but at half a fresh run's meter, not
	# all of it, so the run must have SURVIVED to reach shift 2 at all. This is
	# also where a stale _run reference (the exact bug class this project has
	# already caught once - a controller quietly rolling a fresh RunState out
	# from under a held reference) would surface: if this landed on 0 instead of
	# start - 50, either the formula drifted or is_over() ended the run early and
	# everything past this point is checking a dead object.
	_check("the wipeout cost standing (%d) but did not end the run" % _run.standing,
		_run.standing == _run.cfg.standing_start - 50 and not _run.is_over())
	# The panel you were just looking at had to show that number before
	# finish_shift() ran at all, so the two must agree.
	var panel = _root._shift_view._report_overlay
	_check("and the report panel's own bonus line agrees",
		panel._bonus.text.contains("No bonus"))
	# Missing quota is the only branch this driver's own play can reach, and the
	# line that ANNOUNCES a bonus is the whole point of the feature. Drive it
	# directly rather than leave the copy that matters unrendered by any test.
	#
	# panel.setup() is called directly here, bypassing _show_report()'s own
	# enrichment - so this synthetic dict has to carry standing_before/after/start
	# itself, computed the same way _show_report() would, or setup() crashes on a
	# missing key. Before-standing is cfg.standing_start: this is shift 1, so
	# nothing has touched the meter yet.
	var over: Dictionary = r0.duplicate()
	over["margin_banked"] = int(r0["quota"]) + 900
	over["made_quota"] = true
	over["standing_delta"] = roundi(
		900.0 / float(r0["quota"]) * _run.cfg.standing_heal_scale)
	_set_standing_keys(over, _run.cfg.standing_start)
	panel.setup(over)
	_check("and announces the bonus when there is one (%s)" % panel._bonus.text,
		panel._bonus.text.contains("$900") and panel._bonus.text.contains("bonus"))
	var r0_shown: Dictionary = r0.duplicate()
	_set_standing_keys(r0_shown, _run.cfg.standing_start)
	panel.setup(r0_shown)

func _set_standing_keys(r: Dictionary, standing_before: int) -> void:
	r["standing_before"] = standing_before
	r["standing_after"] = clampi(
		standing_before + int(r["standing_delta"]), 0, _run.cfg.standing_start)
	r["standing_start"] = _run.cfg.standing_start

## The audited bug: the Column VBox wanted more height than the 48px margins
## leave inside a 1080-tall viewport, so DoneButton rendered 63px below the
## bottom edge with the real starter deck already in the shop - no retuning
## needed to reach it. A Control is never given less than its own reported
## minimum, anchors or not, so an oversized child forces its ancestors to grow
## past the viewport rather than clipping - which is exactly why this has to be
## measured in pixels rather than inferred from the tree.
func _check_shop_layout_fits_on_screen() -> void:
	var done_btn := _root._shop_view.get_node(^"Margin/Column/DoneButton") as Control
	var log_label := _root._shop_view.get_node(^"Margin/Column/LogLabel") as Control
	_check("the shop has a deck to show (%d cards)" % _run.deck.cards.size(),
		_run.deck.cards.size() > 0)
	_on_screen("the shop's Done button",
		Rect2(done_btn.global_position, done_btn.size))
	_on_screen("the shop's log label",
		Rect2(log_label.global_position, log_label.size))

func _on_screen(label: String, r: Rect2) -> void:
	_check("%s is on screen (%s)" % [label, r],
		r.position.x >= 0.0 and r.position.y >= 0.0
			and r.end.x <= VIEWPORT.x and r.end.y <= VIEWPORT.y)

func _phase_2_buy_and_leave() -> void:
	# Buy the cheapest thing on the shelf, with the money to afford it.
	var shop: Shop = _root._shop_view._shop
	_run.money = 100000
	_root._shop_view._render()
	var bought: CardDef = shop.offers[0]
	var uids_before := {}
	var same_def_uids_before := {}
	for c in _run.deck.cards:
		uids_before[c.uid] = true
		if c.card == bought:
			same_def_uids_before[c.uid] = true
	var res := shop.buy(bought)
	_check("bought %s (%s)" % [bought.display_name, res.msg], res.ok)
	_check("the deck grew", _run.deck.cards.size() == _deck_before + 1)

	# Pin down exactly which instance the purchase created, by uid - not by
	# assuming Deck.add() appends, and not by matching CardDef alone, which an
	# old copy already in the deck would satisfy just as well.
	var new_uids: Array = []
	for c in _run.deck.cards:
		if not uids_before.has(c.uid):
			new_uids.append(c.uid)
	_check("the purchase created exactly one new instance", new_uids.size() == 1)
	var new_uid = new_uids[0] if new_uids.size() == 1 else null
	_check("its uid is distinct from any pre-existing copy of the same card",
		new_uid != null and not same_def_uids_before.has(new_uid))

	_root._shop_view.done.emit()
	_check("leaving the shop opens the floor again", not _root._shop_view.visible)
	_check("on a shift that knows which one it is",
		_root._shift_view._shift.shift_number == 2)
	_check("running to the climbing quota",
		_root._shift_view._shift.quota == _run.quota_for(2))

	# The point of the whole milestone: the purchase came to work with you.
	# Match on the exact uid the purchase minted, not just the CardDef - an
	# old copy of the same card already in the deck would satisfy that and
	# pass even if the new instance never made it into the shift at all.
	var uids := {}
	for c in _root._shift_view._shift.draw:
		uids[c.uid] = true
	for c in _root._shift_view._shift.hand:
		uids[c.uid] = true
	_check("and the card you bought is in the shift's deck",
		new_uid != null and uids.has(new_uid))

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
	var button_text: String = report._restart.text.to_lower()
	if s.shift_number >= s.cfg.shifts_in_run:
		_check("and its button no longer says Continue on the last shift (%s)"
			% report._restart.text, not button_text.contains("continue"))
	else:
		_check("and its button still says Continue mid-run (%s)"
			% report._restart.text, button_text.contains("continue"))
	report.continue_pressed.emit()

func _check(label: String, ok: bool) -> void:
	_checks += 1
	if not ok:
		_failures.append(label)
