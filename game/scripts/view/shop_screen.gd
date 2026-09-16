extends PanelContainer
## The shop between shifts: buy from the shelf, edit what is already in the
## deck. Both are real cards you click, not a text row.
##
## The deck section shows Shop.upgrade_offers, not the whole deck - a
## random, capped subset re-rolled once per visit, the same shape the
## shelf's own offers already have. Only a card with a real upgrade to sell
## lands in that list (Shop._roll_upgrade_offers() only ever puts one there
## on those terms), so a card with nothing to upgrade does not appear here
## at all - not even to drop it. A deliberate scope cut for now: every card
## shown here supports "upgrade or drop", and nothing shown here supports
## only one of those two.
##
## Rebuilds both rows after every action rather than patching them - a visit
## is a handful of clicks on at most six cards, and a full rebuild cannot
## disagree with the deck the way an incremental patch can.

signal done

@onready var _money: Label = %MoneyLabel
@onready var _shift_label: Label = %ShiftLabel
@onready var _shift_tap: Button = %ShiftTapTarget
@onready var _shelf_row: HBoxContainer = %ShelfRow
@onready var _deck_row: HBoxContainer = %DeckRow
@onready var _log: Label = %LogLabel
@onready var _done: Button = %DoneButton
@onready var _detail: ShopCardDetail = %Detail

var _shop: Shop

func _ready() -> void:
	_done.pressed.connect(func(): done.emit())
	_detail.action_taken.connect(_apply)
	_bind_key(&"debug_add_money", KEY_M, true)   # Ctrl+M: +$10,000, for testing
	# Mobile has no Ctrl+M: an invisible button laid over the quota line
	# itself is the touch equivalent, wired to the exact same effect.
	_shift_tap.pressed.connect(_debug_add_money)

func _bind_key(action: StringName, keycode: Key, ctrl: bool = false) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	if not InputMap.action_get_events(action).is_empty():
		return
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.ctrl_pressed = ctrl
	InputMap.action_add_event(action, ev)

## Ctrl+M, shop only: a manual testing convenience, not a mechanic. Guarded
## on visible rather than a lifecycle flag - unlike ShiftController, this
## screen is never told when it stops being the active one, only toggled by
## RunController's own .visible assignment.
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("debug_add_money"):
		_debug_add_money()

func _debug_add_money() -> void:
	_shop.run.money += 10000
	_render()

func setup(shop: Shop) -> void:
	_shop = shop
	_log.text = ""
	_detail.visible = false
	_render()

func _render() -> void:
	var run := _shop.run
	# Name what this pot IS and what just went into it. The budget stacks across
	# the run, so a total on its own cannot tell you whether the shift you just
	# played earned anything - and that is the number you came here to find out.
	_money.text = "Bonus to spend: %s" % Format.money(run.money)
	if run.last_bonus > 0:
		_money.text += "   (+%s from that shift)" % Format.money(run.last_bonus)
	elif not run.reports.is_empty():
		_money.text += "   (no bonus that shift)"
	_money.text += "   |   Standing: %d/%d" % [run.standing, run.cfg.standing_start]
	_shift_label.text = "shift %d of %d next - quota %s" % [run.shift_number,
		run.cfg.shifts_in_run, Format.money(run.quota_for(run.shift_number))]

	# remove_child() first: queue_free() alone leaves a node in
	# get_children() until the next idle frame, which is exactly the gap a
	# second action within the same frame (an upgrade immediately followed by
	# a drop, say) would fall into - counting stale AND fresh slots both.
	for child in _shelf_row.get_children():
		_shelf_row.remove_child(child)
		child.queue_free()
	for def in _shop.offers:
		# Not on the deck yet - a real CardInstance can only exist once
		# something owns it. A throwaway one (uid -1, never persisted, never
		# touching the model) is enough to feed the SAME card face the deck
		# uses, so an offer looks exactly like what it will look like the
		# moment you actually buy it.
		var preview_inst := CardInstance.new(def, -1)
		var slot := _build_slot(_shelf_row)
		(slot["card"] as ShopCardButton).show_card(preview_inst)
		(slot["price"] as Label).text = Format.money(_shop.buy_price(def))
		(slot["card"] as ShopCardButton).pressed.connect(func(): _apply(_shop.buy(def)))

	for child in _deck_row.get_children():
		_deck_row.remove_child(child)
		child.queue_free()
	for uid in _shop.upgrade_offers:
		var inst := _shop.find(uid)
		if inst == null:
			continue   # already dropped this visit
		var slot := _build_slot(_deck_row)
		(slot["card"] as ShopCardButton).show_card(inst)
		(slot["price"] as Label).text = "upgraded" if inst.upgraded \
			else "upgrade %s" % Format.money(_shop.upgrade_price(inst))
		(slot["card"] as ShopCardButton).pressed.connect(func(): _detail.show_card(_shop, inst))

func _build_slot(row: HBoxContainer) -> Dictionary:
	var slot := VBoxContainer.new()
	slot.add_theme_constant_override("separation", 6)
	slot.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(slot)

	var card: ShopCardButton = (load("res://scenes/cards/shop_card_button.tscn") \
		as PackedScene).instantiate()
	slot.add_child(card)

	var price := Label.new()
	price.add_theme_font_size_override("font_size", 20)
	price.add_theme_color_override("font_color", Palette.color(&"margin"))
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot.add_child(price)

	return {"card": card, "price": price}

func _apply(res: Result) -> void:
	## A refusal costs nothing but must still say why - the same rule the shift
	## screen follows.
	_log.text = res.msg
	_log.add_theme_color_override("font_color",
		Palette.color(&"text_dim" if res.ok else &"alert"))
	_render()
