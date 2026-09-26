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

func _init() -> void:
	seed(20260905)
	_root = (load("res://scenes/run.tscn") as PackedScene).instantiate()
	# This driver tests the run, not the practice shift in front of it (that
	# is tools/drive_tutorial.gd's job) - so it boots straight to the picker,
	# whatever the machine running it has or has not played before.
	_root.tutorial_at_boot = false
	# Its own profile, so the runs this plays are never filed among a real
	# player's personal bests.
	PlayerProfile.path = PROFILE
	PlayerProfile.reset()
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
		# After a MIDDAY shift: the free card, and one card for sale.
		_check_shop_layout_fits_on_screen()
		_check_the_view_deck_button_shows_the_whole_deck()
		_check_the_free_card_is_on_the_house()
		_check_clicking_a_shelf_card_buys_it()
		_check_a_midday_visit_has_no_upgrade()
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
		# After a NIGHT shift: the free card, and one of yours to upgrade.
		_check_shop_layout_fits_on_screen()
		_check_a_night_visit_has_nothing_for_sale()
		_check_the_deck_row_shows_exactly_the_random_upgrade_offers()
		_check_clicking_a_deck_card_opens_its_detail()
		_check_run_summary_screen_appears_at_the_end_of_a_run()
		_check_the_fired_title_is_distinct_from_a_completed_run()
		PlayerProfile.reset()

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
## in this driver already follows (.done, .continue_pressed). Midday first,
## for the store's card for sale; night second, for its upgrade.
func _pick_tier(id: StringName) -> void:
	_check("the picker is showing before a tier is chosen",
		_root._picker_view.visible)
	var profile: ShiftProfile = _root._profiles.by_id(id)
	_check("%s is a real profile in the pool" % id, profile != null)
	_root._picker_view.chosen.emit(profile)
	_check("choosing %s closes the picker" % id, not _root._picker_view.visible)

func _phase_0_open_and_finish_shift() -> void:
	_run = _root._run
	_check("a run started", _run != null)
	_check("on shift 1", _run.shift_number == 1)
	_pick_tier(&"midday")
	_check("with the floor showing, not the shop", not _root._shop_view.visible)
	# The office windows and the tablet's clock follow the shift you picked.
	_check("a midday shift looks out on the middle of the day (%s)"
		% _root._shift_view._windows.time_of_day(),
		_root._shift_view._windows.time_of_day() == &"midday")
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
		"free row": _root._shop_view.get_node(^"%FreeRow") as Control,
		"shelf row": _root._shop_view.get_node(^"%ShelfRow") as Control,
		"deck row": _root._shop_view.get_node(^"%DeckRow") as Control,
	}
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
	for pair in [["free row", shop.free_card == null], ["shelf row", shop.offers.is_empty()],
			["deck row", shop.upgrade_offers.is_empty()]]:
		if pair[1]:
			var row: Node = rows[pair[0]]
			_check("an empty aisle says so (%s: %s)" % [pair[0],
				(row.get_child(0) as Label).text if row.get_child_count() == 1
					and row.get_child(0) is Label else "no note"],
				row.get_child_count() == 1 and row.get_child(0) is Label)
	# An aisle keeps one card slot's height whether it holds a card or only
	# says it is empty: taking the free card must not pull the page, and the
	# button you are about to press, up the screen.
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
	## The capping behaviour this checks only means anything when the deck
	## actually has more upgrade-eligible cards than there are slots - a
	## precondition, not the thing under test. A deck/slot-count retune that
	## makes it untrue should skip this quietly rather than fail for a reason
	## unrelated to whether capping itself still works.
	var shop_view = _root._shop_view
	var shop: Shop = shop_view._shop
	_check("a night's visit gives exactly one upgrade (%d)" % shop.upgrades,
		shop.upgrades == 1 and shop.upgrades_left == 1)
	var eligible_uncapped := 0
	for inst in _run.deck.cards:
		if not inst.upgraded and shop.upgrade_gain(inst) > 0:
			eligible_uncapped += 1
	if eligible_uncapped <= _run.cfg.shop_upgrade_slots:
		print("SKIP  deck-row capping check: only %d eligible cards against %d slots, proves nothing"
			% [eligible_uncapped, _run.cfg.shop_upgrade_slots])
		return

	var deck_row := shop_view.get_node(^"%DeckRow") as HBoxContainer
	_check("rendered exactly as many deck slots as were actually offered (%d)"
		% deck_row.get_child_count(), deck_row.get_child_count() == shop.upgrade_offers.size())
	_check("which is capped at the configured slot count, not the whole deck",
		deck_row.get_child_count() <= _run.cfg.shop_upgrade_slots)

## "Show the card itself. When you click, it opens up the card, shows the
## upgraded card and also has a button for removing from deck" - the literal
## ask, end to end: click a deck slot, the detail overlay opens showing both
## faces and the right prices, upgrading applies and closes it, and the row
## behind it reflects the change once it does. Then "upgrade ONE card": the
## next card along no longer offers an upgrade at all, only the drop.
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

	# The visit's one upgrade is spent. The rest of the few stay on show - so
	# you can still see what you chose between - but say so, and a click on
	# one offers only the drop.
	if shop.upgrade_offers.size() < 2:
		print("SKIP  one-upgrade check: only one card was on offer")
		return
	deck_row = shop_view.get_node(^"%DeckRow") as HBoxContainer
	var labels: Array[String] = []
	for slot in deck_row.get_children():
		labels.append((slot.get_child(slot.get_child_count() - 1) as Label).text)
	_check("the card you chose reads upgraded, the rest that the upgrade is used (%s)"
		% ", ".join(labels),
		labels[0] == "upgraded" and labels.slice(1).all(func(t): return t == "upgrade used"))
	var drop_uid: int = shop.upgrade_offers[1]
	var deck_size_before_drop := _run.deck.cards.size()
	_slot_card(deck_row.get_child(1)).pressed.emit()
	_check("clicking a second card of yours opens its own detail", detail.visible)
	_check("with no upgrade on it - the visit's one is spent",
		not detail._upgrade_btn.visible)
	_check("but the drop still there", detail._remove_btn.visible)
	var drop_price := shop.remove_price()
	detail._remove_btn.pressed.emit()
	_check("pressing remove actually drops the card (%d -> %d, price %s)"
		% [deck_size_before_drop, _run.deck.cards.size(), Format.money(drop_price)],
		_run.deck.cards.size() == deck_size_before_drop - 1
			and shop.find(drop_uid) == null)
	_check("and closes the overlay too", not detail.visible)

## After a midday shift there is a card for sale and nothing of yours to
## upgrade - and the aisle for it says so.
func _check_a_midday_visit_has_no_upgrade() -> void:
	var shop: Shop = _root._shop_view._shop
	var deck_row := _root._shop_view.get_node(^"%DeckRow") as HBoxContainer
	_check("a midday visit offers none of your cards to upgrade",
		shop.upgrades == 0 and shop.upgrade_offers.is_empty())
	var note := _note_in(deck_row)
	_check("and its aisle says there is no upgrade (%s)" % note, note.contains("No upgrade"))

## ...and after a night shift, the other way round.
func _check_a_night_visit_has_nothing_for_sale() -> void:
	var shop: Shop = _root._shop_view._shop
	var shelf_row := _root._shop_view.get_node(^"%ShelfRow") as HBoxContainer
	var free_row := _root._shop_view.get_node(^"%FreeRow") as HBoxContainer
	_check("a night visit still has its free card", shop.free_card != null
		and free_row.get_child_count() == 1 and _slot_card(free_row.get_child(0)) != null)
	_check("but nothing for sale", shop.cards_for_sale == 0 and shop.offers.is_empty())
	var note := _note_in(shelf_row)
	_check("and its aisle says so (%s)" % note, note.contains("Nothing for sale"))

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

## "At the end of every shift, offer a single card for free." One card in the
## free aisle, marked FREE; clicking it opens the same overlay every card here
## uses, with only a way to take it; taking it adds that very card and spends
## nothing, and the aisle then says where it went.
func _check_the_free_card_is_on_the_house() -> void:
	var shop_view = _root._shop_view
	var shop: Shop = shop_view._shop
	var free_row := shop_view.get_node(^"%FreeRow") as HBoxContainer
	var one: bool = free_row.get_child_count() == 1 \
		and _slot_card(free_row.get_child(0)) != null
	_check("one card in the free aisle (%d)" % free_row.get_child_count(), one)
	if not one:
		return
	var slot := free_row.get_child(0)
	var price := slot.get_child(slot.get_child_count() - 1) as Label
	_check("marked free (%s)" % price.text, price.text == "FREE")
	var free: CardDef = shop.free_card
	var detail: ShopCardDetail = shop_view.get_node(^"%Detail")
	_slot_card(slot).pressed.emit()
	_check("clicking it opens the overlay, titled after it (%s)" % detail._title.text,
		detail.visible and detail._title.text == free.display_name)
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
	if added.size() == 1:
		_taken_uid = added[0].uid
	var note := _note_in(shop_view.get_node(^"%FreeRow"))
	_check("and the aisle says where it went (%s)" % note, note.contains("toolkit"))

## "At the end of midday shift, offer a chance to buy one card." The shelf
## routes through the SAME confirm-before-you-spend overlay: clicking the card
## opens it with a "buy" button, not an instant purchase.
func _check_clicking_a_shelf_card_buys_it() -> void:
	var shop_view = _root._shop_view
	var shop: Shop = shop_view._shop
	var shelf_row := shop_view.get_node(^"%ShelfRow") as HBoxContainer
	var one: bool = shop.offers.size() == 1 and shelf_row.get_child_count() == 1 \
		and _slot_card(shelf_row.get_child(0)) != null
	_check("exactly one card for sale after a midday shift (%d)" % shop.offers.size(), one)
	if not one:
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
	var note := _note_in(shop_view.get_node(^"%ShelfRow"))
	_check("and the aisle says it is sold (%s)" % note, note.contains("Sold"))
	shop.run.money = was_affordable   # leave the rest of the run its own accounting

## The picker is a calendar's week view: a column per day of the run, today's
## three shifts as events you click, and the day already worked showing the
## shift you took and how it went. Checked on the SECOND visit, the first one
## with a past to show.
func _check_the_calendar_shows_the_week() -> void:
	_check_window_fits("the calendar", _root._picker_view.get_node(^"%CalendarWindow"))
	var week: Node = _root._picker_view.get_node(^"%Week")
	var days: int = _run.cfg.shifts_in_run
	_check("a column per day of the run, after the hours (%d)" % week.get_child_count(),
		week.get_child_count() == days + 1)
	if week.get_child_count() != days + 1:
		return
	var today: int = _run.shift_number   # column 0 is the hours
	var events: Array = []
	for child in week.get_child(today).get_child(1).get_children():
		if child is Button:
			events.append(child)
	_check("today holds every shift you can pick (%d)" % events.size(),
		events.size() == _root._profiles.profiles.size())
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
	var midday: Button = null
	for e in events:
		if e.name == "Event_midday":
			midday = e
	if midday != null:
		midday.pressed.emit()
	_root._picker_view.chosen.disconnect(catch)
	_root._picker_view.chosen.connect(_root._on_profile_chosen)
	_check("clicking an event chooses that shift",
		got.size() == 1 and got[0].id == &"midday")

func _phase_2_leave_and_work_a_night() -> void:
	_root._shop_view.done.emit()
	_check("leaving the shop opens the picker, not the floor directly",
		_root._picker_view.visible and not _root._shop_view.visible)
	_check_the_calendar_shows_the_week()
	# This driver digs every shift away, and a second total wipeout on top of
	# the first would end the run before the night's store could open - a
	# playtest top-up, the same job the floor's own standing tap target does.
	_run.standing = _run.cfg.standing_start
	# Night this time - real coverage of the archetype-pool unlock and of the
	# upgrade its store adds, not just re-picking the tier the first shift did.
	_pick_tier(&"night")
	_check("on a shift that knows which one it is",
		_root._shift_view._shift.shift_number == 2)
	_check("night's shift actually carries its archetype-pool unlock",
		_root._shift_view._shift.unlock_full_archetype_pool)
	_check("and the windows have gone dark for it (%s)"
		% _root._shift_view._windows.time_of_day(),
		_root._shift_view._windows.time_of_day() == &"night")
	_check("with the clock on the tablet at the start of a night (%s)"
		% _root._shift_view._tablets[0].clock_text(),
		_root._shift_view._tablets[0].clock_text() == ShiftHours.clock(&"night",
			_root._shift_view._shift.tick, _root._shift_view._shift.tick_budget)
			and _root._shift_view._tablets[0].clock_text().ends_with("PM"))
	_check("running to the climbing quota",
		_root._shift_view._shift.quota == _run.quota_for(2))

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
	_check("and so is the card you bought", _bought_uid >= 0 and uids.has(_bought_uid))

	_finish_the_shift()
	_check("finishing the night opens the store again", _root._shop_view.visible)
	_check("stocked by the night's own tier",
		_root._shop_view._shop.upgrades == 1 and _root._shop_view._shop.cards_for_sale == 0)

## The shift log and the top bar each live in the floor's HUD
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
	var top_strip := shift_view.get_node(^"%TopStrip") as Control
	var res: Result = shift_view._shift.approach(0)
	_check("approaching chair A to seat someone (%s)" % res.msg, res.ok)
	shift_view._apply(res)
	_check("seated, so the log is showing to start with", side_panel.visible)
	_check("and the shift's top bar", top_strip.visible)

	_root._view_deck_btn.pressed.emit()
	_check("opening the deck viewer hides the log", not side_panel.visible)
	_check("and the top bar", not top_strip.visible)

	(_root._deck_viewer.get_node(^"%DeckCloseButton") as Button).pressed.emit()
	_check("closing it brings the log back", side_panel.visible)
	_check("and the top bar", top_strip.visible)

	shift_view._apply(shift_view._shift.leave())

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
	_check("and rolls a genuinely fresh RunState, not the finished one relabeled",
		_root._run != stale_run and _root._run.shift_number == 1)
	_check("with a full standing meter again",
		_root._run.standing == _root._run.cfg.standing_start)
	_run = _root._run   # the driver keeps playing the fresh run past this point

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
