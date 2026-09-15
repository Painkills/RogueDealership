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
		_check_hovering_a_shop_row_previews_its_card()
		_check_only_the_random_offer_gets_an_upgrade_button()
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
	# The total wipeout costs standing too - but not all of it, so the run must
	# have SURVIVED to reach shift 2 at all. This is also where a stale _run
	# reference (the exact bug class this project has already caught once - a
	# controller quietly rolling a fresh RunState out from under a held
	# reference) would surface: if this landed on 0, either the formula drifted
	# or is_over() ended the run early and everything past this point is
	# checking a dead object.
	#
	# The exact number is not hardcoded here: this driver digs the clock away
	# and helps nobody, so every seated customer's patience runs out well
	# before the 24-tick bell regardless of exactly how the archetype pool or
	# patience numbers get retuned later - asserting against report()'s own
	# standing_delta proves finish_shift() applied EXACTLY what the shift
	# computed, which is the actual integration point worth checking, rather
	# than a magic number this specific play pattern happens to produce today.
	_check("at least one customer walked out along the way (%d)"
		% int(r0["customers_walked"]), int(r0["customers_walked"]) > 0)
	var expected_standing: int = clampi(
		_run.cfg.standing_start + int(r0["standing_delta"]), 0, _run.cfg.standing_start)
	_check("the wipeout (and walkouts) cost standing (%d) but did not end the run"
		% _run.standing, _run.standing == expected_standing and not _run.is_over())
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
	var preview := _root._shop_view.get_node(^"%CardPreview") as Control
	_check("the shop has a deck to show (%d cards)" % _run.deck.cards.size(),
		_run.deck.cards.size() > 0)
	_on_screen("the shop's Done button",
		Rect2(done_btn.global_position, done_btn.size))
	_on_screen("the shop's log label",
		Rect2(log_label.global_position, log_label.size))
	_on_screen("the shop's card preview",
		Rect2(preview.global_position, preview.size))
	# Technically on screen is not the same bar as actually visible: an
	# unbounded LeftColumn once stretched a single line of button text across
	# 1500+ px and left the preview a bare 260px sliver hugging the right
	# margin with zero pixels of clearance - "on screen" by one pixel is not
	# a hover preview anyone would notice. 200px of clear space is a real
	# gutter, not a coincidence of exactly fitting.
	var clearance: float = VIEWPORT.x - (preview.global_position.x + preview.size.x)
	_check("and has real clearance from the edge, not just barely fitting (%d px clear)"
		% int(clearance), clearance >= 200.0)
	# The reported bug: on the Web (gl_compatibility) renderer specifically,
	# CardPreview2D's SubViewport-fed TextureRect painted past its own 260x364
	# box and over the Done button below it, even though every Control rect
	# involved measures correctly right here - a rendering-backend quirk this
	# geometry can never see, since it only exists once GLES actually draws
	# the frame. clip_contents is the one property that forecloses it
	# regardless of cause, so it is the one thing left to assert.
	_check("and clips its own content, so a render quirk can never paint past its box",
		preview.clip_contents)

func _on_screen(label: String, r: Rect2) -> void:
	_check("%s is on screen (%s)" % [label, r],
		r.position.x >= 0.0 and r.position.y >= 0.0
			and r.end.x <= VIEWPORT.x and r.end.y <= VIEWPORT.y)

## "Ensure that on hover, you can see each card show up in the shop" - the
## literal ask. Emitting the signal directly rather than moving a real mouse,
## the same way drive_shift.gd drives hover on the floor: it invokes the exact
## callback a real hover fires, without needing real pointer motion to do it.
func _check_hovering_a_shop_row_previews_its_card() -> void:
	var shop_view = _root._shop_view
	var preview: CardPreview2D = shop_view._preview
	_check("nothing hovered yet, so the preview invites rather than guesses",
		preview._name.text == "hover a card")

	var offer_rows: Array = shop_view._offer_rows.get_children()
	_check("there is an offer row to hover", offer_rows.size() > 0)
	if offer_rows.size() > 0:
		var first_offer: Button = offer_rows[0]
		first_offer.mouse_entered.emit()
		_check("hovering the offer shows its own card (%s)" % preview._name.text,
			preview._name.text == shop_view._shop.offers[0].display_name)
		first_offer.mouse_exited.emit()
		_check("and looking away clears it", preview._name.text == "hover a card")

	var deck_rows: Array = shop_view._deck_rows.get_children()
	_check("there is a deck row to hover", deck_rows.size() > 0)
	if deck_rows.size() > 0:
		var first_row: HBoxContainer = deck_rows[0]
		var first_card: CardInstance = _run.deck.cards[0]
		_check("the row really does take hover (mouse_filter=%d, not IGNORE)"
			% first_row.mouse_filter, first_row.mouse_filter != Control.MOUSE_FILTER_IGNORE)
		first_row.mouse_entered.emit()
		_check("hovering a deck row shows THAT card (%s vs %s)"
			% [preview._name.text, first_card.card.display_name],
			preview._name.text == first_card.card.display_name)
		first_row.mouse_exited.emit()
		_check("and it clears again", preview._name.text == "hover a card")

## "Reduce the number of upgrade options in the shop to a random selection" -
## before this, every un-upgraded card with a real upgrade to sell got a
## button, unconditionally. Counts the actual Button nodes the screen built,
## not the model's own upgrade_offers array, so this fails if shop_screen.gd's
## gate and Shop's random draw ever disagree about which cards are offered.
func _check_only_the_random_offer_gets_an_upgrade_button() -> void:
	var shop_view = _root._shop_view
	var shop: Shop = shop_view._shop
	var eligible_uncapped := 0
	for inst in _run.deck.cards:
		if not inst.upgraded and shop.upgrade_gain(inst) > 0:
			eligible_uncapped += 1
	_check("the starter deck has more upgradeable cards than the slot count,"
		+ " or this proves nothing (%d eligible, %d slots)"
			% [eligible_uncapped, _run.cfg.shop_upgrade_slots],
		eligible_uncapped > _run.cfg.shop_upgrade_slots)

	var upgrade_buttons := 0
	for row in shop_view._deck_rows.get_children():
		for child in (row as HBoxContainer).get_children():
			if child is Button and (child as Button).text.begins_with("upgrade "):
				upgrade_buttons += 1
	_check("rendered exactly as many upgrade buttons as were actually offered (%d)"
		% upgrade_buttons, upgrade_buttons == shop.upgrade_offers.size())
	_check("which is capped at the configured slot count, not the whole deck",
		upgrade_buttons <= _run.cfg.shop_upgrade_slots)

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
	_check_report_card_fits_the_worst_case(report)
	report.continue_pressed.emit()

## Font-metric arithmetic, not pixel geometry read off a frame that might not
## have resorted yet - CenterContainer/PanelContainer layout is deferred the
## same way build_shop_scene.gd's own comment on DoneButton documents, and this
## runs synchronously inside the same frame that just made the report visible.
## Measured against the WORST case the report can actually show - long dollar
## figures, every branch that adds a line active at once - through panel's own
## setup(), not a second copy of its formatting written here.
func _check_report_card_fits_the_worst_case(report) -> void:
	var worst: Dictionary = {
		"margin_banked": 12345678, "quota": 9876543, "made_quota": false,
		"customers_seen": 999, "customers_signed": 999, "customers_walked": 999,
		"offers": 9999, "sales": 9999, "close_rate": 0.999, "failed_offers": 9999,
		"margin_conceded": 1234567, "margin_padded": 1234567,
		"margin_bonus": 1234567, "margin_lost_to_walks": 1234567,
		"margin_lost_to_closing": 1234567, "standing_delta": -100,
		"standing_lost_to_walkouts": 100,
	}
	_set_standing_keys(worst, 100)
	var was := {}
	for key in ["title", "banked", "bonus", "standing", "walkouts", "customers",
			"offers", "margin", "lost"]:
		was[key] = report.get("_" + key).text
	report.setup(worst)

	var card := report.get_node(^"CenterWrap/Card") as Control
	var vbox := card.get_node(^"CardMargin/VBoxContainer") as VBoxContainer
	var width: float = 900.0 - 56.0 - 56.0   # Card's own width minus CardMargin
	var total := 0.0
	var shown := 0
	for child in vbox.get_children():
		shown += 1
		if child is Label:
			var l := child as Label
			total += l.get_theme_font("font").get_multiline_string_size(
				l.text, HORIZONTAL_ALIGNMENT_LEFT, width,
				l.get_theme_font_size("font_size")).y
		else:
			total += maxf((child as Control).custom_minimum_size.y, 0.0)
	if shown > 1:
		total += float(vbox.get_theme_constant("separation") * (shown - 1))
	total += 56.0 + 56.0   # CardMargin top + bottom
	_check("the report card fits a 1080-tall viewport even at its wordiest (%d px)"
		% int(total), total <= 1080.0)

	# Leave the panel showing what the real shift actually produced, not the
	# synthetic worst case - nothing downstream expects to see 12345678 again.
	for key in was:
		report.get("_" + key).text = was[key]

func _check(label: String, ok: bool) -> void:
	_checks += 1
	if not ok:
		_failures.append(label)
