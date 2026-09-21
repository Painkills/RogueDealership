class_name SpeechBubble extends Control
## A customer's own words, overlaid on the top of their own card face -
## covering the name/archetype row for a couple of ticks - instead of living
## only in the shift log. The log is scrollback you have to go read; the
## table is what you glance at to decide who needs you next, and until now
## nothing there told you a customer had just said something.
##
## Part of customer_front_2d.tscn's own 500x700 canvas (see
## build_customer_front_scene.gd), not a separate mesh - the card's own face
## already reliably faces the camera through whatever the seat/carousel is
## doing, and a texture baked onto it inherits that for free. An earlier
## version tried a separate floating billboard above the card instead; it
## never reliably faced the camera the way the card itself already does.
##
## Timed in TICKS, not seconds - every other clock in this game (demand
## fuses, walk-up delays) is ticks, and "how long you have to notice this"
## should mean the same thing here rather than a wall-clock timer running
## alongside a clock that can itself be frozen (the report overlay, the shop).
const HIDE_AFTER_TICKS := 2

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

## Called every render pass (customer_card_3d.gd's setup()) so the bubble
## can time itself out against the tick it was actually shown on, the same
## way a demand's own countdown is `tick >= due_tick` rather than a Timer
## racing the game's own pace.
func update_visibility(tick: int) -> void:
	if visible and tick - _shown_tick >= HIDE_AFTER_TICKS:
		visible = false
