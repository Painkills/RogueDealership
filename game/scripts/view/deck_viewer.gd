extends PanelContainer
## The whole deck, browsable - not just ShelfRow/DeckRow's own random daily
## subset.
##
## Products are a 3x3 grid - one cell per interest, rows are categories,
## columns are that category's 3 interests (InterestPool.categories /
## in_category() already define both axes, so a renamed or added interest
## never needs this file to change). Always all 9 shown, empty cells and
## all: "how many Extended Warranties do I have" should never require
## counting the shelf.
##
## Support cards carry no interest/category to group by, so they are just
## listed - one chip per copy actually in the deck, no per-name row or
## label above it. A def you own none of simply has no chip; the card face
## itself already names the card.
##
## Reachable from two places - the shop's VIEW TOOLKIT button and clicking the
## draw pile on the floor - which is why this is a RunController-level
## overlay rather than owned by either screen: one node, shown on top of
## whichever of them is active, never a second instance to keep in sync.

## A card face, minified - the aspect every card uses. Sized to fill roughly
## half the screen's width across 3 columns (see build_deck_viewer_scene.gd's
## own comment on the 50/50 split), not the shelf-chip scale ShopScreen's own
## rows use - this overlay has the whole screen to itself and nothing else
## competing for it.
const CHIP_SIZE := Vector2(260, 364)

@onready var _title: Label = %DeckViewerTitle
@onready var _products_col: GridContainer = %ProductsColumn
@onready var _support_col: GridContainer = %SupportColumn
@onready var _close: Button = %DeckCloseButton
## The dealership's upgrades across the top - see _show_dealership().
@onready var _dealership_strip: Control = %DealershipStrip
@onready var _dealership_badges: HBoxContainer = %DealershipBadges
@onready var _dealership_note: Label = %DealershipNote

const BADGE := Vector2(60, 60)
const NOTE_HINT := "Hover or tap a badge to see what it does."

func _ready() -> void:
	_close.pressed.connect(func(): visible = false)

func show_deck(run: RunState) -> void:
	_title.text = "MY TOOLKIT  -  %d cards" % run.deck.cards.size()
	_show_dealership(run.dealership)

	var by_interest: Dictionary = {}   # interest id -> Array[CardInstance]
	var support_insts: Array = []      # every support CardInstance, deck order
	for inst in run.deck.cards:
		if inst.is_product():
			var iid: StringName = (inst.card as ProductCardDef).interest.id
			if not by_interest.has(iid):
				by_interest[iid] = []
			by_interest[iid].append(inst)
		else:
			support_insts.append(inst)

	_clear(_products_col)
	for cat in run.interests.categories:
		for interest in run.interests.in_category(cat):
			_products_col.add_child(_cell(interest.display_name,
				by_interest.get(interest.id, [])))

	_clear(_support_col)
	if support_insts.is_empty():
		_support_col.add_child(_dash())
	else:
		for inst in support_insts:
			_support_col.add_child(_chip(inst))

	visible = true

## One badge per dealership upgrade the run owns, its icon or its initials:
## hovering one (tooltip on a mouse) or tapping it (a touchscreen has no hover)
## writes its name and what it does beside them. Hidden with none to show.
func _show_dealership(owned: Array) -> void:
	_clear(_dealership_badges)
	_dealership_strip.visible = not owned.is_empty()
	_dealership_note.text = NOTE_HINT
	for u in owned:
		if u == null:
			continue
		var b := Button.new()
		b.name = "Badge_%s" % u.id
		b.custom_minimum_size = BADGE
		b.tooltip_text = "%s\n%s" % [u.display_name, u.blurb]
		ButtonStyle.filled(b, Palette.color(&"primary"))
		if u.icon != null:
			b.icon = u.icon
			b.expand_icon = true
			b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		else:
			b.text = initials(u.display_name)
			b.add_theme_font_size_override("font_size", 22)
		var say := func(): _dealership_note.text = "%s - %s" % [u.display_name, u.blurb]
		b.mouse_entered.connect(say)
		b.pressed.connect(say)
		b.mouse_exited.connect(func(): _dealership_note.text = NOTE_HINT)
		_dealership_badges.add_child(b)

## "Walkaway Wednesday" -> "WW": the first letter of its first two words.
static func initials(display_name: String) -> String:
	var out := ""
	for word in display_name.split(" ", false):
		out += word.left(1).to_upper()
		if out.length() == 2:
			break
	return out

func _clear(container: Control) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()

## label_text: the interest name. insts: however many copies of it are in
## the deck right now - zero is a real, expected answer, shown as a dash
## rather than an empty gap that could pass for a rendering glitch. A second
## (or third) copy of the same product stacks BELOW the first, never beside
## it: the cell's width is pinned to one chip regardless of what it holds, so
## a duplicate makes its own cell taller, never its column wider - every
## column in the 3x3 grid stays the same width whether its cells are empty,
## single, or stacked.
func _cell(label_text: String, insts: Array) -> Control:
	var cell := VBoxContainer.new()
	cell.add_theme_constant_override("separation", 8)
	cell.custom_minimum_size.x = CHIP_SIZE.x

	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Palette.color(&"text_dim"))
	cell.add_child(label)

	if insts.is_empty():
		var placeholder := CenterContainer.new()
		placeholder.custom_minimum_size = CHIP_SIZE
		placeholder.add_child(_dash())
		cell.add_child(placeholder)
	else:
		for inst in insts:
			cell.add_child(_chip(inst))
	return cell

func _chip(inst: CardInstance) -> ShopCardButton:
	var card: ShopCardButton = (load("res://scenes/cards/shop_card_button.tscn") \
		as PackedScene).instantiate()
	card.custom_minimum_size = CHIP_SIZE
	card.size = CHIP_SIZE
	card.show_card(inst)
	return card

func _dash() -> Label:
	var none := Label.new()
	none.text = "-"
	none.add_theme_font_size_override("font_size", 22)
	none.add_theme_color_override("font_color", Palette.color(&"neutral_3"))
	return none
