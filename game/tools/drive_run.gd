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
## The two cards the first visit to the store added - the one on the house and
## the one bought - by uid, so the next shift can be checked for exactly those
## instances rather than any old copy of the same card.
var _taken_uid: int = -1
var _bought_uid: int = -1

const PROFILE := "user://drive_run_profile.cfg"

## Every error the engine reports while the run is driven - see ErrorTrap.
var _trap := ErrorTrap.new()

func _init() -> void:
	OS.add_logger(_trap)
	seed(20260905)
	_root = (load("res://scenes/run.tscn") as PackedScene).instantiate()
	# This driver tests the run, not the title screen in front of it (that is
	# tools/drive_tutorial.gd's job) - so it boots straight to the picker.
	_root.title_at_boot = false
	# Its own profile, so the runs this plays are never filed among a real
	# player's personal bests.
	PlayerProfile.path = PROFILE
	PlayerProfile.reset()
	# Nor ever posted to the real shared board.
	Leaderboard.offline = true
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
		# After a MIDDAY shift: the free pick first, then the store it stocks.
		_check_shop_layout_fits_on_screen()
		_check_the_view_deck_button_shows_the_whole_deck()
		_check_the_free_card_is_on_the_house()
		_check_the_store_holds_what_the_shift_stocks()
		_check_clicking_a_shelf_card_buys_it()
		_check_debug_add_money_key_works()
		_check_shift_label_tap_target_adds_money_too()
		_check_build_badge_is_always_on_screen("in the shop")
		_phase_2_leave_and_work_a_night()
		_settle_frames = 0
		_phase = 2
		return false

	if _phase == 2:
		_settle_frames += 1
		if _settle_frames < 5:
			return false
		# After a NIGHT shift: the free pick again - passed on, this time - and
		# the store it stocks, cards of yours to upgrade among it.
		_check_shop_layout_fits_on_screen()
		_check_passing_on_the_free_pick_opens_the_store()
		_check_the_store_holds_what_the_shift_stocks()
		_check_the_deck_row_shows_exactly_the_random_upgrade_offers()
		_check_clicking_a_deck_card_opens_its_detail()
		_check_the_week_report_comes_between_weeks()
		_check_run_summary_screen_appears_at_the_end_of_a_run()
		_check_the_fired_title_is_distinct_from_a_completed_run()
		_check_the_last_fight_shortcut_stops_in_the_store_then_fights_the_boss()
		PlayerProfile.reset()
		_check("and not one error on the way (%s)" % "; ".join(_trap.errors),
			_trap.errors.is_empty())

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

## Drives the real ShiftPickerView.chosen signal, the same "through the
## actual wiring, not a direct controller call" rule every other transition
## in this driver already follows (.done, .continue_pressed). Which regular
## shift gets picked is decided by what it stocks - `score` - never by its
## name, so renaming or retuning a tier cannot break this driver.
func _pick_tier_by(score: Callable) -> ShiftProfile:
	_check("the picker is showing before a tier is chosen",
		_root._picker_view.visible)
	var best: ShiftProfile = null
	for p in (_root._profiles as ShiftProfilePool).profiles:
		if best == null or float(score.call(p)) > float(score.call(best)):
			best = p
	_check("there is a regular shift to pick", best != null)
	_root._picker_view.chosen.emit(best)
	_check("choosing %s closes the picker" % best.id, not _root._picker_view.visible)
	return best

func _phase_0_open_and_finish_shift() -> void:
	_run = _root._run
	_check("a run started", _run != null)
	_check("on shift 1", _run.shift_number == 1)
	_check_the_toolkit_opens_from_a_new_games_calendar()
	# The tier with the most for sale, for the store checks after it.
	var first := _pick_tier_by(func(p): return p.cards_for_sale)
	_check("with the floor showing, not the shop", not _root._shop_view.visible)
	# The office windows and the tablet's clock follow the shift you picked.
	_check("the floor looks out on the picked shift's own time of day (%s)"
		% _root._shift_view._windows.time_of_day(),
		_root._shift_view._windows.time_of_day() == first.worked_at())
	_check_build_badge_is_always_on_screen("on the floor")
	_check_clicking_the_draw_pile_opens_the_deck_viewer()
	_check_the_corner_button_opens_the_deck_viewer()
	_check_the_deck_viewer_hides_the_floor_side_panels()
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
	_check("with what that shift paid (%d banked, %d quota)"
		% [int(r0["margin_banked"]), int(r0["quota"])],
		_run.money == RunState.bonus_from(r0))
	# This driver digs the clock away rather than selling anything, so it always
	# lands on the missed-quota branch: the paycheck, and nothing on top.
	# The week's base salary, at the shift's own pay_scale.
	var base_pay := roundi(_run.cfg.paycheck_in_week(1) * _root._chosen_profile.pay_scale)
	_check("which after a shift that banked nothing is the paycheck alone (%d)" % base_pay,
		not bool(r0["made_quota"]) and int(r0["paycheck"]) == base_pay
			and _run.money == base_pay and _run.last_bonus == base_pay)
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
	_check("and the report panel's own pay line agrees (%s)" % panel._bonus.text,
		panel._bonus.text.contains(Format.money(base_pay))
			and panel._bonus.text.contains("short"))
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
	# What 900 over pays depends on the shift's own commission - read, not assumed.
	var paid := RunState.bonus_from(over)
	_check("and announces the pay, base and commission, when there is some (%s)" % panel._bonus.text,
		panel._bonus.text.contains(Format.money(paid)) and panel._bonus.text.contains("paycheck")
			and panel._bonus.text.contains("commission")
			and panel._bonus.text.contains(Format.money(int(over["paycheck"]))))
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
## Every screen is an app window centred on the desktop, and the run's VIEW
## TOOLKIT button sits over the top-right corner of all of them - so a window
## tall enough to reach it would put the button on top of the window's own
## title bar. Measured from the window's minimum size, which containers give
## it however deferred their layout pass is.
func _check_window_fits(what: String, window: Control) -> void:
	var h: float = maxf(window.custom_minimum_size.y, window.get_combined_minimum_size().y)
	var top: float = (VIEWPORT.y - h) * 0.5
	var corner := _root.get_node(^"BuildBadge/ViewDeckCornerButton") as Control
	var corner_bottom: float = corner.offset_bottom
	_check("%s's window fits the screen (%d px tall)" % [what, int(h)], h <= VIEWPORT.y)
	_check("and starts below the corner VIEW TOOLKIT button (top %d, button ends %d)"
		% [int(top), int(corner_bottom)], top >= corner_bottom + 4.0)

func _check_shop_layout_fits_on_screen() -> void:
	_check_window_fits("the store", _root._shop_view.get_node(^"%PortalWindow"))
	_check_window_fits("the toolkit", _root._deck_viewer.get_node(^"%DeckWindow"))
	var shop: Shop = _root._shop_view._shop
	var done_btn := _root._shop_view.get_node(^"%DoneButton") as Control
	var log_label := _root._shop_view.get_node(^"%LogLabel") as Control
	var rows := {
		"shelf row": _root._shop_view.get_node(^"%ShelfRow") as Control,
		"deck row": _root._shop_view.get_node(^"%DeckRow") as Control,
	}
	# Only the aisles this shift stocks are on the page at all.
	for row_name in rows.keys():
		if not (rows[row_name] as Control).is_visible_in_tree():
			rows.erase(row_name)
	_check("the shop has a deck to show (%d cards)" % _run.deck.cards.size(),
		_run.deck.cards.size() > 0)
	_on_screen("the shop's Done button",
		Rect2(done_btn.global_position, done_btn.size))
	_on_screen("the shop's log label",
		Rect2(log_label.global_position, log_label.size))
	for row_name in rows:
		var row: Control = rows[row_name]
		_on_screen("the %s" % row_name, Rect2(row.global_position, row.size))
	# An aisle with nothing in it says so, rather than standing empty.
	for pair in [["shelf row", shop.offers.is_empty()],
			["deck row", shop.upgrade_offers.is_empty()]]:
		if pair[1] and rows.has(pair[0]):
			var row: Node = rows[pair[0]]
			_check("an empty aisle says so (%s: %s)" % [pair[0],
				(row.get_child(0) as Label).text if row.get_child_count() == 1
					and row.get_child(0) is Label else "no note"],
				row.get_child_count() == 1 and row.get_child(0) is Label)
	# An aisle keeps one card slot's height whether it holds a card or only
	# says it is empty: buying a card must not pull the page, and the button
	# you are about to press, up the screen.
	for row_name in rows:
		var row: Control = rows[row_name]
		_check("the %s holds a card's height, full or empty (%d px)"
			% [row_name, int(row.custom_minimum_size.y)], row.custom_minimum_size.y >= 252.0)
		for slot in row.get_children():
			if _slot_card(slot) == null:
				continue
			var need: float = (slot as Control).get_combined_minimum_size().y
			_check("and that is room for a real card slot (%s needs %d of %d)"
				% [row_name, int(need), int(row.custom_minimum_size.y)],
				need <= row.custom_minimum_size.y)
	var done_rect := Rect2(done_btn.global_position, done_btn.size)
	var names: Array = rows.keys()
	for i in range(names.size()):
		var a: Control = rows[names[i]]
		var a_rect := Rect2(a.global_position, a.size)
		for j in range(i + 1, names.size()):
			var b: Control = rows[names[j]]
			var b_rect := Rect2(b.global_position, b.size)
			_check("the %s does not overlap the %s (%s vs %s)"
				% [names[i], names[j], a_rect, b_rect], not a_rect.intersects(b_rect))
		_check("and the %s does not overlap the Done button (%s vs %s)"
			% [names[i], a_rect, done_rect], not a_rect.intersects(done_rect))
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
	for row_name in rows:
		for slot in (rows[row_name] as Node).get_children():
			var card := _slot_card(slot) as Control
			if card == null:
				continue   # an empty aisle's own note, not a card slot
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
	var eligible := 0
	for inst in _run.deck.cards:
		if not inst.upgraded and shop.upgrade_gain(inst) > 0:
			eligible += 1
	var deck_row := shop_view.get_node(^"%DeckRow") as HBoxContainer
	var shown := _slots_in(deck_row)
	_check("rendered exactly as many deck slots as were actually offered (%d)" % shown,
		shown == shop.upgrade_offers.size())
	_check("which is the shift's own count, not the whole toolkit (%d of %d, %d eligible)"
		% [shown, shop.upgrades, eligible], shown == mini(shop.upgrades, eligible))

## How many real card slots a row holds - not the words an empty one shows.
func _slots_in(row: Node) -> int:
	var n := 0
	for slot in row.get_children():
		if _slot_card(slot) != null:
			n += 1
	return n

## "Show the card itself. When you click, it opens up the card, shows the
## upgraded card and also has a button for removing from deck" - the literal
## ask, end to end: click a deck slot, the detail overlay opens showing both
## faces and the right prices, upgrading applies and closes it, and the row
## behind it reflects the change once it does. Then "as many as you can
## afford": the next card along still offers its upgrade, and its drop.
func _check_clicking_a_deck_card_opens_its_detail() -> void:
	var shop_view = _root._shop_view
	var shop: Shop = shop_view._shop
	var detail: ShopCardDetail = shop_view.get_node(^"%Detail")
	_check("the detail overlay starts hidden", not detail.visible)

	var deck_row := shop_view.get_node(^"%DeckRow") as HBoxContainer
	var clickable: bool = deck_row.get_child_count() > 0 \
		and _slot_card(deck_row.get_child(0)) != null
	_check("there is a deck slot to click", clickable)
	if not clickable:
		return

	var uid: int = shop.upgrade_offers[0]
	var inst := shop.find(uid)
	var card := _slot_card(deck_row.get_child(0))
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
		detail._upgrade_btn.visible
			and detail._upgrade_btn.text == "upgrade %s" % Format.money(shop.upgrade_price(inst)))
	_check("and a real drop price on the other one (%s)" % detail._remove_btn.text,
		detail._remove_btn.text == "remove %s" % Format.money(shop.remove_price()))
	_check("and nothing to take or buy - it is already yours",
		not detail._take_btn.visible and not detail._buy_btn.visible)

	_run.money = 999999
	var was_upgraded := inst.upgraded
	detail._upgrade_btn.pressed.emit()
	_check("pressing upgrade actually upgrades the card", inst.upgraded and not was_upgraded)
	_check("and closes the overlay", not detail.visible)

	# "You can buy or upgrade as many as you can afford": the rest of the few
	# still say what upgrading them costs, and a click on one still offers it.
	if shop.upgrade_offers.size() < 2:
		print("SKIP  second-upgrade check: only one card was on offer")
		return
	deck_row = shop_view.get_node(^"%DeckRow") as HBoxContainer
	var labels: Array[String] = []
	for slot in deck_row.get_children():
		labels.append((slot.get_child(slot.get_child_count() - 1) as Label).text)
	_check("the card you upgraded reads upgraded, the rest still their price (%s)"
		% ", ".join(labels),
		labels[0] == "upgraded"
			and labels.slice(1).all(func(t): return t.begins_with("upgrade ")))
	var drop_uid: int = shop.upgrade_offers[1]
	var deck_size_before_drop := _run.deck.cards.size()
	_slot_card(deck_row.get_child(1)).pressed.emit()
	_check("clicking a second card of yours opens its own detail", detail.visible)
	_check("still offering its upgrade - as many as you can afford",
		detail._upgrade_btn.visible)
	_check("and its drop", detail._remove_btn.visible)
	var drop_price := shop.remove_price()
	detail._remove_btn.pressed.emit()
	_check("pressing remove actually drops the card (%d -> %d, price %s)"
		% [deck_size_before_drop, _run.deck.cards.size(), Format.money(drop_price)],
		_run.deck.cards.size() == deck_size_before_drop - 1
			and shop.find(drop_uid) == null)
	_check("and closes the overlay too", not detail.visible)

## "What's offered in the store depends on the shift you picked." Read back
## against that shift's own numbers, never today's tuning of them: its cards
## for sale on the shelf, and its cards of yours to upgrade.
func _check_the_store_holds_what_the_shift_stocks() -> void:
	var shop: Shop = _root._shop_view._shop
	var profile: ShiftProfile = _root._chosen_profile
	_check("the store is stocked by the %s's own numbers (%d for sale, %d to upgrade)"
		% [profile.id, shop.cards_for_sale, shop.upgrades],
		shop.cards_for_sale == profile.cards_for_sale and shop.upgrades == profile.upgrades)
	var shelf := _slots_in(_root._shop_view.get_node(^"%ShelfRow"))
	var deck := _slots_in(_root._shop_view.get_node(^"%DeckRow"))
	_check("a card on the shelf for each one for sale (%d of %d)" % [shelf, shop.offers.size()],
		shelf == shop.offers.size())
	_check("and one of yours for each upgrade on offer (%d of %d)"
		% [deck, shop.upgrade_offers.size()], deck == shop.upgrade_offers.size())
	# An aisle is on the page only when the shift stocks it, and a shift that
	# stocks neither says so in their place.
	var shelf_on := (_root._shop_view.get_node(^"%ShelfSection") as Control).visible
	var deck_on := (_root._shop_view.get_node(^"%DeckSection") as Control).visible
	var empty_on := (_root._shop_view.get_node(^"%StoreEmptyNote") as Control).visible
	_check("each aisle shows only when the shift stocks it (for sale %s, upgrades %s)"
		% [shelf_on, deck_on],
		shelf_on == (shop.cards_for_sale > 0) and deck_on == (shop.upgrades > 0))
	_check("and a shift that stocks neither says so instead",
		empty_on == (shop.cards_for_sale == 0 and shop.upgrades == 0))

## The words an empty aisle shows instead of cards, or "" when it is not one.
func _note_in(row: Node) -> String:
	if row.get_child_count() == 1 and row.get_child(0) is Label:
		return (row.get_child(0) as Label).text
	return ""

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

## A shelf/deck slot is a VBoxContainer whose children now include a rarity
## Label alongside the ShopCardButton (shop_screen.gd's _build_slot) - find
## the button by type instead of assuming it sits at a fixed child index.
func _slot_card(slot: Node) -> ShopCardButton:
	for child in slot.get_children():
		if child is ShopCardButton:
			return child
	return null

## Product cells are a VBoxContainer of [Label, chip, chip, ...] (or
## [Label, CenterContainer(dash)] when empty) - extra copies stack below the
## first rather than beside it, so every ShopCardButton child past index 0 is
## a real chip. Support chips sit directly in the column - count them as-is.
## A dash placeholder (either shape, empty deck) is neither and is skipped
## for free.
func _count_deck_viewer_chips(column: GridContainer) -> int:
	var total := 0
	for child in column.get_children():
		if child is ShopCardButton:
			total += 1
		elif child is VBoxContainer:
			for sub in child.get_children():
				if sub is ShopCardButton:
					total += 1
	return total

## "I want to be able to see the cards in my deck" - reachable from two
## places (this checks the shop's own button; _check_the_draw_pile_also_opens_it
## covers the floor), a read-only browser of the WHOLE deck, not just
## ShelfRow/DeckRow's own random daily subset. Products are a square 3x3
## grid, all 9 interests always visible even at zero copies; support cards
## are just listed, one chip per copy actually owned, no per-name grouping.
func _check_the_view_deck_button_shows_the_whole_deck() -> void:
	var shop_view = _root._shop_view
	var shop: Shop = shop_view._shop
	var deck_viewer = _root._deck_viewer
	_check("the deck viewer starts hidden", not deck_viewer.visible)
	var view_btn := shop_view.get_node(^"%ViewDeckButton") as Button
	# "Replace all mentions of View deck with View Toolkit to make it
	# consistent. Change My Toolkit to View Toolkit." One name for the one
	# page, on both of the buttons that open it.
	_check("the store's button to it says VIEW TOOLKIT (%s)" % view_btn.text,
		view_btn.text == "VIEW TOOLKIT")
	_check("and so does the corner button, word for word (%s)" % _root._view_deck_btn.text,
		_root._view_deck_btn.text == view_btn.text)
	view_btn.pressed.emit()
	_check("clicking it opens the deck viewer", deck_viewer.visible)

	var products_col := deck_viewer.get_node(^"%ProductsColumn") as GridContainer
	var support_col := deck_viewer.get_node(^"%SupportColumn") as GridContainer
	# Each side's frame border echoes the kind-icon colour its own cards
	# already carry (card_face_3d.gd's _kind_icon), not a colour invented
	# just for this overlay.
	var products_frame := deck_viewer.get_node(^"%ProductsSideFrame") as PanelContainer
	var support_frame := deck_viewer.get_node(^"%SupportSideFrame") as PanelContainer
	var products_border: Color = (products_frame.get_theme_stylebox("panel") as StyleBoxFlat).border_color
	var support_border: Color = (support_frame.get_theme_stylebox("panel") as StyleBoxFlat).border_color
	_check("the products frame border matches the product kind-icon colour (%s)" % products_border,
		products_border == Palette.color(&"accent"))
	_check("the support frame border matches the support kind-icon colour, purple (%s)" % support_border,
		support_border == Palette.color(&"action"))

	var interest_count: int = shop.run.interests.count()
	_check("the product grid is square - 3 columns (%d)" % products_col.columns,
		products_col.columns == 3)
	_check("every interest gets a cell, even ones with nothing in the deck (%d cells for %d interests)"
		% [products_col.get_child_count(), interest_count],
		products_col.get_child_count() == interest_count)

	# A duplicate copy stacks DOWN inside its own cell rather than widening it
	# sideways - so every cell's reserved width (one chip, regardless of an
	# empty dash or several stacked copies) must agree, or a column would grow
	# for whichever interest happens to own a duplicate this run.
	var cell_widths: Array = []
	for child in products_col.get_children():
		cell_widths.append((child as Control).custom_minimum_size.x)
	var first_width: float = cell_widths[0]
	var all_same_width := true
	for w in cell_widths:
		if w != first_width:
			all_same_width = false
	_check("every product cell reserves the same width, empty or stacked (%s)"
		% str(cell_widths), all_same_width and first_width > 0.0)

	var support_inst_count := 0
	for inst in shop.run.deck.cards:
		if not inst.is_product():
			support_inst_count += 1
	if support_inst_count == 0:
		_check("no support cards in the deck shows a single dash, not a row per def",
			support_col.get_child_count() == 1)
	else:
		_check("support cards are just listed, one chip per copy, no row per def (%d chips for %d copies)"
			% [support_col.get_child_count(), support_inst_count],
			support_col.get_child_count() == support_inst_count)
		# The count alone can't tell a bare chip from a chip wrapped in its own
		# name label - a def-per-row regression would still add exactly one
		# child per copy. Check the shape too: every child a chip directly,
		# never a labeled cell.
		var all_bare_chips := true
		for child in support_col.get_children():
			if not (child is ShopCardButton):
				all_bare_chips = false
				break
		_check("and each one is the card itself, not a name label over it",
			all_bare_chips)

	var shown := _count_deck_viewer_chips(products_col) + _count_deck_viewer_chips(support_col)
	_check("it shows every card in the deck, not a random subset (%d shown, %d in deck)"
		% [shown, shop.run.deck.cards.size()], shown == shop.run.deck.cards.size())

	var close_btn := deck_viewer.get_node(^"%DeckCloseButton") as Button
	close_btn.pressed.emit()
	_check("closing it hides it again", not deck_viewer.visible)

## "First, you get a popup with the one out of three." It covers the store
## until you pick one: a card for each free choice, each marked FREE; clicking
## one opens the same overlay every card here uses, over the popup, with only
## a way to take it; taking it adds that very card, spends nothing, and opens
## the store behind it.
func _check_the_free_card_is_on_the_house() -> void:
	var shop_view = _root._shop_view
	var shop: Shop = shop_view._shop
	var popup := shop_view.get_node(^"%FreePick") as Control
	var row := shop_view.get_node(^"%FreePickRow") as HBoxContainer
	_check("the free pick pops up first, over the store", popup.visible and shop_view.visible)
	_check_window_fits("the free pick", shop_view.get_node(^"%FreePickWindow"))
	var slots := row.get_children().filter(func(slot): return _slot_card(slot) != null)
	_check("a card for each free choice (%d of %d)" % [slots.size(), shop.free_cards.size()],
		slots.size() == shop.free_cards.size() and slots.size() >= 2)
	if slots.size() < 2:
		return
	for slot in slots:
		var price := slot.get_child(slot.get_child_count() - 1) as Label
		_check("each marked free (%s)" % price.text, price.text == "FREE")
	# The second one - not always the first, so the pick is really a pick.
	var free: CardDef = shop.free_cards[1]
	var detail: ShopCardDetail = shop_view.get_node(^"%Detail")
	_slot_card(slots[1]).pressed.emit()
	_check("clicking one opens the overlay, titled after it (%s)" % detail._title.text,
		detail.visible and detail._title.text == free.display_name)
	_check("drawn over the popup, not under it", detail.get_index() > popup.get_index())
	_check("with a way to take it and nothing to pay",
		detail._take_btn.visible and not detail._buy_btn.visible
			and not detail._upgrade_btn.visible and not detail._remove_btn.visible)
	var money_before: int = _run.money
	var uids_before := {}
	for c in _run.deck.cards:
		uids_before[c.uid] = true
	detail._take_btn.pressed.emit()
	var added: Array = []
	for c in _run.deck.cards:
		if not uids_before.has(c.uid):
			added.append(c)
	_check("taking it adds exactly that card (%d new)" % added.size(),
		added.size() == 1 and added[0].card == free)
	_check("for nothing", _run.money == money_before)
	_check("and closes the overlay", not detail.visible)
	_check("and the popup with it, leaving the store", not popup.visible)
	if added.size() == 1:
		_taken_uid = added[0].uid
	var another: CardDef = shop.free_cards[0]
	_check("and no second free card this visit",
		not shop.take_free(another).ok and _run.deck.cards.size() == uids_before.size() + 1)

## The shelf routes through the SAME confirm-before-you-spend overlay:
## clicking the card opens it with a "buy" button, not an instant purchase -
## and "you can buy as many as you can afford", so the next goes the same way.
func _check_clicking_a_shelf_card_buys_it() -> void:
	var shop_view = _root._shop_view
	var shop: Shop = shop_view._shop
	var shelf_row := shop_view.get_node(^"%ShelfRow") as HBoxContainer
	if shop.cards_for_sale <= 0:
		print("SKIP  shelf check: no regular shift puts cards up for sale")
		return
	var stocked: bool = not shop.offers.is_empty() and _slots_in(shelf_row) == shop.offers.size()
	_check("cards for sale after that shift (%d)" % shop.offers.size(), stocked)
	if not stocked:
		return
	var offered := shop.offers[0]
	var was_affordable := shop.run.money
	shop.run.money = 999999
	var before := _run.deck.cards.size()
	var uids_before := {}
	for c in _run.deck.cards:
		uids_before[c.uid] = true
	var detail: ShopCardDetail = shop_view.get_node(^"%Detail")
	var card := _slot_card(shelf_row.get_child(0))
	card.pressed.emit()
	_check("clicking the shelf card opens the confirm overlay, not an instant buy",
		detail.visible)
	_check("titled after the card that was clicked (%s)" % detail._title.text,
		detail._title.text == offered.display_name)
	_check("the take/upgrade/remove buttons stay hidden for a card on sale",
		not detail._take_btn.visible and not detail._upgrade_btn.visible
			and not detail._remove_btn.visible)
	_check("with a real buy price on the button (%s)" % detail._buy_btn.text,
		detail._buy_btn.text == "buy %s" % Format.price(shop.buy_price(offered)))
	detail._buy_btn.pressed.emit()
	_check("pressing buy actually buys %s (deck %d -> %d)"
		% [offered.display_name, before, _run.deck.cards.size()],
		_run.deck.cards.size() == before + 1)
	_check("and closes the overlay", not detail.visible)
	for c in _run.deck.cards:
		if not uids_before.has(c.uid):
			_bought_uid = c.uid
	if not shop.offers.is_empty():
		var next_def: CardDef = shop.offers[0]
		var size_before_next := _run.deck.cards.size()
		_slot_card(shelf_row.get_child(0)).pressed.emit()
		detail._buy_btn.pressed.emit()
		_check("and the next one on the shelf too - as many as the bonus covers (%s)"
			% next_def.display_name,
			_run.deck.cards.size() == size_before_next + 1 and not shop.offers.has(next_def))
	shop.run.money = was_affordable   # leave the rest of the run its own accounting

## "Pick one, or none": the popup's "no thanks" spends the visit's pick on
## nothing and opens the store all the same.
func _check_passing_on_the_free_pick_opens_the_store() -> void:
	var shop_view = _root._shop_view
	var shop: Shop = shop_view._shop
	var popup := shop_view.get_node(^"%FreePick") as Control
	_take_any_dealership_upgrade()
	_check("the free pick pops up again after the next shift",
		popup.visible and shop.free_picks_left == 1)
	var before := _run.deck.cards.size()
	(shop_view.get_node(^"%SkipFreeButton") as Button).pressed.emit()
	_check("no thanks closes it, for the store", not popup.visible)
	_check("having taken nothing", _run.deck.cards.size() == before and shop.free_picks_left == 0)

## The picker is a calendar's week view: a column per day of the run, today's
## three shifts as events you click, and the day already worked showing the
## shift you took and how it went. Checked on the SECOND visit, the first one
## with a past to show.
func _check_the_calendar_shows_the_week() -> void:
	_check_window_fits("the calendar", _root._picker_view.get_node(^"%CalendarWindow"))
	var week: Node = _root._picker_view.get_node(^"%Week")
	var days: int = mini(_run.cfg.days_per_week, _run.cfg.shifts_in_run)
	_check("a column per day of the week, after the hours (%d)" % week.get_child_count(),
		week.get_child_count() == days + 1)
	if week.get_child_count() != days + 1:
		return
	var today: int = _today_column()   # column 0 is the hours
	var events := _todays_events()
	_check("today holds every shift you can pick (%d of %d)"
		% [events.size(), _run.todays_shifts().size()],
		events.size() == _run.todays_shifts().size() and not events.is_empty())
	var worked: Node = week.get_child(today - 1).get_child(1)
	_check("yesterday shows the shift you worked",
		worked.get_node_or_null(^"Worked") != null)
	_check("and nothing sits on the days still ahead",
		week.get_child(today + 1).get_child(1).get_child_count() == 0)
	# Clicking an event IS the choice - the same signal _pick_tier() drives.
	# The run's own handler is held off for the click, so checking the button
	# does not also start a shift (and spend the run's rolls) behind the
	# rest of this phase's back.
	var got: Array = []
	var catch := func(p): got.append(p)
	_root._picker_view.chosen.disconnect(_root._on_profile_chosen)
	_root._picker_view.chosen.connect(catch)
	if not events.is_empty():
		(events[0] as Button).pressed.emit()
	_root._picker_view.chosen.disconnect(catch)
	_root._picker_view.chosen.connect(_root._on_profile_chosen)
	_check("clicking an event chooses that shift",
		got.size() == 1 and got[0] == _run.todays_shifts()[0])
	# Every shift shows its quota and its bonus, read from its own numbers,
	# with its hours at the far right of its title row.
	var day_quota := _run.quota_for(_run.shift_number)
	for i in range(mini(events.size(), _run.todays_shifts().size())):
		var profile: ShiftProfile = _run.todays_shifts()[i]
		var words := ""
		for label in (events[i] as Node).find_children("*", "Label", true, false):
			words += (label as Label).text + " "
		var quota := profile.quota_on(day_quota)
		var rate := "%d%% commission" % roundi(profile.commission * 100.0)
		_check("%s's event shows its quota (%s) and commission (%s)"
			% [profile.id, Format.money(quota), rate],
			words.contains(Format.money(quota)) and words.contains(rate))
		var hours := (events[i] as Node).find_child("Hours", true, false) as Label
		_check("%s's hours sit at the far right of its title row" % profile.id,
			hours != null and hours.get_parent().name == "TitleRow"
				and hours.get_index() == hours.get_parent().get_child_count() - 1
				and hours.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT)

## Which of the calendar's columns is today - column 0 is the hours, and the
## calendar shows one week at a time.
func _today_column() -> int:
	return (_run.shift_number - 1) % maxi(1, _run.cfg.days_per_week) + 1

## Today's column's events, in the order the day offers them.
func _todays_events() -> Array:
	var week: Node = _root._picker_view.get_node(^"%Week")
	var out := []
	for child in week.get_child(_today_column()).get_child(1).get_children():
		if child is Button:
			out.append(child)
	return out

## "A boss day", and "a pool of shifts that can show up on other days": a
## premade shift in a tier's slot says so on the calendar, and a boss day is
## today's only shift. Dealt from a made-up pool - what ships in data/ is not
## this check's business - and the run's own week put back after.
func _check_the_calendar_shows_premade_shifts() -> void:
	var was: Week = _run.week
	var pool := ShiftProfilePool.new()
	pool.profiles = (_root._profiles as ShiftProfilePool).profiles
	var special := ShiftProfile.new()
	special.id = &"drive_special"
	special.display_name = "Drive Special"
	# Into whichever slot today's calendar actually opens - not every tier is
	# offered every day (ShiftProfile.from_day).
	var slot: StringName = was.offers(_run.shift_number)[0].worked_at()
	var category := ShiftCategory.new()
	category.slots = 1 << ShiftCategory.SLOTS.find(slot)
	# Only on today's weekday: a premade shift comes up once a week, and one
	# allowed every day would have been dealt on the week's first.
	category.days = 1 << ((_run.shift_number - 1) % maxi(1, _run.cfg.days_per_week))
	category.shifts.append(special)
	pool.categories.append(category)

	_run.week = Week.new(pool, _run.cfg.shifts_in_run, 1, _run.cfg.days_per_week)
	_root._open_the_picker()
	var events := _todays_events()
	var specials := events.filter(func(e): return e.name == "Event_drive_special")
	_check("a premade shift takes a tier's place (%d shifts, %d of it)"
		% [events.size(), specials.size()],
		events.size() == _run.todays_shifts().size() and specials.size() == 1)
	# "They're just another shift to the player. Only bosses should have a
	# differentiator."
	var special_event: Button = specials[0]
	_check("and looks like any other shift: no sticker, its hours showing",
		events.all(func(e): return e.find_child("PremadeTag", true, false) == null \
			and (e.find_child("Hours", true, false) as Label).modulate.a == 1.0))
	var slot_role := StringName("shift_%s" % slot)
	var slot_hue := Palette.color(slot_role) if Palette.ROLES.has(slot_role) \
		else Palette.color(&"primary")
	_check("in the colour of the slot it took",
		(special_event.get_theme_stylebox("normal") as StyleBoxFlat).border_color == slot_hue)
	_check("and a shift that bends no rules has no rules line",
		events.all(func(e): return e.find_child("Rules", true, false) == null))
	var shop_line := ""
	for label in special_event.find_children("*", "Label", true, false):
		if (label as Label).text.begins_with("Shop"):
			shop_line = (label as Label).text
	_check("and the shop line leaves out the free card every shift ends with (%s)" % shop_line,
		not shop_line.to_lower().contains("free card"))

	# One that bends a rule, dealt to today's difficulty with a made-up
	# complicator on top - every spare point spent on complicators, so it
	# comes with one whatever today's target is.
	special.hand_size = 4
	var twist := ShiftComplicator.new()
	twist.id = &"drive_twist"
	twist.display_text = "Drive Twist"
	twist.line_offset = 1
	pool.complicators.append(twist)
	var deal_cfg := _run.cfg.duplicate() as ShiftConfig
	deal_cfg.complicator_share = 1.0
	_run.week = Week.new(pool, _run.cfg.shifts_in_run, 1, _run.cfg.days_per_week,
		_run.archetypes, deal_cfg)
	_root._open_the_picker()
	var dealt: ShiftProfile = _run.todays_shifts().filter(func(p): return p.id == &"drive_special")[0]
	var rules := _todays_events().filter(func(e): return e.name == "Event_drive_special")[0] \
		.find_child("Rules", true, false) as Label
	_check("a shift that bends a rule says how on the calendar (%s)"
		% (rules.text if rules != null else "no rules line"),
		rules != null and rules.text == dealt.rules_preview() and rules.text.contains("Hand of 4"))
	_check("built to today's difficulty, with the complicator it came with (%s)"
		% str(dealt.complicators.map(func(c): return c.id)),
		dealt.lineup.size() > 0 and dealt.complicators.size() == 1
			and dealt.complicators[0] == twist
			and rules != null and rules.text.contains(twist.display_text))
	special.hand_size = 0

	category.boss_day = true
	_run.week = Week.new(pool, _run.cfg.shifts_in_run, 1, _run.cfg.days_per_week)
	_root._open_the_picker()
	events = _todays_events()
	var boss_tags: Array = []
	for e in events:
		var t := (e as Node).find_child("PremadeTag", true, false) as Label
		if t != null and t.text.begins_with("BOSS"):
			boss_tags.append(t)
	_check("a boss takes one of today's shifts' places, and says so (%d shifts, %d bosses)"
		% [events.size(), boss_tags.size()],
		events.size() == _run.todays_shifts().size() and boss_tags.size() == 1)
	if boss_tags.size() == 1:
		var sticker: Label = boss_tags[0]
		var boss_event: Node = sticker.get_parent()
		_check("with a tilted sticker over its hours, which are hidden",
			boss_event is Button and not is_zero_approx(sticker.rotation)
				and is_zero_approx((boss_event.find_child("Hours", true, false) as Label).modulate.a))
		_check("while every other shift still shows its hours",
			events.filter(func(e): return e != boss_event).all(
				func(e): return (e.find_child("Hours", true, false) as Label).modulate.a == 1.0))

	_run.week = was
	_root._open_the_picker()
	_check("and the run's own week comes back", _todays_events().size() == _run.todays_shifts().size())

## "Add a shortcut to last fight, which stops me in the store with 5 upgrades and
## 5 purchases to pick from" - and "instead of free card, give me a dealership
## upgrade": Ctrl+B or a tap over the badge on the title screen, then the store,
## then straight to the final boss - and nothing of it filed among the scores. Run last: it replaces the run the rest of this driver has been
## following.
func _check_the_last_fight_shortcut_stops_in_the_store_then_fights_the_boss() -> void:
	var filed_before := PlayerProfile.bests().size()
	_root._new_run()
	_root._open_the_title()
	var tap := _root.get_node(^"%LastFightTapTarget") as Button
	_check("the title screen has a tap target for it, with nothing to see",
		tap.visible and tap.flat and (tap.text == ""))
	tap.pressed.emit()
	var run: RunState = _root._run
	_check("it opens the store, on the last day",
		_root._shop_view.visible and not _root._title_view.visible
			and run.shift_number == run.cfg.shifts_in_run)
	var shop: Shop = _root._shop_view._shop
	_check("with %d cards for sale and %d of yours to upgrade (%d, %d)"
		% [_root.LAST_FIGHT_PURCHASES, _root.LAST_FIGHT_UPGRADES, shop.offers.size(),
			shop.upgrade_offers.size()],
		shop.offers.size() == _root.LAST_FIGHT_PURCHASES
			and shop.upgrade_offers.size() == _root.LAST_FIGHT_UPGRADES)
	_check("a dealership upgrade to pick, in place of the free card (%d offered, %d free cards)"
		% [shop.dealership_offers.size(), shop.free_cards.size()],
		shop.dealership_offers.size() == _root.LAST_FIGHT_DEALERSHIP_UPGRADES
			and shop.dealership_picks_left == 1 and shop.free_cards.is_empty()
			and shop.free_picks_left == 0)
	_check("the store puts the upgrade first and no free card behind it",
		_root._shop_view._dealership_pick.visible and not _root._shop_view._free_pick.visible)
	_check("and picking one takes it", shop.take_dealership_upgrade(shop.dealership_offers[0]).ok
		and run.dealership.size() == 1)
	_check("and the money for every one of them (%d of %d)"
		% [run.money, shop.cost_of_everything()], run.money >= shop.cost_of_everything())
	var bought := 0
	for def in shop.offers.duplicate():
		bought += 1 if shop.buy(def).ok else 0
	var upgraded := 0
	for uid in shop.upgrade_offers.duplicate():
		upgraded += 1 if shop.upgrade(uid).ok else 0
	_check("buying all of them and upgrading all of them works (%d, %d)" % [bought, upgraded],
		bought == _root.LAST_FIGHT_PURCHASES and upgraded == _root.LAST_FIGHT_UPGRADES)
	_root._shop_view.done.emit()
	var profile: ShiftProfile = _root._chosen_profile
	_check("leaving it goes straight to the last day's boss, no calendar between",
		profile != null and profile.is_boss_day() and run.todays_shifts().has(profile)
			and not _root._picker_view.visible and _root._shift_view._shift != null)
	_check("and nothing leaves the store open behind it", not _root._shop_view.visible)
	_check_the_boss_fights_folders_say_what_is_happening(_root._shift_view)
	_check_a_product_the_boss_buys_leaves_the_table(_root._shift_view)
	_root._on_shift_finished(_root._shift_view._shift.report())
	_check("after the fight it is back to the menu, on a fresh run",
		_root._title_view.visible and _root._run.shift_number == 1
			and not _root._summary_view.visible)
	_check("and none of it was filed among the scores",
		PlayerProfile.bests().size() == filed_before)

	# The keyboard's way in: Ctrl+B on the title screen - but not while the name
	# tag is being written.
	var key := InputEventKey.new()
	key.keycode = KEY_B
	key.ctrl_pressed = true
	key.pressed = true
	_root._title_view.ask_name(&"new_game")
	_root._unhandled_input(key)
	_check("Ctrl+B does nothing while the name tag is up", not _root._shop_view.visible)
	_root._title_view._close_popup()
	_root._unhandled_input(key)
	_check("and opens the store once it is not", _root._shop_view.visible
		and _root._run.shift_number == _root._run.cfg.shifts_in_run)
	_root._new_run()
	_root._open_the_title()
	_check("the tap target is back up on the front door", tap.visible)
	_root._show_only(_root._picker_view)
	_check("and gone from every other screen", not tap.visible)

## "You could use the side chairs / folders to provide additional information. I
## shouldn't be able to rotate to them": on the real boss floor the budget is on
## the folder to the left and what is coming on the right, and neither is a seat.
func _check_the_boss_fights_folders_say_what_is_happening(floor_view) -> void:
	var shift: Shift = floor_view._shift
	var front: int = floor_view._front()
	var boss: Customer = shift.chairs[front]
	var left: int = (front + 2) % 3
	var right: int = (front + 1) % 3
	var budget_card: CustomerCard3D = floor_view._customer_cards[left]
	var move_card: CustomerCard3D = floor_view._customer_cards[right]
	_check("the boss is a boss, with a budget to drain", boss != null
		and boss.archetype.is_boss() and boss.has_budget())
	_check("the folder on the left is their budget (%s, %s)"
		% [budget_card._archetype.text, budget_card._name.text],
		budget_card._archetype.text == "BUDGET" and budget_card._note.visible
			and budget_card._name.text.contains(Format.money(boss.budget_left())))
	_check("its bar is how much is left of how much they came with",
		budget_card._patience_bar.value == boss.budget_left()
			and budget_card._patience_bar.max_value == boss.budget)
	_check("the folder on the right is what they are about to do (%s: %s)"
		% [move_card._archetype.text, move_card._name.text],
		move_card._note.visible and (move_card._archetype.text == "INCOMING"
			or move_card._archetype.text == "NEXT MOVE"))
	if boss.demand != null:
		_check("telegraphed with how to stop it (%s)" % move_card._note.text,
			move_card._name.text == boss.demand.display_name and move_card._note.text != ""
				and (move_card._patience.text.contains("to answer")
					or move_card._patience.text.contains("lands in")))
	var all_text: String = (budget_card._name.text + budget_card._note.text
		+ move_card._name.text + move_card._note.text + move_card._demand.text
		+ boss.archetype.pattern).to_lower()
	_check("and nothing on any of it calls their patience a shield",
		not all_text.contains("shield"))
	_check("the boss's own folder says patience", floor_view._customer_cards[front]._patience.text.begins_with("patience"))
	var own_card: CustomerCard3D = floor_view._customer_cards[front]
	_check("it wears their archetype's picture (%s)" % own_card._photo.icon,
		ArchetypeIcon.has(boss.archetype.icon) and own_card._photo.icon == boss.archetype.icon)
	_check("and is named from the archetype's own list (%s)" % boss.display_name,
		boss.archetype.names.is_empty() or boss.archetype.names.has(boss.display_name))
	_check("the folders either side are not people, so carry no picture",
		not budget_card._photo.visible and not move_card._photo.visible)
	_check("neither folder is a seat to turn to",
		shift.chairs.size() <= mini(left, right) and not shift.approach(left).ok
			and not shift.approach(right).ok)

## What the boss buys leaves the deck for the fight - and its card leaves the table
## with it, rather than sitting in front of their folder with nowhere to go.
func _check_a_product_the_boss_buys_leaves_the_table(floor_view) -> void:
	var shift: Shift = floor_view._shift
	var front: int = floor_view._front()
	var boss: Customer = shift.chairs[front]
	if shift.at == null:
		shift.approach(front)
	var inst: CardInstance = null
	for i in shift.hand:
		if inst == null and i.is_product():
			inst = i
	if inst == null:
		for i in shift.draw:
			if inst == null and i.is_product():
				inst = i
		if inst != null:
			shift.draw.erase(inst)
			shift.hand.append(inst)
	_check("there is a product to sell the boss", inst != null)
	if inst == null:
		return
	floor_view._render()
	boss.line = 0                       # a sale for certain
	var placed := shift.place(shift.hand.find(inst))
	floor_view._render()
	_check("the product is on their table as a card (%s)" % placed.msg,
		placed.ok and floor_view._nodes.has(inst.uid))
	var sold := shift.offer()
	floor_view._render()
	_check("and they buy it", sold.ok and not boss.unsigned.is_empty())
	_check("it is in no pile: out of the deck for the fight",
		shift.exhausted.has(inst) and not shift.discard.has(inst)
			and not shift.draw.has(inst) and not shift.hand.has(inst))
	var on_a_table := false
	for zone in floor_view._all_zones():
		for card in zone.cards:
			if card.uid == inst.uid:
				on_a_table = true
	_check("and its card has left the table, not stuck in front of their folder",
		not on_a_table and not floor_view._nodes.has(inst.uid))
	var kept := false
	for node in floor_view._retired:
		if node.uid == inst.uid:
			kept = true
	_check("hidden away, to be tidied up with the next shift", kept)

func _phase_2_leave_and_work_a_night() -> void:
	_root._shop_view.done.emit()
	_check("leaving the shop opens the picker, not the floor directly",
		_root._picker_view.visible and not _root._shop_view.visible)
	_check_the_calendar_shows_the_week()
	_check_the_calendar_shows_premade_shifts()
	# This driver digs every shift away, and a second total wipeout on top of
	# the first would end the run before the night's store could open - a
	# playtest top-up, the same job the floor's own standing tap target does.
	_run.standing = _run.cfg.standing_start
	# The tier with the most of yours to upgrade this time, for the upgrade
	# checks after it - whatever it is called.
	var second := _pick_tier_by(func(p): return p.upgrades)
	var shift: Shift = _root._shift_view._shift
	_check("on a shift that knows which one it is", shift.shift_number == 2)
	_check("carrying its tier's own archetype rules",
		shift.lineup == second.lineup
			and shift.excluded_archetypes == second.excluded_archetypes)
	_check("and the windows show its time of day (%s)"
		% _root._shift_view._windows.time_of_day(),
		_root._shift_view._windows.time_of_day() == second.worked_at())
	_check("with the clock on the tablet at the start of it (%s)"
		% _root._shift_view._tablets[0].clock_text(),
		_root._shift_view._tablets[0].clock_text() == ShiftHours.clock(second.worked_at(),
			shift.tick, shift.tick_budget))
	_check("running to its own quota", shift.quota == second.quota_on(_run.quota_for(2)))

	# The point of the whole milestone: what you took home came to work with
	# you. Matched on the exact uids the store minted, not just the CardDef -
	# an old copy of the same card would pass even if the new one never made it.
	var uids := {}
	for c in _root._shift_view._shift.draw:
		uids[c.uid] = true
	for c in _root._shift_view._shift.hand:
		uids[c.uid] = true
	_check("the card you took free is in the shift's deck",
		_taken_uid >= 0 and uids.has(_taken_uid))

	_finish_the_shift()
	_check("finishing the night opens the store again", _root._shop_view.visible)
	_check("stocked by that tier's own numbers",
		_root._shop_view._shop.upgrades == second.upgrades
			and _root._shop_view._shop.cards_for_sale == second.cards_for_sale)

## The shift log, the waiting list and the top bar each live in the floor's HUD
## CanvasLayer, which draws by layer number rather than tree order - so the
## deck viewer being visually in front of the floor does nothing to them on
## its own. shift_controller.gd's set_hud_dimmed(), wired through
## RunController's _deck_viewer.visibility_changed listener, is what
## actually hides them - checked here through the corner button (any of the
## three entry points would do; RunController's listener does not
## distinguish between them).
func _check_the_deck_viewer_hides_the_floor_side_panels() -> void:
	var shift_view = _root._shift_view
	var side_panel := shift_view.get_node(^"%SidePanel") as Control
	var waiting := shift_view.get_node(^"%WaitingPanel") as Control
	var top_strip := shift_view.get_node(^"%TopStrip") as Control
	_check("a shift opens with you sat at chair A", shift_view._shift.at == 0)
	_check("seated, so the log is showing to start with", side_panel.visible)
	_check("and the waiting list", waiting.visible)
	_check("and the shift's top bar", top_strip.visible)

	_root._view_deck_btn.pressed.emit()
	_check("opening the deck viewer hides the log", not side_panel.visible)
	_check("and the waiting list", not waiting.visible)
	_check("and the top bar", not top_strip.visible)

	(_root._deck_viewer.get_node(^"%DeckCloseButton") as Button).pressed.emit()
	_check("closing it brings the log back", side_panel.visible)
	_check("and the waiting list", waiting.visible)
	_check("and the top bar", top_strip.visible)

## "Click on your deck during the main game" - the floor's own trigger for
## the exact same overlay the shop's VIEW TOOLKIT button opens (RunController
## owns one shared instance - see its own comment on why). Driven through
## the real card_clicked signal on the draw pile's CardCollection3D, not a
## direct controller call, the same rule every other transition here follows.
func _check_clicking_the_draw_pile_opens_the_deck_viewer() -> void:
	var deck_viewer = _root._deck_viewer
	_check("the deck viewer starts hidden on the floor too", not deck_viewer.visible)
	_root._shift_view._draw_zone.card_clicked.emit(null)
	_check("clicking the draw pile opens it", deck_viewer.visible)
	(deck_viewer.get_node(^"%DeckCloseButton") as Button).pressed.emit()
	_check("closing it returns to the floor, not the shop",
		not deck_viewer.visible and not _root._shop_view.visible)

## Before a single shift is worked: the corner button over a new game's first
## calendar, with no shift on the floor behind it yet. Anything it trips over
## lands in the error trap.
func _check_the_toolkit_opens_from_a_new_games_calendar() -> void:
	var deck_viewer = _root._deck_viewer
	_check("the corner button is there on the first calendar",
		_root._picker_view.visible and _root._view_deck_btn.visible)
	_root._view_deck_btn.pressed.emit()
	_check("and opens the toolkit", deck_viewer.visible)
	(deck_viewer.get_node(^"%DeckCloseButton") as Button).pressed.emit()
	_check("which closes back onto the calendar",
		not deck_viewer.visible and _root._picker_view.visible)

## The third way in - a plain 2D button, always on screen top-right,
## reachable no matter which of the four screens is showing, for whenever
## the 3D draw pile's own pick shape is not a reliable target.
func _check_the_corner_button_opens_the_deck_viewer() -> void:
	var deck_viewer = _root._deck_viewer
	_check("the deck viewer starts hidden before the corner button is used",
		not deck_viewer.visible)
	_root._view_deck_btn.pressed.emit()
	_check("pressing the corner button opens it", deck_viewer.visible)
	(deck_viewer.get_node(^"%DeckCloseButton") as Button).pressed.emit()
	_check("closing it again leaves the corner button available",
		not deck_viewer.visible and _root._view_deck_btn.visible)

## A night store opens on the dealership upgrade, in front of the free pick:
## one tile per upgrade on offer, and clicking one keeps it for the run and
## lets the free pick through. Does nothing after a shift that offers none.
func _take_any_dealership_upgrade() -> void:
	var shop_view = _root._shop_view
	var shop: Shop = shop_view._shop
	var popup := shop_view.get_node(^"%DealershipPick") as Control
	if shop.dealership_offers.is_empty():
		_check("no dealership upgrade, no popup for one", not popup.visible)
		return
	var row := shop_view.get_node(^"%DealershipRow") as Control
	_check("the dealership upgrade pops up first, one tile per upgrade (%d)"
		% row.get_child_count(),
		popup.visible and row.get_child_count() == shop.dealership_offers.size()
			and not (shop_view.get_node(^"%FreePick") as Control).visible)
	var first: DealershipUpgrade = shop.dealership_offers[0]
	(row.get_child(0) as Button).pressed.emit()
	_check("clicking one keeps %s for the run and closes the popup" % first.display_name,
		_run.dealership.has(first) and not popup.visible)

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
		"standing_lost_to_walkouts": 100, "standing_healed": 100,
	}
	_set_standing_keys(worst, 100)
	var was := {}
	for key in ["title", "banked", "bonus", "standing", "walkouts", "customers",
			"offers", "margin", "lost"]:
		was[key] = report.get("_" + key).text
	report.setup(worst)

	# The report is an app window now: a title bar, then its body inside the
	# window's own margins. Measured the way the containers will lay it out -
	# every nested panel's padding and every column's gaps - at the width the
	# window gives its text.
	var window := report.get_node(^"%ReportWindow") as Control
	var pad := window.get_node(^"WindowColumn/Body") as MarginContainer
	var content := pad.get_node(^"Content") as Control
	var side: float = pad.get_theme_constant("margin_left") + pad.get_theme_constant("margin_right")
	var width: float = window.custom_minimum_size.x - side
	var total: float = AppWindow.TITLE_BAR_H + pad.get_theme_constant("margin_top") \
		+ pad.get_theme_constant("margin_bottom") + _needed_height(content, width)
	_check("the end-of-day report fits a 1080-tall viewport even at its wordiest (%d px)"
		% int(total), total <= 1080.0)

	# Leave the panel showing what the real shift actually produced, not the
	# synthetic worst case - nothing downstream expects to see 12345678 again.
	for key in was:
		report.get("_" + key).text = was[key]

## How tall a Control will lay out at `width`, without waiting on a layout pass:
## a Label by its font, a column by its children and gaps, a panel by its
## padding around what it holds.
func _needed_height(node: Control, width: float) -> float:
	if not node.visible:
		return 0.0
	if node is Label:
		var l := node as Label
		var text := l.text if l.text != "" else " "
		return l.get_theme_font("font").get_multiline_string_size(text,
			HORIZONTAL_ALIGNMENT_LEFT, width, l.get_theme_font_size("font_size")).y
	if node is VBoxContainer:
		var sum := 0.0
		var shown := 0
		for child in node.get_children():
			if child is Control and (child as Control).visible:
				sum += _needed_height(child, width)
				shown += 1
		if shown > 1:
			sum += float(node.get_theme_constant("separation") * (shown - 1))
		return maxf(sum, node.custom_minimum_size.y)
	if node is PanelContainer:
		var box: StyleBox = node.get_theme_stylebox("panel")
		var inner := width - box.get_margin(SIDE_LEFT) - box.get_margin(SIDE_RIGHT)
		var tallest := 0.0
		for child in node.get_children():
			if child is Control:
				tallest = maxf(tallest, _needed_height(child, inner))
		return maxf(tallest + box.get_margin(SIDE_TOP) + box.get_margin(SIDE_BOTTOM),
			node.custom_minimum_size.y)
	if node is BoxContainer:   # a row: as tall as its tallest
		var tallest := 0.0
		for child in node.get_children():
			if child is Control:
				tallest = maxf(tallest, maxf((child as Control).custom_minimum_size.y,
					_needed_height(child, width)))
		return tallest
	return node.custom_minimum_size.y

## "Before that week starts, give the player a 'this week so far' kind of
## report." Put the run on the first day of week 2 and close the store the way
## a player would: the report comes up instead of the calendar, a row for each
## day of week 1 this run has worked, and its button opens week 2's calendar.
func _check_the_week_report_comes_between_weeks() -> void:
	var was_day: int = _run.shift_number
	var per_week: int = _run.cfg.days_per_week
	if _run.cfg.shifts_in_run <= per_week:
		print("SKIP  week report check: the run is only one week long")
		return
	_run.shift_number = per_week + 1
	var week_view = _root._week_view
	_check("the week report starts hidden", not week_view.visible)
	_root._on_shop_done()
	_check("closing the last store of a week opens its report, not the calendar",
		week_view.visible and not _root._picker_view.visible)
	var worked: int = mini(_root._history.size(), per_week)
	var grid := week_view.get_node(^"%DaysGrid") as GridContainer
	_check("a row for each day of the week worked (%d cells for %d days)"
		% [grid.get_child_count(), worked],
		grid.get_child_count() == grid.columns * (worked + 1))
	_check("titled for the week just worked (%s)" % week_view._title.text,
		week_view._title.text.contains("WEEK 1"))
	# "Base pay should increase each week by a little bit, and the end of week
	# email should mention it."
	var next_pay: int = _run.cfg.paycheck_in_week(2)
	_check("the email says the base pay goes up, and to what (%s)" % week_view._next.text,
		_run.cfg.paycheck_raise_per_week <= 0
			or (week_view._next.text.contains("base pay")
				and week_view._next.text.contains(Format.money(next_pay))))
	# "After week 1, there are product quotas... This should be explained in
	# the end of week 1 email."
	var memo := week_view.get_node(^"%Memo") as Control
	var starts_now: bool = _run.cfg.category_quota_in_week(2) > 0 \
		and _run.cfg.category_quota_in_week(1) <= 0
	var memo_text: String = (week_view.get_node(^"%MemoLabel") as Label).text
	_check("the email explains next week's product quotas (%s)" % memo_text.left(60),
		memo.visible == starts_now and (not starts_now
			or (memo_text.contains("product quota")
				and memo_text.contains(str(_run.cfg.category_quota_in_week(2)))
				and memo_text.contains("%d standing" % _run.cfg.category_quota_standing))))
	var start := week_view.get_node(^"%StartButton") as Button
	_check("and a way on into week 2 (%s)" % start.text, start.text.contains("2"))
	start.pressed.emit()
	_check("which opens week 2's calendar", _root._picker_view.visible and not week_view.visible)
	_check_week_two_shows_the_product_quota()
	_run.shift_number = was_day

## Week 2's calendar names what the boss wants under every day's date but a
## boss day's, and a shift worked under it carries it onto the floor's top bar.
func _check_week_two_shows_the_product_quota() -> void:
	var q: Dictionary = _run.category_quota(_run.shift_number)
	var shown: Array = _root._picker_view.find_children("ProductQuota", "Label", true, false)
	var expected: Dictionary = _root._week_product_quotas()
	_check("the week's days name their product quotas (%d labels, %d days)"
		% [shown.size(), expected.size()],
		shown.size() == expected.size() and not expected.is_empty())
	# A boss carries no product quota, so the first of today's regular shifts.
	var regular := _run.todays_shifts().filter(func(p): return not p.is_boss_day())
	if q.is_empty() or regular.is_empty():
		return
	var s := _run.start_shift(regular[0])
	_root._chosen_profile = regular[0]
	_root._show_only(_root._shift_view)
	_root._shift_view.setup(s, _run.standing)
	var label := _root._shift_view.get_node(^"%ProductQuotaLabel") as Label
	_check("the floor's top bar shows it (%s)" % label.text,
		label.visible and label.text.contains((q["category"] as Category).display_name)
			and label.text.contains("0/%d" % int(q["count"])))
	_check_an_unsigned_product_shows_on_the_top_bar(s, label)
	_check_the_calendar_from_the_floor()
	_root._show_only(_root._picker_view)

## A product agreed to but not signed for shows beside the count, and moves into
## it once they sign.
func _check_an_unsigned_product_shows_on_the_top_bar(s: Shift, label: Label) -> void:
	var def: ProductCardDef = null
	for c in s.card_pool.cards:
		if c is ProductCardDef and (c as ProductCardDef).interest.category.id == s.category_quota:
			def = c
			break
	# A plain buyer in chair A - whoever the day dealt there might hold out for a
	# concession, want another category first or wave the card off, and none of
	# that is what this checks.
	var plain := CustomerArchetype.new()
	plain.id = &"drive_plain_buyer"
	plain.display_name = "Plain Buyer"
	s.chairs[0] = null
	s._spawn(0, plain)
	s.at = 0
	var customer: Customer = s.chairs[0]
	customer.line = 0
	s.hand.clear()
	s.hand.append(CardInstance.new(def, 990))
	s.place(0)
	s.offer()
	_root._shift_view._render()
	_check("a product agreed to shows as unsigned (%s)" % label.text,
		label.text.contains("0/") and label.text.contains("+1 unsigned"))
	s.close()
	_root._shift_view._render()
	_check("and counts once signed (%s)" % label.text,
		label.text.contains("1/") and not label.text.contains("unsigned"))

## "Add a button to view calendar (view only) from the floor scene."
func _check_the_calendar_from_the_floor() -> void:
	var button := _root.get_node(^"BuildBadge/ViewCalendarCornerButton") as Button
	var picker = _root._picker_view
	_check("the floor has a VIEW CALENDAR button", button.visible)
	button.pressed.emit()
	_check("which lays the week over the floor", picker.visible)
	_check("without leaving it", (_root._shift_view.get_node(^"HUD") as CanvasLayer) != null
		and _root._shift_view.current_shift() != null)
	var events: Array = picker.find_children("Event_*", "", true, false)
	_check("today is the one shift you are on (%d events)" % events.size(), events.size() == 1)
	var pickable := false
	for e in events:
		pickable = pickable or (e as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE
	_check("and nothing on it can be picked", not pickable)
	_check("it says which (%s)" % picker._sub.text,
		picker._sub.text.contains(_root._chosen_profile.display_name))
	var close := picker.get_node(^"%CloseButton") as Button
	_check("with a way back", close.visible)
	close.pressed.emit()
	_check("which puts it away, back to the floor", not picker.visible and button.visible)
	_root._open_the_picker()
	_check("the picker itself has no way back - it is where you start",
		not (picker.get_node(^"%CloseButton") as Button).visible)
	_check("and the button is the floor's alone", not button.visible)

## "At end of run it would show you all these categories and the points
## given and a high score" - the literal ask, end to end: force the run onto
## its last shift, finish it through the real report button the way a player
## would, and check the summary that comes up actually is RunSummaryPanel
## rendering Score.tally() of the very _run this driver has been playing.
func _check_run_summary_screen_appears_at_the_end_of_a_run() -> void:
	_run.shift_number = _run.cfg.shifts_in_run
	# Out of the store and onto the floor, the way _open_the_floor() does it.
	_root._show_only(_root._shift_view)
	_root._shift_view.setup(_run.start_shift(ShiftProfile.new()), _run.standing)
	_check("the summary starts out hidden", not _root._summary_view.visible)

	_finish_the_shift()

	_check("the run is over after its last shift", _run.is_over())
	_check("the summary screen shows once the run ends",
		_root._summary_view.visible)
	_check("the shop stays hidden behind it, not shown underneath",
		not _root._shop_view.visible)

	var score := Score.tally(_run)
	var summary = _root._summary_view
	_check("the boss's email totals the same score Score.tally computes (%s)"
		% summary._total.text,
		summary._total.text == Format.number(int(score["total"])))
	var measured := func(row: String) -> String:
		return (summary._rows[row].get_node(^"Measured") as Label).text
	_check("margin banked, lifetime, is on its own line (%s)" % measured.call("MarginRow"),
		measured.call("MarginRow").contains(Format.money(score["margin_banked"])))
	_check("standing at the bell is on its own line (%s)" % measured.call("StandingRow"),
		measured.call("StandingRow").contains(str(score["standing"])))
	_check("walkout count is on its own line (%s)" % measured.call("WalkoutsRow"),
		measured.call("WalkoutsRow") == str(score["walkouts"]))
	# Personal bests: the week is filed on this device, and the email says so.
	var filed: Array = PlayerProfile.bests().filter(
		func(r): return int(r["score"]) == int(score["total"]))
	_check("the week was filed among this device's personal bests",
		not filed.is_empty())
	_check("as the device's first week, it is on the board - not a record it beat (%s)"
		% summary._best_headline.text,
		summary._best_headline.text == "Your first week on the board")
	_check("the email lists the best weeks on this device (%d)"
		% summary._bests_list.get_child_count(), summary._bests_list.get_child_count() >= 1)
	_check("addressed to whoever is playing (%s)" % summary._to.text,
		summary._to.text.contains(PlayerProfile.display_name()))

	var stale_run := _run
	summary.continue_pressed.emit()
	_check("pressing the button hides the summary", not summary.visible)
	_check("and goes back to the title screen's menu",
		_root._title_view.visible and _root._title_view.page() == &"menu"
			and not _root._picker_view.visible)
	_root._title_view.show_scores()
	_check("whose high scores list the week just filed (%d)"
		% _root._title_view._scores_list.get_child_count(),
		_root._title_view._scores_list.get_child_count() == PlayerProfile.bests().size()
			and not _root._title_view._scores_empty.visible)
	_check("and rolls a genuinely fresh RunState, not the finished one relabeled",
		_root._run != stale_run and _root._run.shift_number == 1)
	_check("with a full standing meter again",
		_root._run.standing == _root._run.cfg.standing_start)
	_run = _root._run   # the driver keeps playing the fresh run past this point
	_root._show_only(_root._picker_view)

## "YOU'RE FIRED" has to read as a different outcome than finishing the run on
## schedule - the same rule report_panel.gd already follows for the per-shift
## version of this screen. Driven directly through setup(), the same way
## _check_report_card_fits_the_worst_case() reaches a branch this driver's own
## play never lands on live.
func _check_the_fired_title_is_distinct_from_a_completed_run() -> void:
	var summary = _root._summary_view
	var score := Score.tally(_run)
	summary.setup(score, true)
	_check("a standing wipeout gets the boss's \"You're fired.\" (%s)"
		% summary._title.text, summary._title.text == "You're fired.")
	_check("in the same alert colour the per-shift report already uses for it",
		summary._title.get_theme_color("font_color") == Palette.color(&"alert"))
	summary.setup(score, false)
	_check("a completed run gets the week's numbers instead (%s)"
		% summary._title.text, summary._title.text == "Your week, by the numbers")
	_check("in the same neutral colour the per-shift report uses for a normal close",
		summary._title.get_theme_color("font_color") == Palette.color(&"text"))

func _check(label: String, ok: bool) -> void:
	_checks += 1
	if not ok:
		_failures.append(label)
