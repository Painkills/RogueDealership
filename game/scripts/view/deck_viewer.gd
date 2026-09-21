extends PanelContainer
## The whole deck, browsable - not just ShelfRow/DeckRow's own random daily
## subset, and organized so all 9 interests and all 9 support cards are
## always visible, empty rows and all: "how many Anti-Theft contracts do I
## have" should never require counting the shelf.
##
## Products on the left, grouped by category then interest - exactly the
## grouping InterestPool.categories/in_category() already define, so a
## renamed or added interest never needs this file to change. Support cards
## on the right, one row per definition in CardPool order - they carry no
## interest to group by.
##
## Reachable from two places - the shop's VIEW DECK button and clicking the
## draw pile on the floor - which is why this is a RunController-level
## overlay rather than owned by either screen: one node, shown on top of
## whichever of them is active, never a second instance to keep in sync.

const CHIP_SIZE := Vector2(110, 154)   ## a card face, minified - the aspect every card uses

@onready var _title: Label = %DeckViewerTitle
@onready var _products_col: VBoxContainer = %ProductsColumn
@onready var _support_col: VBoxContainer = %SupportColumn
@onready var _close: Button = %DeckCloseButton

func _ready() -> void:
	_close.pressed.connect(func(): visible = false)

func show_deck(run: RunState) -> void:
	_title.text = "YOUR DECK (%d cards)" % run.deck.cards.size()

	var by_interest: Dictionary = {}   # interest id -> Array[CardInstance]
	var by_card_id: Dictionary = {}    # support CardDef id -> Array[CardInstance]
	for inst in run.deck.cards:
		if inst.is_product():
			var iid: StringName = (inst.card as ProductCardDef).interest.id
			if not by_interest.has(iid):
				by_interest[iid] = []
			by_interest[iid].append(inst)
		else:
			if not by_card_id.has(inst.card.id):
				by_card_id[inst.card.id] = []
			by_card_id[inst.card.id].append(inst)

	_clear(_products_col)
	for cat in run.interests.categories:
		_products_col.add_child(_category_header(cat.display_name))
		for interest in run.interests.in_category(cat):
			_products_col.add_child(_row(interest.display_name,
				by_interest.get(interest.id, [])))

	_clear(_support_col)
	for def in run.card_pool.cards:
		if def is ProductCardDef:
			continue
		_support_col.add_child(_row(def.display_name, by_card_id.get(def.id, [])))

	visible = true

func _clear(container: Control) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()

func _category_header(text: String) -> Label:
	var l := Label.new()
	l.text = text.to_upper()
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", Palette.color(&"accent"))
	return l

## label_text: the interest or card name. insts: however many copies of it
## are in the deck right now - zero is a real, expected answer, shown as a
## dash rather than an empty gap that could pass for a rendering glitch.
func _row(label_text: String, insts: Array) -> Control:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 4)

	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Palette.color(&"text_dim"))
	row.add_child(label)

	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation", 8)
	strip.custom_minimum_size = Vector2(0, CHIP_SIZE.y)
	if insts.is_empty():
		var none := Label.new()
		none.text = "-"
		none.add_theme_font_size_override("font_size", 18)
		none.add_theme_color_override("font_color", Palette.color(&"neutral_3"))
		strip.add_child(none)
	else:
		for inst in insts:
			var card: ShopCardButton = (load("res://scenes/cards/shop_card_button.tscn") \
				as PackedScene).instantiate()
			card.custom_minimum_size = CHIP_SIZE
			card.size = CHIP_SIZE
			strip.add_child(card)
			card.show_card(inst)
	row.add_child(strip)
	return row
