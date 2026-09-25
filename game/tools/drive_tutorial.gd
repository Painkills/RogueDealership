extends SceneTree
## Drives the practice shift on the real run.tscn, memo by memo: boots into it
## the first time, advances only when the thing each memo asks for has really
## happened on the table, never points at something the memo itself is
## covering, and hands over to the picker - remembered - when it is done.
##
##   godot --headless --path game --script res://tools/drive_tutorial.gd
##
## A live driver like drive_shift.gd and drive_run.gd, and for the same reason:
## the coach watches a real floor, and only a real scene tree has one.

const PROGRESS := "user://drive_tutorial_progress.cfg"

var _root: Node
var _coach: TutorialCoach
var _floor
var _failures: Array[String] = []
var _checks := 0

func _init() -> void:
	seed(20260924)
	# Its own progress file, so this never reads or clobbers a real player's.
	TutorialProgress.path = PROGRESS
	TutorialProgress.reset()
	_boot()
	_drive.call_deferred()

func _boot() -> void:
	_root = (load("res://scenes/run.tscn") as PackedScene).instantiate()
	get_root().add_child(_root)

func _drive() -> void:
	await _frames(3)
	_coach = _root._coach
	_floor = _root._shift_view

	_check("the first boot opens on the practice shift, not the picker",
		_coach.is_running() and not _root._picker_view.visible)
	_check("on the real floor", (_floor.get_node(^"HUD") as CanvasLayer).visible)
	var shift: Shift = _floor.current_shift()
	_check("with one chair", shift.chairs.size() == 1)
	_check("memo 1 is the welcome", _coach.step_id() == &"welcome")
	_check("and it frames nothing yet", _coach._highlight.rects().is_empty())

	await _next(&"customer")
	await _check_it_points_at_something("the customer")

	# The other two desks have nobody at them in practice - clicking one must
	# be scenery, not a peek at nobody or a "No such chair." in the log.
	var logged: int = _floor._event_log.get_parsed_text().length()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	for i in 2:
		_floor._on_pad_input(null, click, Vector3.ZERO, Vector3.ZERO, 0, 1)
	_check("clicking an empty desk goes nowhere", shift.at == null)
	_check("and says nothing about it",
		_floor._event_log.get_parsed_text().length() == logged)
	_check("an empty desk's file has no photo clipped to it",
		not _floor._customer_cards[1]._photo.visible)
	_check("while the customer's does", _floor._customer_cards[0]._photo.visible)

	await _next(&"details")
	_check("the details memo waits for you - no NEXT to skip it", not _coach._next.visible)
	_floor._on_customer_hover(0)
	await _settle()
	_check("turning their card over moves it on", _coach.step_id() == &"sit")
	_floor._on_customer_unhover(0)

	_floor._apply(shift.approach(0))
	await _settle()
	_check("sitting down moves it on", _coach.step_id() == &"hand")
	await _check_it_points_at_something("your hand")

	await _next(&"dig")
	var ticks_before: int = shift.tick
	_floor._apply(shift.dig(_index_of(shift, &"gap")))
	await _settle()
	_check("digging moves it on", _coach.step_id() == &"clock")
	_check("and the dig really did cost a tick (%d -> %d)" % [ticks_before, shift.tick],
		shift.tick == ticks_before + 1)
	await _check_it_points_at_something("the clock")

	await _next(&"place")
	var product := _index_of(shift, &"vsc")
	_check("the scripted product is still in hand to place", product >= 0)
	_floor._apply(shift.play_card(product))
	await _settle()
	_check("placing a product moves it on", _coach.step_id() == &"meter")
	var c: Customer = shift.chairs[0]
	_check("and their Line was tuned to it (appeal %d, Line %d)"
		% [c.offer.appeal, c.line], c.line == c.offer.appeal + Tutorial.LINE_GAP)
	_check("with a real Appeal in the meter to look at (%d)" % c.offer.appeal,
		c.offer.appeal >= 20)
	await _check_it_points_at_something("the product's sheet")

	await _next(&"support")
	# The wrong card on purpose - Small Talk buys patience, not Appeal. The
	# lesson should carry on regardless, and then say why the offer failed.
	_floor._apply(shift.play_card(_index_of(shift, &"smalltalk")))
	await _settle()
	_check("any support card moves it on", _coach.step_id() == &"offer")
	_floor._on_offer()
	await _settle()
	_check("an offer that falls short does not", _coach.step_id() == &"offer")
	_check("but the memo says why (%s)" % _coach._hint.text,
		_coach._hint.visible and _coach._hint.text.contains("Explain the Product"))
	_floor._apply(shift.play_card(_index_of(shift, &"explain")))
	_floor._on_offer()
	await _settle()
	_check("with Explain on it, the offer sells and moves it on",
		_coach.step_id() == &"close")
	await _check_it_points_at_something("the CLOSE button")

	_floor._on_close()
	await _settle()
	_check("signing them moves it on", _coach.step_id() == &"done")
	_check("the last memo's button says where it goes (%s)" % _coach._next.text,
		_coach._next.text == "START MY FIRST SHIFT")
	_check("and there is nothing left to skip", not _coach._skip.visible)
	var run: RunState = _root._run
	_check("practice never touched the run's deck",
		run.deck.cards.size() == Deck.build_starting(run.card_pool).cards.size())

	await _next(&"")
	_check("finishing hands over to the picker", _root._picker_view.visible)
	_check("and packs the floor away", not (_floor.get_node(^"HUD") as CanvasLayer).visible)
	_check("and the coach", not _coach.visible and not _coach.is_running())
	_check("and is remembered", TutorialProgress.is_done())
	_check("with the run still waiting on its first shift", run.shift_number == 1)

	# HOW TO PLAY replays it, and SKIP gets straight back out.
	_root._picker_view.tutorial_requested.emit()
	await _frames(2)
	_check("HOW TO PLAY replays it", _coach.is_running() and _coach.step_id() == &"welcome")
	_coach._skip.pressed.emit()
	await _frames(2)
	_check("and SKIP goes straight back to the picker",
		_root._picker_view.visible and not _coach.is_running())

	# A second boot, once it has been seen, goes straight to the picker.
	_root.queue_free()
	await _frames(2)
	_boot()
	await _frames(3)
	_check("once it is done, the game boots straight to the picker",
		_root._picker_view.visible and not _root._coach.is_running())

	TutorialProgress.reset()
	_report()

func _next(expect: StringName) -> void:
	_coach._next.pressed.emit()
	await _settle()
	if expect != &"":
		_check("NEXT moves on to %s" % expect, _coach.step_id() == expect)

## The memo points at the thing it is talking about - on screen, and never
## underneath the memo itself.
func _check_it_points_at_something(what: String) -> void:
	await _frames(2)
	var rects: Array[Rect2] = _coach._highlight.rects()
	_check("the memo about %s frames it" % what, not rects.is_empty())
	var screen := Rect2(Vector2.ZERO, Vector2(1920, 1080))
	var memo: Rect2 = _coach.memo_rect()
	for r in rects:
		_check("on screen (%s)" % r, screen.intersects(r))
		_check("and clear of the memo (%s vs %s)" % [r, memo], not r.intersects(memo))

## Tweens run on real time and this runs as fast as frames come, so step them
## to their ends - the same fast-forward drive_shift.gd's own _settle() does -
## then give the coach a couple of frames to notice.
func _settle() -> void:
	for i in 3:
		var t = _floor._framing_tween
		if t != null and t.is_valid() and t.is_running():
			t.custom_step(5.0)
		for flip in _floor._customer_flips:
			var ft = flip._tween
			if ft != null and ft.is_valid() and ft.is_running():
				ft.custom_step(5.0)
		for card in _floor._offer_details + _floor._customer_details:
			var st = card._slide_tween
			if st != null and st.is_valid() and st.is_running():
				st.custom_step(5.0)
		for zone in _floor._all_zones():
			for card in zone.cards:
				var pt = card.position_tween
				if pt != null and pt.is_valid() and pt.is_running():
					pt.custom_step(5.0)
		await process_frame

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _index_of(s: Shift, id: StringName) -> int:
	for i in range(s.hand.size()):
		if s.hand[i].card.id == id:
			return i
	return -1

func _report() -> void:
	print("")
	const EXPECTED_MIN := 30
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

func _check(label: String, ok: bool) -> void:
	_checks += 1
	if not ok:
		_failures.append(label)
