extends Node
## The run: a picked shift, played, a shop after it, then pick again.
##
## Owns the RunState and does nothing else - the picker chooses a
## ShiftProfile, the shift screen plays a shift under it, the shop screen
## hands out a free card and whatever else that same profile earns, and this
## decides which one you are looking at. That split is the whole reason
## shift_controller.gd stopped building its own shift: it is already the
## table, the framing, the HUD and reconciliation.

@onready var _picker_view = $ShiftPickerView
@onready var _shift_view = $ShiftView
@onready var _shop_view = $ShopView
@onready var _summary_view = $RunSummaryView
## Between weeks - see week_report_panel.gd.
@onready var _week_view = $WeekReportView
## Reachable from the shop's own button AND clicking the draw pile on the
## floor, so it lives here rather than inside either screen - one overlay,
## shown on top of whichever of the four is active, never toggled by
## _show_only() itself (it is dismissed by its own Close button, the same
## independence ShopCardDetail already has within the shop alone).
@onready var _deck_viewer = $DeckViewer
@onready var _build_label: Label = $BuildBadge/BuildLabel
## Top-right, always on screen (same CanvasLayer as the build badge) - a
## third way into the deck viewer, alongside the shop's own button and the
## floor's draw pile, and the one least dependent on hitting a specific
## click target.
@onready var _view_deck_btn: Button = $BuildBadge/ViewDeckCornerButton
## On the floor only: this week's calendar to look at, not pick from.
@onready var _view_calendar_btn: Button = $BuildBadge/ViewCalendarCornerButton
## Whether the calendar is up over the floor - see _open_the_calendar_view().
var _calendar_open := false
## The practice shift's teacher - see scripts/run/tutorial.gd for the shift
## and tutorial_coach.gd for the lesson.
@onready var _coach: TutorialCoach = $TutorialCoach

## The front door: the menu (NEW GAME, TUTORIAL, HIGH SCORES), and a new
## game's first-day welcome - see title_screen.gd.
@onready var _title_view = $TitleView
## Over the build badge on the title screen: the touch way to the last fight,
## as Ctrl+B is the keyboard's - see _debug_last_fight().
@onready var _last_fight_tap: Button = $BuildBadge/LastFightTapTarget

## What the last fight's store puts up for sale, and how many of your cards it
## offers to upgrade - see _debug_last_fight().
const LAST_FIGHT_PURCHASES := 5
const LAST_FIGHT_UPGRADES := 5
## How many dealership upgrades it offers, to pick ONE from - in place of the
## free card.
const LAST_FIGHT_DEALERSHIP_UPGRADES := 3

## Open the game on the title screen's menu. A driver that is testing the run
## itself turns this off BEFORE adding the run to the tree, so it boots
## straight to the calendar.
@export var title_at_boot := true

var _run: RunState
var _profiles: ShiftProfilePool
var _chosen_profile: ShiftProfile
## True while the floor is playing the practice shift rather than one of the
## run's: its end goes back to the picker, and never to a report or the shop.
var _in_tutorial := false
## One {"profile", "report"} per shift worked this run, in order - the picker's
## calendar shows each past day as the shift you took and how it went.
var _history: Array = []
## True for a run begun with the last-fight shortcut: nothing of it is filed
## among the scores - see _debug_last_fight().
var _practice_run := false
## True between that shortcut's store and its fight - leaving the store goes
## straight to the boss rather than to a calendar to pick from.
var _straight_to_the_boss := false
## The run being worked, as it goes to disk after every move (RunFile) - null
## behind the title screen and for a run nothing is kept of (the last-fight
## shortcut). See _keep_the_save_current().
var _save: RunSave = null
## The shift being worked today and the store open after it, once there are
## any - what the save's fingerprint is taken of.
var _live_shift: Shift = null
var _live_shop: Shop = null
## How far the save on disk had got when it was written - see
## _keep_the_save_current().
var _saved_mark: Array = []
## Said on the next calendar: CONTINUE could not play today's moves back on this
## build, so today starts over from its calendar.
var _calendar_note := ""

func _ready() -> void:
	_picker_view.chosen.connect(_on_profile_chosen)
	_shift_view.shift_finished.connect(_on_shift_finished)
	_shift_view.deck_viewed.connect(_on_view_deck_requested)
	_shop_view.done.connect(_on_shop_done)
	_shop_view.view_deck_requested.connect(_on_view_deck_requested)
	_view_deck_btn.pressed.connect(_on_view_deck_requested)
	_view_calendar_btn.pressed.connect(_open_the_calendar_view)
	_picker_view.closed.connect(_close_the_calendar_view)
	# The deck viewer sits in front of the floor visually, but its own action
	# column and shift log live in the floor's HUD CanvasLayer - drawn by
	# layer, not tree order, so they would otherwise keep showing through
	# regardless of which of the three entry points opened it, or how it
	# gets closed. Control's own visibility_changed catches every path.
	_deck_viewer.visibility_changed.connect(
		func(): _shift_view.set_hud_dimmed(_deck_viewer.visible or _calendar_open))
	_summary_view.continue_pressed.connect(_on_summary_continue)
	_week_view.continue_pressed.connect(_open_the_picker)
	# NOT left to whatever build_run_scene.gd happened to bake into run.tscn
	# at author time: that text is a static property of a committed scene
	# file, frozen the moment the builder ran locally, and CI stamps
	# BuildInfo.LABEL's SOURCE long after that scene was already generated
	# and checked in. Reading it here, at actual startup, is what makes the
	# badge answer "what build is this" rather than "what build was it when
	# someone last ran the builder."
	_build_label.text = BuildInfo.LABEL
	_coach.finished.connect(_on_tutorial_finished)
	_title_view.tutorial_requested.connect(_open_the_tutorial)
	_title_view.new_game_started.connect(_start_run)
	_title_view.continue_requested.connect(_continue_run)
	_bind_key(&"debug_last_fight", KEY_B, true)   # Ctrl+B, on the title screen
	_last_fight_tap.pressed.connect(_debug_last_fight)
	if title_at_boot:
		_new_run()
		_open_the_title()
		# Back from the phone taking the GPU away mid-run: straight back to it.
		if RunFile.reloaded_to_pick_up():
			_continue_run()
	else:
		_start_run()

## A fresh run, straight to its first day's calendar. It takes the place of
## any run on this device that was still going.
func _start_run() -> void:
	_new_run()
	_begin_the_day()
	_open_the_picker()

## CONTINUE: the run on this device, put back exactly where it was left - the
## calendar, the floor mid-shift, the report, or the store. Played back from the
## start of its day (RunSave); if this build plays those moves out differently,
## the day starts over from its calendar instead, and the calendar says so.
func _continue_run() -> void:
	var save := RunFile.read()
	if save == null:
		_open_the_title()
		return
	_new_run(save.seed_value())
	var back := save.resume(_run)
	if not back["ok"]:
		_new_run(save.seed_value())
		save.restart_day()
		back = save.resume(_run, false)
		_calendar_note = "A new build came in - today starts over"
	_history = back["history"]
	_save = save
	_live_shift = back["shift"]
	_live_shop = back["shop"]
	_chosen_profile = back["profile"]
	# The played-back shift and store keep their own logs from here on.
	if _live_shift != null:
		_save.shift_commands = _live_shift.commands
	if _live_shop != null:
		_save.shop_commands = _live_shop.commands
	_write_the_save()
	if _live_shop != null:
		_show_only(_shop_view)
		_shop_view.setup(_live_shop)
	elif _live_shift != null:
		_show_only(_shift_view)
		_shift_view.setup(_live_shift, _run.standing, _chosen_profile.worked_at(), true)
	else:
		_open_the_day()

## A day beginning on its calendar: what the save plays back from, from here.
func _begin_the_day() -> void:
	_live_shift = null
	_live_shop = null
	if _practice_run:
		return
	_save = RunSave.start_of_day(_run, _history)
	_write_the_save()

func _write_the_save() -> void:
	if _save == null:
		return
	_save.build = BuildInfo.LABEL
	_save.fingerprint = RunSave.fingerprint_of(_run, _live_shift, _live_shop)
	RunFile.write(_save)
	_saved_mark = _save_mark()

func _save_mark() -> Array:
	return [_save.pick, _save.pick_path, _save.shift_commands.size(), _save.shop_open,
		_save.shop_commands.size()]

## Every move lands in the shift's or the store's own log (Shift.commands,
## Shop.commands), wherever it came from - a tap, a drag, a key - so the save
## only has to notice that one did. Written the frame after, with the game still
## in front of you.
func _process(_delta: float) -> void:
	_keep_the_save_current()

func _keep_the_save_current() -> void:
	if _save != null and _save_mark() != _saved_mark:
		_write_the_save()

func _bind_key(action: StringName, keycode: Key, ctrl: bool = false) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	if not InputMap.action_get_events(action).is_empty():
		return
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.ctrl_pressed = ctrl
	InputMap.action_add_event(action, ev)

func _unhandled_input(event: InputEvent) -> void:
	# On the title screen, but not while the name tag is being written.
	if event.is_action_pressed("debug_last_fight") and _title_view.visible \
			and not _title_view.name_popup_showing():
		_debug_last_fight()

## Ctrl+B on the title screen, or a tap over the build badge: the last fight,
## without the nine days before it - a manual testing convenience, not a
## mechanic, like Ctrl+E and Ctrl+M.
##
## It stops in the store first, on the last day, with a dealership upgrade to
## pick (no free card), LAST_FIGHT_PURCHASES cards for sale and
## LAST_FIGHT_UPGRADES of yours to upgrade, and enough money that none of it is
## out of reach: build the deck to test the fight with. Leaving the store goes
## straight to the final boss. Nothing of it is filed among the scores - after
## the fight, it is back to the menu.
func _debug_last_fight() -> void:
	_new_run()
	_practice_run = true
	_straight_to_the_boss = true
	_run.shift_number = _run.cfg.shifts_in_run
	var store := ShiftProfile.new()
	store.cards_for_sale = LAST_FIGHT_PURCHASES
	store.upgrades = LAST_FIGHT_UPGRADES
	store.dealership_upgrades = LAST_FIGHT_DEALERSHIP_UPGRADES
	var shop := Shop.new(_run, store)
	# A dealership upgrade instead of the free card.
	shop.free_cards.clear()
	shop.free_picks_left = 0
	_run.money = shop.cost_of_everything()
	_show_only(_shop_view)
	_shop_view.setup(shop)

## A fresh RunState with nothing worked yet - built behind the title screen
## too, since the practice shift borrows its config and pools. Dealt from
## `seed_value`, or a new seed; nothing of it is saved until a day begins.
func _new_run(seed_value: int = -1) -> void:
	_profiles = load("res://data/shift_profile_pool.tres")
	_run = RunState.new(load("res://data/shift_config.tres"),
		load("res://data/interests/interest_pool.tres"),
		load("res://data/card_pool.tres"),
		load("res://data/archetype_pool.tres"), seed_value if seed_value >= 0 else randi(),
		load("res://data/dialogue/dialogue_pool.tres"), _profiles,
		load("res://data/dealership_upgrades/upgrade_pool.tres"))
	_history = []
	_practice_run = false
	_straight_to_the_boss = false
	_save = null
	_live_shift = null
	_live_shop = null

## The title screen, on its menu - or, `intro`, on a new game's first day.
func _open_the_title(intro: bool = false) -> void:
	_show_only(_title_view)
	if intro:
		_title_view.show_intro()
	else:
		_title_view.show_menu()
	var saved := RunFile.read()
	_title_view.offer_continue(saved.day() if saved != null else 0)

func _open_the_picker() -> void:
	_show_only(_picker_view)
	_set_up_the_calendar(null)
	if _calendar_note != "":
		_picker_view.note(_calendar_note)
		_calendar_note = ""

## The start of a day: the week just worked gets its report first when this day
## begins a new one, then the calendar.
func _open_the_day() -> void:
	if _run.week_starts_today():
		_show_only(_week_view)
		_week_view.setup(_run, _history)
		return
	_open_the_picker()

## The calendar for today - to pick from, or with `working`, to look at from
## the floor while working that shift.
func _set_up_the_calendar(working: ShiftProfile) -> void:
	_picker_view.setup(_run.todays_shifts(), _run.shift_number, _run.cfg.shifts_in_run,
		_run.quota_for(_run.shift_number), _history, _run.cfg.days_per_week,
		_run.cfg.paycheck_in_week(_run.week_of(_run.shift_number)),
		_week_product_quotas(), working)

## VIEW CALENDAR, from the floor: the week laid over it, nothing to pick, and
## the floor's own HUD put away until it closes - the deck viewer's trick.
func _open_the_calendar_view() -> void:
	_calendar_open = true
	_set_up_the_calendar(_chosen_profile)
	_picker_view.visible = true
	_view_calendar_btn.visible = false
	_shift_view.set_hud_dimmed(true)

func _close_the_calendar_view() -> void:
	_calendar_open = false
	_picker_view.visible = false
	_view_calendar_btn.visible = true
	_shift_view.set_hud_dimmed(_deck_viewer.visible)

## The boss's product quota for every day of this week that has one - not a
## boss day's, which is its own test.
func _week_product_quotas() -> Dictionary:
	var per_week: int = maxi(1, _run.cfg.days_per_week)
	var first: int = (_run.shift_number - 1) / per_week * per_week + 1
	var out := {}
	for day in range(first, mini(first + per_week, _run.cfg.shifts_in_run + 1)):
		var offers: Array[ShiftProfile] = _run.week.offers(day) if _run.week != null else []
		if offers.size() == 1 and offers[0].is_boss_day():
			continue
		var q := _run.category_quota(day)
		if not q.is_empty():
			out[day] = q
	return out

func _on_profile_chosen(profile: ShiftProfile) -> void:
	_chosen_profile = profile
	if _save != null:
		_save.picked(_run, profile)
	_open_the_floor()

func _open_the_floor() -> void:
	_show_only(_shift_view)
	var shift := _run.start_shift(_chosen_profile)
	_live_shift = shift
	if _save != null:
		_save.shift_commands = shift.commands
	# Worked at the profile's own time of day - the office windows and the
	# tablet's clock both follow it.
	_shift_view.setup(shift, _run.standing, _chosen_profile.worked_at())
	_keep_the_save_current()

## The practice shift, on the same floor the real ones use. Dealt from its own
## starter deck (see Tutorial), so nothing done in practice touches the run.
func _open_the_tutorial() -> void:
	_in_tutorial = true
	_show_only(_shift_view)
	# A first day starts in the morning.
	_shift_view.setup(Tutorial.build_shift(_run.cfg, _run.interests, _run.card_pool,
		_run.archetypes, _run.dialogue), _run.standing, &"morning")
	_coach.start(_shift_view)

## Finished or skipped, it is done and remembered. Finished - its last button
## is START MY FIRST SHIFT - goes on to a new game's first day; skipped or
## exited goes back to the menu it was opened from.
func _on_tutorial_finished(completed: bool) -> void:
	_in_tutorial = false
	_coach.stop()
	TutorialProgress.mark_done()
	_open_the_title(completed)

func _on_shift_finished(report: Dictionary) -> void:
	# The practice clock running out is the practice being over - never a
	# report the run keeps, or a trip to the shop.
	if _in_tutorial:
		_on_tutorial_finished(false)
		return
	# A last-fight shortcut: the report was the point. Nothing of it is the run's
	# to keep - not a week for the summary, not a line on the high scores.
	if _practice_run:
		_shift_view.set_active(false)
		_new_run()
		_open_the_title()
		return
	_history.append({"profile": _chosen_profile, "report": report})
	_run.finish_shift(report)
	if _run.is_over():
		# Nothing left to pick up.
		RunFile.clear()
		_save = null
		# Neither the floor nor the shop - the run stops here, on top of
		# whichever of them the last shift ended on, the same way that
		# shift's own ReportOverlay already sits on top of the floor.
		_shift_view.set_active(false)
		_shop_view.visible = false
		# Filed among this device's personal bests before the boss's email is
		# written, so the email can say where the week landed.
		var tally := Score.tally(_run)
		var fired := _run.standing <= 0
		var rank := PlayerProfile.record_run(int(tally["total"]),
			int(tally["margin_banked"]), fired)
		# And onto everyone's board, under the name on your badge.
		_title_view.post_score(PlayerProfile.display_name(), int(tally["total"]),
			int(tally["margin_banked"]), fired)
		_summary_view.setup(tally, fired, rank)
		_summary_view.visible = true
		return
	# The shop is what the JUST-PLAYED shift's tier adds to the free card, not
	# whatever gets picked next - so it goes in before the picker is shown
	# again. Anything past the free card costs money from the bonus pot, which
	# only beating quota fills - so failing a harder tier buys nothing it did
	# not already have saved.
	var shop := Shop.new(_run, _chosen_profile)
	_live_shop = shop
	if _save != null:
		_save.shop_open = true
		_save.shop_commands = shop.commands
		_write_the_save()
	_show_only(_shop_view)
	_shop_view.setup(shop)

func _on_summary_continue() -> void:
	_summary_view.visible = false
	# Back to the front door, where the week just filed is on the high scores.
	_new_run()
	_open_the_title()

## The store closes on the next day's calendar - unless that day starts a new
## week, when the week just worked gets its report first.
func _on_shop_done() -> void:
	# The last-fight shortcut: from the store to the boss, no calendar between.
	if _straight_to_the_boss:
		_straight_to_the_boss = false
		for p in _run.todays_shifts():
			if p.is_boss_day():
				_chosen_profile = p
				_open_the_floor()
				return
	_begin_the_day()
	_open_the_day()

func _on_view_deck_requested() -> void:
	_deck_viewer.show_deck(_run)

## Exactly one of the four screens visible at a time. ShiftView is a Node3D,
## not a Control (the table), which is why this takes a plain Node - and it
## alone carries an "active" flag beyond plain visibility (see set_active()
## below, unchanged from before this screen existed); every other screen is
## fully described by .visible.
func _show_only(screen: Node) -> void:
	_shift_view.set_active(screen == _shift_view)
	_picker_view.visible = screen == _picker_view
	_shop_view.visible = screen == _shop_view
	_week_view.visible = screen == _week_view
	_title_view.visible = screen == _title_view
	# No toolkit to look at from the front door.
	_view_deck_btn.visible = screen != _title_view
	# The calendar from the floor - not in practice, which has no week.
	_calendar_open = false
	_view_calendar_btn.visible = screen == _shift_view and not _in_tutorial
	# The shortcut to the last fight: from the front door only.
	_last_fight_tap.visible = screen == _title_view
