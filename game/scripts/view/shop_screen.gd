extends PanelContainer
## The store between shifts. Every visit opens on a popup first - a few cards
## on the house, to pick one from, or pass - and then the store itself: the
## cards the shift you just worked put up for sale, and a few of your own it
## offers to upgrade. Buy or upgrade as many as the bonus covers. Every one of
## them is a real card you click, not a text row.
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
## The free pick - see build_shop_scene.gd's _free_pick().
@onready var _free_pick: Control = %FreePick
@onready var _free_pick_row: HBoxContainer = %FreePickRow
@onready var _skip_free: Button = %SkipFreeButton
## A night store's dealership upgrade - see build_shop_scene.gd's
## _dealership_pick(). Up before the free pick, until one is taken.
@onready var _dealership_pick: Control = %DealershipPick
@onready var _dealership_row: HBoxContainer = %DealershipRow
@onready var _shelf_row: HBoxContainer = %ShelfRow
@onready var _deck_row: HBoxContainer = %DeckRow
## The aisles around those rows, and what stands in for both when the shift
## stocks neither - see _lay_out_the_aisles().
@onready var _shelf_section: Control = %ShelfSection
@onready var _deck_section: Control = %DeckSection
@onready var _store_empty: Control = %StoreEmptyNote
@onready var _log: Label = %LogLabel
@onready var _done: Button = %DoneButton
@onready var _view_deck: Button = %ViewDeckButton
@onready var _detail: ShopCardDetail = %Detail
## Who the portal says is signed in - whoever wrote their name on the welcome's
## name tag (see PlayerProfile).
@onready var _account: Label = %AccountLabel

var _shop: Shop
## Past this many cards across both aisles they no longer fit side by side, and the
## store shows one aisle at a time, with a button for each - see
## _lay_out_the_aisles(). Five is what the page holds at full size.
const SIDE_BY_SIDE_MOST := 5
## One card on offer, as big as the page lets it be (the aisle holds six across).
const CARD_SIZE := Vector2(240, 336)
## Which aisle a paged store is showing: &"shelf" or &"deck".
var _aisle: StringName = &"shelf"
var _aisle_tabs: HBoxContainer
var _shelf_tab: Button
var _deck_tab: Button
## The aisles' own titles, which the buttons stand in for while the store is paged.
var _shelf_title: Control
var _deck_title: Control

func _ready() -> void:
	_build_aisle_tabs()
	_done.pressed.connect(func(): done.emit())
	_view_deck.pressed.connect(func(): view_deck_requested.emit())
	_detail.action_taken.connect(_apply)
	_skip_free.pressed.connect(func(): _apply(_shop.pass_on_free()))
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
	_shop.add_money_for_testing(10000)
	_render()

func setup(shop: Shop) -> void:
	_shop = shop
	_aisle = &"shelf"
	_log.text = ""
	_detail.visible = false
	_render()

func _render() -> void:
	var run := _shop.run
	_account.text = PlayerProfile.display_name()
	# Name what this pot IS and what just went into it. The budget stacks across
	# the run, so a total on its own cannot tell you whether the shift you just
	# played earned anything - and that is the number you came here to find out.
	_money.text = "Money to spend: %s" % Format.money(run.money)
	if run.last_bonus > 0:
		_money.text += "   (+%s from that shift)" % Format.money(run.last_bonus)
	elif not run.reports.is_empty():
		_money.text += "   (no pay that shift)"
	_money.text += "   |   Standing: %d/%d" % [run.standing, run.cfg.standing_start]
	_shift_label.text = "shift %d of %d next - quota %s" % [run.shift_number,
		run.cfg.shifts_in_run, Format.money(run.quota_for(run.shift_number))]
	# Smaller and dimmer than the money line on purpose - this is context for
	# what is on offer below, not a number that needs the same weight as the
	# budget you actually have to spend.
	_shift_label.text += "\n" + _shop.perk_text()
	if not run.dealership.is_empty():
		var names: Array[String] = []
		for u in run.dealership:
			names.append(u.display_name)
		_shift_label.text += "\nYour perks: " + ", ".join(names)

	# A night's dealership upgrade comes first, over everything - the free card
	# waits behind it.
	_clear(_dealership_row)
	var upgrading: bool = _shop.dealership_picks_left > 0
	_dealership_pick.visible = upgrading
	if upgrading:
		for u in _shop.dealership_offers:
			_dealership_row.add_child(_upgrade_button(u))

	# "First, you get a popup with the one out of three" - up until the pick is
	# made or passed on, over everything else here. Not in your toolkit yet - a
	# real CardInstance can only exist once something owns it. A throwaway one
	# (uid -1, never persisted, never touching the model) is enough to feed the
	# SAME card face the deck uses, so a card on offer looks exactly like what
	# it will look like once yours.
	_clear(_free_pick_row)
	var picking: bool = _shop.free_picks_left > 0 and not _shop.free_cards.is_empty() \
		and not upgrading
	_free_pick.visible = picking
	if picking:
		for free in _shop.free_cards:
			_build_slot(_free_pick_row, CardInstance.new(free, -1), "FREE").pressed.connect(
				func(): _detail.show_free_card(_shop, free))

	_lay_out_the_aisles()
	_clear(_shelf_row)
	for def in _shop.offers:
		_build_slot(_shelf_row, CardInstance.new(def, -1),
			Format.price(_shop.buy_price(def))).pressed.connect(
				func(): _detail.show_shelf_card(_shop, def))
	if _shelf_row.get_child_count() == 0:
		# Bought, or never stocked: an aisle with nothing in it says which,
		# rather than standing there empty like the page failed to load.
		_note(_shelf_row, "Sold out - it is all in your toolkit now." if _shop.cards_for_sale > 0
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
			else "No upgrades after that shift.")

## Only the aisles this shift stocks, each as wide as what it holds: five cards
## for sale take the whole store, two and two share it evenly. A shift that
## stocks neither (a boss, whose reward is the dealership) shows a note instead
## of two empty boxes. Sized by what the shift STOCKS, not what is left, so
## buying the shelf out does not shuffle the page under the pointer.
func _lay_out_the_aisles() -> void:
	var shelf_on := _shop.cards_for_sale > 0
	var deck_on := _shop.upgrades > 0
	_shelf_section.visible = shelf_on
	_deck_section.visible = deck_on
	_shelf_section.size_flags_stretch_ratio = maxf(1.0, float(_shop.cards_for_sale))
	_deck_section.size_flags_stretch_ratio = maxf(1.0, float(_shop.upgrades))
	_store_empty.visible = not shelf_on and not deck_on
	# Too many to fit across the page together: one aisle at a time, full size.
	var paged := shelf_on and deck_on \
		and _shop.cards_for_sale + _shop.upgrades > SIDE_BY_SIDE_MOST
	_aisle_tabs.visible = paged
	_shelf_title.visible = true
	_deck_title.visible = true
	if paged:
		_shelf_section.visible = _aisle == &"shelf"
		_deck_section.visible = _aisle == &"deck"
		# The buttons stand where the shown aisle's own title does, so the page is
		# no taller for them.
		var shown_section := _shelf_section if _aisle == &"shelf" else _deck_section
		var column := shown_section.get_node(^"Column") as Control
		if _aisle_tabs.get_parent() != column:
			if _aisle_tabs.get_parent() != null:
				_aisle_tabs.get_parent().remove_child(_aisle_tabs)
			column.add_child(_aisle_tabs)
		column.move_child(_aisle_tabs, 0)
		(_shelf_title if _aisle == &"shelf" else _deck_title).visible = false
		_shelf_tab.text = "FOR SALE  %d" % _shop.offers.size()
		_deck_tab.text = "UPGRADE YOUR CARDS  %d" % _shop.upgrade_offers.size()
		_dress_aisle_tab(_shelf_tab, _aisle == &"shelf")
		_dress_aisle_tab(_deck_tab, _aisle == &"deck")

## The two buttons that turn between the aisles of a store too big for both at
## once. Built here rather than in the scene: they are only ever on show then, and
## shop.tscn is a builder's output.
func _build_aisle_tabs() -> void:
	_shelf_title = _shelf_section.get_node(^"Column").get_child(0)
	_deck_title = _deck_section.get_node(^"Column").get_child(0)
	_aisle_tabs = HBoxContainer.new()
	_aisle_tabs.name = "AisleTabs"
	_aisle_tabs.add_theme_constant_override("separation", 14)
	_aisle_tabs.visible = false
	_shelf_section.get_node(^"Column").add_child(_aisle_tabs)
	_shelf_tab = _aisle_tab(&"shelf")
	_deck_tab = _aisle_tab(&"deck")

func _aisle_tab(which: StringName) -> Button:
	var b := Button.new()
	b.name = "AisleTab_%s" % which
	b.custom_minimum_size = Vector2(0, 40)
	b.add_theme_font_size_override("font_size", 24)
	b.pressed.connect(func():
		_aisle = which
		_render())
	_aisle_tabs.add_child(b)
	return b

func _dress_aisle_tab(b: Button, shown: bool) -> void:
	if shown:
		ButtonStyle.filled(b, Palette.color(&"primary"))
	else:
		ButtonStyle.outlined(b, Palette.color(&"primary"))
	# No taller than the title they stand in for.
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		var box := b.get_theme_stylebox(state) as StyleBoxFlat
		box.content_margin_top = 2
		box.content_margin_bottom = 2

## One dealership upgrade on offer: its name and what it does, the whole tile a
## button that takes it.
func _upgrade_button(u: DealershipUpgrade) -> Button:
	var b := Button.new()
	b.name = "Upgrade_%s" % u.id
	b.custom_minimum_size = Vector2(380, 340)
	ButtonStyle.outlined(b, Palette.color(&"primary"))
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 18)
	col.add_theme_constant_override("separation", 12)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(col)
	var title := Label.new()
	title.text = u.display_name
	title.theme_type_variation = &"Heading"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Palette.color(&"text"))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(title)
	var blurb := Label.new()
	blurb.text = u.blurb
	blurb.add_theme_font_size_override("font_size", 25)
	blurb.add_theme_color_override("font_color", Palette.color(&"text_dim"))
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD
	blurb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	blurb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(blurb)
	b.pressed.connect(func(): _apply(_shop.take_dealership_upgrade(u)))
	return b

## What sits under one of your cards: what upgrading it costs, or that it is
## done. An upgraded card stays on show, so you can still see what you chose.
func _upgrade_label(inst: CardInstance) -> String:
	if inst.upgraded:
		return "upgraded"
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
	note.add_theme_font_size_override("font_size", 28)
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
	rarity.add_theme_font_size_override("font_size", 17)
	rarity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity.text = CardText.rarity_name(inst)
	rarity.add_theme_color_override("font_color", Palette.rarity_color(inst.card.rarity))
	slot.add_child(rarity)

	var card: ShopCardButton = (load("res://scenes/cards/shop_card_button.tscn") \
		as PackedScene).instantiate()
	card.custom_minimum_size = CARD_SIZE
	card.size = CARD_SIZE
	slot.add_child(card)
	card.show_card(inst)

	var price := Label.new()
	price.add_theme_font_size_override("font_size", 27)
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
