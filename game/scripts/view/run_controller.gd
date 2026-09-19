extends Node
## The run: five shifts with a shop between them.
##
## Owns the RunState and does nothing else - the shift screen plays a shift, the
## shop screen sells cards, and this decides which one you are looking at. That
## split is the whole reason shift_controller.gd stopped building its own shift:
## it is already the table, the framing, the HUD and reconciliation.

@onready var _shift_view = $ShiftView
@onready var _shop_view = $ShopView
@onready var _summary_view = $RunSummaryView
@onready var _build_label: Label = $BuildBadge/BuildLabel

var _run: RunState

func _ready() -> void:
	_shift_view.shift_finished.connect(_on_shift_finished)
	_shop_view.done.connect(_on_shop_done)
	_summary_view.continue_pressed.connect(_on_summary_continue)
	# NOT left to whatever build_run_scene.gd happened to bake into run.tscn
	# at author time: that text is a static property of a committed scene
	# file, frozen the moment the builder ran locally, and CI stamps
	# BuildInfo.LABEL's SOURCE long after that scene was already generated
	# and checked in. Reading it here, at actual startup, is what makes the
	# badge answer "what build is this" rather than "what build was it when
	# someone last ran the builder."
	_build_label.text = BuildInfo.LABEL
	_start_run()

func _start_run() -> void:
	_run = RunState.new(load("res://data/shift_config.tres"),
		load("res://data/interests/interest_pool.tres"),
		load("res://data/card_pool.tres"),
		load("res://data/archetype_pool.tres"), randi(),
		load("res://data/dialogue/dialogue_pool.tres"))
	_open_the_floor()

func _open_the_floor() -> void:
	_show_shop(false)
	_shift_view.setup(_run.start_shift(), _run.standing)

func _on_shift_finished(report: Dictionary) -> void:
	_run.finish_shift(report)
	if _run.is_over():
		# Neither the floor nor the shop - the run stops here, on top of
		# whichever of them the last shift ended on, the same way that
		# shift's own ReportOverlay already sits on top of the floor.
		_shift_view.set_active(false)
		_shop_view.visible = false
		_summary_view.setup(Score.tally(_run), _run.standing <= 0)
		_summary_view.visible = true
		return
	_show_shop(true)
	_shop_view.setup(Shop.new(_run))

func _on_summary_continue() -> void:
	_summary_view.visible = false
	_start_run()

func _on_shop_done() -> void:
	_open_the_floor()

func _show_shop(on: bool) -> void:
	_shift_view.set_active(not on)
	_shop_view.visible = on
