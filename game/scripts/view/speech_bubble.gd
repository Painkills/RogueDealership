class_name SpeechBubble extends Control
## A customer's own words, overlaid on their own card face instead of living
## only in the shift log. The log is scrollback you have to go read; the table
## is what you glance at to decide who needs you next, and until now nothing
## there told you a customer had just said something.
##
## Over their INTEREST GRID, never their name or patience (see
## build_customer_front_scene.gd's GRID_TOP). It used to cover the name row,
## which put a line of dialogue over the patience meter - the one number that
## says how long you have with them.
##
## Part of customer_front_2d.tscn's own canvas, not a separate mesh - the
## card's own face already reliably faces the camera through whatever the
## seat/carousel is doing, and a texture baked onto it inherits that for free.
##
## Timed in TICKS, not seconds - every other clock in this game (demand
## fuses, walk-up delays) is ticks, and "how long you have to notice this"
## should mean the same thing here rather than a wall-clock timer running
## alongside a clock that can itself be frozen (the report overlay, the shop).

## At the desk you are sitting at, the grid underneath is what you are working
## from, so the bubble gets out of the way: one tick, or a look at them.
const AT_YOUR_DESK_TICKS := 1
## At a desk you are not at, it is how you hear that someone said something at
## all, so it stays long enough to be noticed.
const SIDE_SEAT_TICKS := 3

@onready var _panel: PanelContainer = $Panel
@onready var _label: Label = $Panel/Label

## The tick say() was called on. -9999 so a fresh card (never spoken to)
## reads as "long expired" rather than "just started," if update_visibility()
## is ever called before the first say().
var _shown_tick: int = -9999

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

func say(text: String, tick: int) -> void:
	if text == "":
		return
	_label.text = text
	_shown_tick = tick
	visible = true

## Called every render pass (customer_card_3d.gd's setup()) so the bubble can
## time itself out against the tick it was actually shown on, the same way a
## demand's own countdown is `tick >= due_tick` rather than a Timer racing the
## game's own pace. `lifetime` is AT_YOUR_DESK_TICKS or SIDE_SEAT_TICKS,
## depending on where this customer is sitting relative to you.
func update_visibility(tick: int, lifetime: int = SIDE_SEAT_TICKS) -> void:
	if visible and tick - _shown_tick >= lifetime:
		visible = false

## Gone now, whatever the clock says - you looked at them.
func hush() -> void:
	visible = false
