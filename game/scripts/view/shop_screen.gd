extends PanelContainer
## The store between shifts: a few cards on the house every visit to pick one
## from, the card for sale if the shift you just worked put one up, and a few
## of your own to upgrade if it lets you. Every one of them is a real card you click, not a
## text row.
##
## Your own cards here are Shop.upgrade_offers, not the whole deck - a random
## few, rolled once per visit, and only ever cards with a real upgrade to sell
## (Shop._roll_upgrade_offers() puts nothing else there). Dropping one is on
## the same card, beside upgrading it.
##
## Rebuilds every aisle after every action rather than patching them - a visit
## is a handful of clicks on at most five cards, and a full rebuild cannot
## disagree with the deck the way an incremental patch can.

signal done
## RunController owns the actual DeckViewer - reachable from the floor too
## (clicking the draw pile), so it is a RunController-level overlay rather
## than something this screen instances itself. See deck_viewer.gd's own
## header comment on why one shared node beats a second instance.
signal view_deck_requested

@onready var _money: Label = %MoneyLabel
@onready var _shift_label: Label = %ShiftLabel
@onready var _shift_tap: Button = %ShiftTapTarget
@onready var _free_row: HBoxContainer = %FreeRow
@onready var _shelf_row: HBoxContainer = %ShelfRow
@onready var _deck_row: HBoxContainer = %DeckRow
@onready var _log: Label = %LogLabel
@onready var _done: Button = %DoneButton
@onready var _view_deck: Button = %ViewDeckButton
@onready var _detail: ShopCardDetail = %Detail
## Who the portal says is signed in - whoever wrote their name on the welcome's
## name tag (see PlayerProfile).
@onready var _account: Label = %AccountLabel

var _shop: Shop

func _ready() -> void:
	_done.pressed.connect(func(): done.emit())
	_view_deck.pressed.connect(func(): view_deck_requested.emit())
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
	_account.text = PlayerProfile.display_name()
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
	# Smaller and dimmer than the money line on purpose - this is context for
	# what is on offer below, not a number that needs the same weight as the
	# budget you actually have to spend.
	_shift_label.text += "\n" + _shop.perk_text()

	# Not in your toolkit yet - a real CardInstance can only exist once
	# something owns it. A throwaway one (uid -1, never persisted, never
	# touching the model) is enough to feed the SAME card face the deck uses,
	# so a card on offer looks exactly like what it will look like once yours.
	_clear(_free_row)
	if _shop.free_picks_left > 0:
		for free in _shop.free_cards:
			_build_slot(_free_row, CardInstance.new(free, -1), "FREE").pressed.connect(
				func(): _detail.show_free_card(_shop, free))
	# Picked: the others go with it, until the next shift's three.
	if _shop.free_taken != null:
		_note(_free_row, "Taken - the %s is in your toolkit now."
			% _shop.free_taken.display_name)
	elif _free_row.get_child_count() == 0:
		_note(_free_row, "Nothing on the house this visit.")

	_clear(_shelf_row)
	for def in _shop.offers:
		_build_slot(_shelf_row, CardInstance.new(def, -1),
			Format.price(_shop.buy_price(def))).pressed.connect(
				func(): _detail.show_shelf_card(_shop, def))
	if _shelf_row.get_child_count() == 0:
		# Bought, or never stocked: an aisle with nothing in it says which,
		# rather than standing there empty like the page failed to load.
		_note(_shelf_row, "Sold - it is in your toolkit now." if _shop.cards_for_sale > 0
			else "Nothing for sale after that shift.")

	_clear(_deck_row)
	for uid in _shop.upgrade_offers:
		var inst := _shop.find(uid)
		if inst == null:
			continue   # already dropped this visit
		_build_slot(_deck_row, inst, _upgrade_label(inst)).pressed.connect(
			func(): _detail.show_card(_shop, inst))
	if _deck_row.get_child_count() == 0:
		_note(_deck_row, "Nothing of yours left to upgrade." if _shop.upgrades > 0
			else "No upgrade after that shift.")

## What sits under one of your cards: what upgrading it costs - or, once the
## visit's upgrade is spent, that it is. The cards stay on show either way, so
## you can still see which one you chose.
func _upgrade_label(inst: CardInstance) -> String:
	if inst.upgraded:
		return "upgraded"
	if _shop.upgrades_left <= 0:
		return "upgrade used"
	return "upgrade %s" % Format.price(_shop.upgrade_price(inst))

## remove_child() first: queue_free() alone leaves a node in get_children()
## until the next idle frame, which is exactly the gap a second action within
## the same frame (an upgrade immediately followed by a drop, say) would fall
## into - counting stale AND fresh slots both.
func _clear(row: HBoxContainer) -> void:
	for child in row.get_children():
		row.remove_child(child)
		child.queue_free()

func _note(row: HBoxContainer, text: String) -> void:
	var note := Label.new()
	note.name = "EmptyNote"
	note.text = text
	note.autowrap_mode = TextServer.AUTOWRAP_WORD
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# In the middle of the aisle, which stays a card's height either way.
	note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# The whole aisle's width to wrap in - an autowrapping label claims none
	# of its own.
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.add_theme_font_size_override("font_size", 22)
	note.add_theme_color_override("font_color", Palette.color(&"text_dim"))
	row.add_child(note)

## One card on offer: its rarity over it, the card itself (the thing you
## click), and what it costs under it. Returns the card.
func _build_slot(row: HBoxContainer, inst: CardInstance, price_text: String) -> ShopCardButton:
	var slot := VBoxContainer.new()
	slot.add_theme_constant_override("separation", 4)
	slot.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(slot)

	# Store-only, not on the card itself - a corner badge on the card face
	# made every card busier everywhere it appears (hand, table, deck
	# viewer), for a fact that only matters here, while you are shopping.
	# Small: this is a third row stacked into every slot, and the screen's
	# whole vertical budget was already tuned tight before it existed.
	var rarity := Label.new()
	rarity.add_theme_font_size_override("font_size", 12)
	rarity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity.text = CardText.rarity_name(inst)
	rarity.add_theme_color_override("font_color", Palette.rarity_color(inst.card.rarity))
	slot.add_child(rarity)

	var card: ShopCardButton = (load("res://scenes/cards/shop_card_button.tscn") \
		as PackedScene).instantiate()
	slot.add_child(card)
	card.show_card(inst)

	var price := Label.new()
	price.add_theme_font_size_override("font_size", 20)
	price.add_theme_color_override("font_color", Palette.color(&"margin"))
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price.text = price_text
	slot.add_child(price)
	return card

func _apply(res: Result) -> void:
	## A refusal costs nothing but must still say why - the same rule the shift
	## screen follows.
	_log.text = res.msg
	_log.add_theme_color_override("font_color",
		Palette.color(&"text_dim" if res.ok else &"alert"))
	_render()
