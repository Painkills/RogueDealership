extends Node
## The run: a picked shift, played, a shop after it, then pick again.
##
## Owns the RunState and does nothing else - the picker chooses a
## ShiftProfile, the shift screen plays a shift under it, the shop screen
## sells cards (gated by that same profile's reward), and this decides which
## one you are looking at. That split is the whole reason
## shift_controller.gd stopped building its own shift: it is already the
## table, the framing, the HUD and reconciliation.

@onready var _picker_view = $ShiftPickerView
@onready var _shift_view = $ShiftView
@onready var _shop_view = $ShopView
@onready var _summary_view = $RunSummaryView
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
## The practice shift's teacher - see scripts/run/tutorial.gd for the shift
## and tutorial_coach.gd for the lesson.
@onready var _coach: TutorialCoach = $TutorialCoach

## Open the game on the practice shift - every time, not just the first. Its
## welcome has a way out as big as the way in, and for someone who has been
## through it before (TutorialProgress remembers) the way out is the loud one.
## A driver that is testing something else turns this off BEFORE adding the
## run to the tree, so it boots straight to the picker. The picker's HOW TO
## PLAY button replays it either way.
@export var tutorial_at_boot := true

var _run: RunState
var _profiles: ShiftProfilePool
var _chosen_profile: ShiftProfile
## True while the floor is playing the practice shift rather than one of the
## run's: its end goes back to the picker, and never to a report or the shop.
var _in_tutorial := false
## One {"profile", "report"} per shift worked this run, in order - the picker's
## calendar shows each past day as the shift you took and how it went.
var _history: Array = []

func _ready() -> void:
	_picker_view.chosen.connect(_on_profile_chosen)
	_shift_view.shift_finished.connect(_on_shift_finished)
	_shift_view.deck_viewed.connect(_on_view_deck_requested)
	_shop_view.done.connect(_on_shop_done)
	_shop_view.view_deck_requested.connect(_on_view_deck_requested)
	_view_deck_btn.pressed.connect(_on_view_deck_requested)
	# The deck viewer sits in front of the floor visually, but its own action
	# column and shift log live in the floor's HUD CanvasLayer - drawn by
	# layer, not tree order, so they would otherwise keep showing through
	# regardless of which of the three entry points opened it, or how it
	# gets closed. Control's own visibility_changed catches every path.
	_deck_viewer.visibility_changed.connect(
		func(): _shift_view.set_hud_dimmed(_deck_viewer.visible))
	_summary_view.continue_pressed.connect(_on_summary_continue)
	# NOT left to whatever build_run_scene.gd happened to bake into run.tscn
	# at author time: that text is a static property of a committed scene
	# file, frozen the moment the builder ran locally, and CI stamps
	# BuildInfo.LABEL's SOURCE long after that scene was already generated
	# and checked in. Reading it here, at actual startup, is what makes the
	# badge answer "what build is this" rather than "what build was it when
	# someone last ran the builder."
	_build_label.text = BuildInfo.LABEL
	_coach.finished.connect(_on_tutorial_finished)
	_picker_view.tutorial_requested.connect(_open_the_tutorial)
	_start_run()
	if tutorial_at_boot:
		_open_the_tutorial()

func _start_run() -> void:
	_run = RunState.new(load("res://data/shift_config.tres"),
		load("res://data/interests/interest_pool.tres"),
		load("res://data/card_pool.tres"),
		load("res://data/archetype_pool.tres"), randi(),
		load("res://data/dialogue/dialogue_pool.tres"))
	_profiles = load("res://data/shift_profile_pool.tres")
	_history = []
	_open_the_picker()

func _open_the_picker() -> void:
	_show_only(_picker_view)
	_picker_view.setup(_profiles, _run.shift_number, _run.cfg.shifts_in_run,
		_run.quota_for(_run.shift_number), _history)

func _on_profile_chosen(profile: ShiftProfile) -> void:
	_chosen_profile = profile
	_open_the_floor()

func _open_the_floor() -> void:
	_show_only(_shift_view)
	_shift_view.setup(_run.start_shift(_chosen_profile), _run.standing)

## The practice shift, on the same floor the real ones use. Dealt from its own
## starter deck (see Tutorial), so nothing done in practice touches the run.
func _open_the_tutorial() -> void:
	_in_tutorial = true
	_show_only(_shift_view)
	_shift_view.setup(Tutorial.build_shift(_run.cfg, _run.interests, _run.card_pool,
		_run.archetypes, _run.dialogue), _run.standing)
	_coach.start(_shift_view)

## Finished or skipped, it is done: remembered, and back to the picker for
## the run's first real shift.
func _on_tutorial_finished(_completed: bool) -> void:
	_in_tutorial = false
	_coach.stop()
	TutorialProgress.mark_done()
	_open_the_picker()

func _on_shift_finished(report: Dictionary) -> void:
	# The practice clock running out is the practice being over - never a
	# report the run keeps, or a trip to the shop.
	if _in_tutorial:
		_on_tutorial_finished(false)
		return
	_history.append({"profile": _chosen_profile, "report": report})
	_run.finish_shift(report)
	if _run.is_over():
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
		_summary_view.setup(tally, fired, rank)
		_summary_view.visible = true
		return
	# The shop's reward gating is what the JUST-PLAYED shift's profile earned,
	# not whatever gets picked next - so it goes in before the picker is
	# shown again. And it is EARNED, not just picked: missing quota already
	# costs standing and leaves the bonus pot untouched, and a free upgrade on
	# top of that would make picking a harder tier and then failing it better
	# than picking morning and succeeding.
	_show_only(_shop_view)
	_shop_view.setup(Shop.new(_run, _chosen_profile, bool(report.get("made_quota", false))))

func _on_summary_continue() -> void:
	_summary_view.visible = false
	_start_run()

func _on_shop_done() -> void:
	_open_the_picker()

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
