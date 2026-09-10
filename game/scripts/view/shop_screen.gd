extends PanelContainer
## The shop between shifts. Three verbs and a button to go back to work.
##
## Rebuilds both lists after every purchase rather than patching rows: a visit
## is a handful of clicks on at most twenty rows, and a full rebuild cannot
## disagree with the deck the way an incremental patch can.

signal done

@onready var _money: Label = %MoneyLabel
@onready var _shift_label: Label = %ShiftLabel
@onready var _offer_rows: VBoxContainer = %OfferRows
@onready var _deck_rows: VBoxContainer = %DeckRows
@onready var _log: Label = %LogLabel
@onready var _done: Button = %DoneButton

var _shop: Shop

func _ready() -> void:
	_done.pressed.connect(func(): done.emit())

func setup(shop: Shop) -> void:
	_shop = shop
	_log.text = ""
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

	for child in _offer_rows.get_children():
		child.queue_free()
	for def in _shop.offers:
		_add_row(_offer_rows, "%s - %s" % [def.display_name,
			Format.money(_shop.buy_price(def))],
			func(): _apply(_shop.buy(def)))

	for child in _deck_rows.get_children():
		child.queue_free()
	for inst in run.deck.cards:
		var uid: int = inst.uid
		var label := inst.card.display_name
		if inst.upgraded:
			label += "  (upgraded)"
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		_deck_rows.add_child(row)

		var name_label := Label.new()
		name_label.text = label
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.add_theme_font_size_override("font_size", 24)
		row.add_child(name_label)

		if not inst.upgraded:
			_add_button(row, "upgrade %s" % Format.money(_shop.upgrade_price(inst)),
				func(): _apply(_shop.upgrade(uid)))
		_add_button(row, "drop %s" % Format.money(_shop.remove_price()),
			func(): _apply(_shop.remove(uid)))

func _add_row(parent: Node, text: String, action: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 26)
	b.custom_minimum_size = Vector2(0, 56)
	b.pressed.connect(action)
	parent.add_child(b)

func _add_button(parent: Node, text: String, action: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(action)
	parent.add_child(b)

func _apply(res: Result) -> void:
	## A refusal costs nothing but must still say why - the same rule the shift
	## screen follows.
	_log.text = res.msg
	_log.add_theme_color_override("font_color",
		Palette.color(&"text_dim" if res.ok else &"alert"))
	_render()
