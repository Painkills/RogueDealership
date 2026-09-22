extends PanelContainer
## The mid-shift "reveal N, keep one" popup PullCards.apply() stages via
## Shift.pending_pull - the third multi-step player decision in this game
## (after approach/offer/close and the shift tier picker), and the first
## that lives entirely inside the floor's own HUD rather than swapping
## screens for it.
##
## PullRow is built EMPTY (see build_pull_picker_scene.gd's own comment) and
## filled here at runtime: how many chips there are is data
## (Shift.pending_pull.revealed's own size), the same reason
## deck_viewer.gd builds its own rows at runtime instead of the scene
## builder baking a fixed count.

signal card_chosen(index: int)
signal cancel_pressed

const CHIP_SIZE := Vector2(180, 252)

var _title: Label
var _row: HBoxContainer
var _cancel: Button
var _bound := false

func _ready() -> void:
	_bind()

## Plain fields, resolved lazily rather than @onready: a bare .instantiate()
## in a test never fires _ready(), the same gap CardFace3D/ReportPanel/
## DetailCard3D already hit and fixed the same way.
func _bind() -> void:
	if _bound:
		return
	_bound = true
	_title = %PullTitleLabel
	_row = %PullRow
	_cancel = %PullCancelButton
	_cancel.pressed.connect(func(): cancel_pressed.emit())

func show_pull(pending: PendingPull) -> void:
	_bind()
	_title.text = "CHOOSE ONE (%d revealed)" % pending.revealed.size()
	for child in _row.get_children():
		_row.remove_child(child)
		child.queue_free()
	for i in range(pending.revealed.size()):
		var card: ShopCardButton = (load("res://scenes/cards/shop_card_button.tscn") \
			as PackedScene).instantiate()
		card.custom_minimum_size = CHIP_SIZE
		card.size = CHIP_SIZE
		_row.add_child(card)
		card.show_card(pending.revealed[i])
		card.pressed.connect(func(): card_chosen.emit(i))
	visible = true

func hide_pull() -> void:
	visible = false
