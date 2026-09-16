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
		_check_clicking_a_shelf_card_buys_it()
		_check_the_deck_row_shows_exactly_the_random_upgrade_offers()
		_check_clicking_a_deck_card_opens_its_detail()
		_check_debug_add_money_key_works()
		_check_shift_label_tap_target_adds_money_too()
		_check_build_badge_is_always_on_screen("in the shop")
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
	_check_build_badge_is_always_on_screen("on the floor")
	# The debug money key is guarded on the shop's own visibility, not a
	# lifecycle flag - pressing it here (shop hidden, _shop not even set up
	# yet) must be a complete no-op, or the guard is decorative.
	var money_before_debug_press: int = _run.money
	var debug_ev := InputEventKey.new()
	debug_ev.keycode = KEY_M
	debug_ev.ctrl_pressed = true
	debug_ev.pressed = true
	_root._shop_view._unhandled_input(debug_ev)
	_check("and Ctrl+M does nothing while the shop is hidden",
		_run.money == money_before_debug_press)
	_check("and the shift's HUD with it",
		(_root._shift_view.get_node(^"HUD") as CanvasLayer).visible)

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
	var shelf_row := _root._shop_view.get_node(^"%ShelfRow") as Control
	var deck_row := _root._shop_view.get_node(^"%DeckRow") as Control
	_check("the shop has a deck to show (%d cards)" % _run.deck.cards.size(),
		_run.deck.cards.size() > 0)
	_on_screen("the shop's Done button",
		Rect2(done_btn.global_position, done_btn.size))
	_on_screen("the shop's log label",
		Rect2(log_label.global_position, log_label.size))
	_on_screen("the shelf row", Rect2(shelf_row.global_position, shelf_row.size))
	_on_screen("the deck row", Rect2(deck_row.global_position, deck_row.size))
	var shelf_rect := Rect2(shelf_row.global_position, shelf_row.size)
	var deck_rect := Rect2(deck_row.global_position, deck_row.size)
	var done_rect := Rect2(done_btn.global_position, done_btn.size)
	_check("the shelf row does not overlap the deck row (%s vs %s)"
		% [shelf_rect, deck_rect], not shelf_rect.intersects(deck_rect))
	_check("and the deck row does not overlap the Done button (%s vs %s)"
		% [deck_rect, done_rect], not deck_rect.intersects(done_rect))
	# Exactly touching the bottom margin is "on screen" by one pixel, the same
	# gap that let the shop preview hug the right margin with nothing to
	# spare - real slack, not a coincidence of exactly fitting.
	var bottom_clearance: float = VIEWPORT.y - done_rect.end.y
	_check("and the Done button has real clearance from the bottom margin,"
		+ " not just barely fitting (%d px clear)" % int(bottom_clearance),
		bottom_clearance >= 20.0)

	# The reported bug, and its real cause: TextureRect.expand_mode defaults
	# to EXPAND_KEEP_SIZE, which floors a TextureRect's own minimum size at
	# its texture's native resolution (500x700) no matter what its parent's
	# actual box is - so the inner TextureRect never actually shrank to this
	# card's real size, and rendered at ~2x scale, anchored top-left, right
	# and bottom cropped off (title text truncated mid-word) once
	# clip_contents (needed for a DIFFERENT bug - the same oversized render
	# painting over the Done button below it) started cropping the overflow
	# instead of letting it spill. Both symptoms trace to one missed
	# property; clip_contents alone only hid the first one.
	#
	# This was never a "can only be seen once a real renderer draws the
	# frame" problem - every prior check here measured Control rects, never
	# the child TextureRect's own .size, which is exactly where this was
	# visible the whole time.
	for row in [shelf_row, deck_row]:
		for slot in row.get_children():
			var card := slot.get_child(0) as Control
			_check("%s's card clips its own content, so a render quirk can never"
				% slot.name + " paint past its box (%s)" % card.name, card.clip_contents)
			var texture := card.get_node(^"TextureRect") as TextureRect
			_check("%s's card texture actually shrank to its box, not stuck at"
				% slot.name + " its native 500x700 (expand_mode=%d, size=%s)"
					% [texture.expand_mode, texture.size],
				texture.expand_mode == TextureRect.EXPAND_IGNORE_SIZE
					and texture.size.x < 300.0)

## "Ensure each build shows the build number in the bottom right so I can
## know if it's the right one" - checked once per screen, since the whole
## point of living in run.tscn rather than either screen is surviving the
## switch between them.
func _check_build_badge_is_always_on_screen(where: String) -> void:
	var badge := _root.get_node(^"BuildBadge/BuildLabel") as Label
	_check("the build badge names a real build, %s (%s)" % [where, badge.text],
		not badge.text.is_empty())
	_on_screen("the build badge %s" % where,
		Rect2(badge.global_position, badge.size))

func _on_screen(label: String, r: Rect2) -> void:
	_check("%s is on screen (%s)" % [label, r],
		r.position.x >= 0.0 and r.position.y >= 0.0
			and r.end.x <= VIEWPORT.x and r.end.y <= VIEWPORT.y)

## "Reduce the number of upgrade options in the shop to a random selection" -
## before this, every un-upgraded card with a real upgrade to sell got a row,
## unconditionally. Counts the actual card slots the screen built, not the
## model's own upgrade_offers array, so this fails if shop_screen.gd's render
## loop and Shop's random draw ever disagree about which cards are shown.
func _check_the_deck_row_shows_exactly_the_random_upgrade_offers() -> void:
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

	var deck_row := shop_view.get_node(^"%DeckRow") as HBoxContainer
	_check("rendered exactly as many deck slots as were actually offered (%d)"
		% deck_row.get_child_count(), deck_row.get_child_count() == shop.upgrade_offers.size())
	_check("which is capped at the configured slot count, not the whole deck",
		deck_row.get_child_count() <= _run.cfg.shop_upgrade_slots)

## "Show the card itself. When you click, it opens up the card, shows the
## upgraded card and also has a button for removing from deck" - the literal
## ask, end to end: click a deck slot, the detail overlay opens showing both
## faces and the right prices, upgrading applies and closes it, and the row
## behind it reflects the change once it does.
func _check_clicking_a_deck_card_opens_its_detail() -> void:
	var shop_view = _root._shop_view
	var shop: Shop = shop_view._shop
	var detail: ShopCardDetail = shop_view.get_node(^"%Detail")
	_check("the detail overlay starts hidden", not detail.visible)

	var deck_row := shop_view.get_node(^"%DeckRow") as HBoxContainer
	_check("there is a deck slot to click", deck_row.get_child_count() > 0)
	if deck_row.get_child_count() == 0:
		return

	var uid: int = shop.upgrade_offers[0]
	var inst := shop.find(uid)
	var card := deck_row.get_child(0).get_child(0) as ShopCardButton
	card.pressed.emit()
	_check("clicking the deck card opens the detail overlay", detail.visible)
	_check("titled after the card that was clicked (%s)" % detail._title.text,
		detail._title.text == inst.card.display_name)
	_check("showing the card's current face (%s)" % detail._current._name.text,
		detail._current._name.text == inst.card.display_name)
	_check("and its upgraded face, in the appeal colour (%s)"
		% detail._upgraded._name.get_theme_color("font_color"),
		detail._upgraded._name.get_theme_color("font_color") == Palette.color(&"appeal"))
	for side in [["current", detail._current], ["upgraded", detail._upgraded]]:
		var texture := (side[1] as CardPreview2D).get_node(^"TextureRect") as TextureRect
		_check("the detail's %s card texture actually shrank to its box (expand_mode=%d, size=%s)"
			% [side[0], texture.expand_mode, texture.size],
			texture.expand_mode == TextureRect.EXPAND_IGNORE_SIZE and texture.size.x < 300.0)
	_check("with a real upgrade price on the button (%s)" % detail._upgrade_btn.text,
		detail._upgrade_btn.text == "upgrade %s" % Format.money(shop.upgrade_price(inst)))
	_check("and a real drop price on the other one (%s)" % detail._remove_btn.text,
		detail._remove_btn.text == "remove %s" % Format.money(shop.remove_price()))

	# money is plentiful from here on - phase 2 resets it before its own
	# purchase, so spending some proving upgrade/remove work costs nothing
	# later.
	_run.money = 999999
	var was_upgraded := inst.upgraded
	detail._upgrade_btn.pressed.emit()
	_check("pressing upgrade actually upgrades the card", inst.upgraded and not was_upgraded)
	_check("and closes the overlay", not detail.visible)

	# A second card, so removing one does not undo the upgrade this same
	# check just proved - upgrade_offers is capped at shop_upgrade_slots
	# (>= 2 per shift_config.tres), and the eligibility check above already
	# proved there are more eligible cards than slots this seed.
	if shop.upgrade_offers.size() > 1:
		var deck_size_before_drop := _run.deck.cards.size()
		var drop_uid: int = shop.upgrade_offers[1]
		# The row rebuilds after the upgrade above, but in the SAME order -
		# it walks shop.upgrade_offers itself, which is rolled once and never
		# reshuffled - so index 1 is still this uid's slot.
		deck_row = shop_view.get_node(^"%DeckRow") as HBoxContainer
		var drop_card := deck_row.get_child(1).get_child(0) as ShopCardButton
		drop_card.pressed.emit()
		_check("clicking a second deck card opens its own detail", detail.visible)
		var drop_price := shop.remove_price()
		detail._remove_btn.pressed.emit()
		_check("pressing remove actually drops the card (%d -> %d, price %s)"
			% [deck_size_before_drop, _run.deck.cards.size(), Format.money(drop_price)],
			_run.deck.cards.size() == deck_size_before_drop - 1
				and shop.find(drop_uid) == null)
		_check("and closes the overlay too", not detail.visible)

## Ctrl+M, shop only: +$10,000 for testing purchases without grinding a run
## out first. Guarded on the shop actually being the visible screen, since
## ShopScreen has no active/inactive lifecycle hook telling it to stop
## listening the way ShiftController's set_active() does.
func _check_debug_add_money_key_works() -> void:
	var shop_view = _root._shop_view
	var before: int = shop_view._shop.run.money
	var ev := InputEventKey.new()
	ev.keycode = KEY_M
	ev.ctrl_pressed = true
	ev.pressed = true
	shop_view._unhandled_input(ev)
	_check("Ctrl+M adds $10,000 while the shop is open (%d -> %d)"
		% [before, shop_view._shop.run.money], shop_view._shop.run.money == before + 10000)

## Mobile has no Ctrl+M - the quota line itself is an invisible tap target
## wired to the identical effect.
func _check_shift_label_tap_target_adds_money_too() -> void:
	var shop_view = _root._shop_view
	var before: int = shop_view._shop.run.money
	var tap := shop_view.get_node(^"%ShiftTapTarget") as Button
	tap.pressed.emit()
	_check("tapping the quota line adds $10,000 too (%d -> %d)"
		% [before, shop_view._shop.run.money], shop_view._shop.run.money == before + 10000)

## "Show the card itself... click the card itself" - the shelf's own answer,
## distinct from the deck browser's click-to-open: buying is a single click,
## no detail overlay involved.
func _check_clicking_a_shelf_card_buys_it() -> void:
	var shop_view = _root._shop_view
	var shop: Shop = shop_view._shop
	var shelf_row := shop_view.get_node(^"%ShelfRow") as HBoxContainer
	_check("there is a shelf card to click", shelf_row.get_child_count() > 0)
	if shelf_row.get_child_count() == 0:
		return
	var offered := shop.offers[0]
	var was_affordable := shop.run.money
	shop.run.money = 999999
	var before := _run.deck.cards.size()
	var card := shelf_row.get_child(0).get_child(0) as ShopCardButton
	card.pressed.emit()
	_check("clicking the shelf card buys %s (deck %d -> %d)"
		% [offered.display_name, before, _run.deck.cards.size()],
		_run.deck.cards.size() == before + 1)
	shop.run.money = was_affordable   # leave phase 2 its own accounting

func _phase_2_buy_and_leave() -> void:
	# Buy the cheapest thing on the shelf, with the money to afford it.
	var shop: Shop = _root._shop_view._shop
	_run.money = 100000
	_root._shop_view._render()
	var bought: CardDef = shop.offers[0]
	var deck_before_this_purchase := _run.deck.cards.size()
	var uids_before := {}
	var same_def_uids_before := {}
	for c in _run.deck.cards:
		uids_before[c.uid] = true
		if c.card == bought:
			same_def_uids_before[c.uid] = true
	var res := shop.buy(bought)
	_check("bought %s (%s)" % [bought.display_name, res.msg], res.ok)
	_check("the deck grew", _run.deck.cards.size() == deck_before_this_purchase + 1)

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
