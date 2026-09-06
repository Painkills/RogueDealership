extends Node
## The run: five shifts with a shop between them.
##
## Owns the RunState and does nothing else - the shift screen plays a shift, the
## shop screen sells cards, and this decides which one you are looking at. That
## split is the whole reason shift_controller.gd stopped building its own shift:
## it is already the table, the framing, the HUD and reconciliation.

@onready var _shift_view = $ShiftView
@onready var _shop_view = $ShopView

var _run: RunState

func _ready() -> void:
	_shift_view.shift_finished.connect(_on_shift_finished)
	_shop_view.done.connect(_on_shop_done)
	_start_run()

func _start_run() -> void:
	_run = RunState.new(load("res://data/shift_config.tres"),
		load("res://data/interests/interest_pool.tres"),
		load("res://data/card_pool.tres"),
		load("res://data/archetype_pool.tres"), randi())
	_open_the_floor()

func _open_the_floor() -> void:
	_show_shop(false)
	_shift_view.setup(_run.start_shift())

func _on_shift_finished(report: Dictionary) -> void:
	_run.finish_shift(report)
	if _run.is_over():
		# The run is done. Until there is an end-of-run screen, roll a new one -
		# the alternative is a dead button on a finished report. Rolling it
		# silently would be indistinguishable from the deck-persistence bug this
		# milestone exists to prevent, so the end of the run is made legible here
		# through the same channel every other tool in this project reports
		# through, even though there is no screen for it yet.
		print("run finished: banked %d across %d shifts"
			% [_run.banked_total, _run.cfg.shifts_in_run])
		_start_run()
		return
	_show_shop(true)
	_shop_view.setup(Shop.new(_run))

func _on_shop_done() -> void:
	_open_the_floor()

func _show_shop(on: bool) -> void:
	_shift_view.set_active(not on)
	_shop_view.visible = on
