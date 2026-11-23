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
## The portal's two tabs, and the page each shows.
@onready var _toolkit_tab: Button = %MyToolkitTab
@onready var _perks_tab: Button = %MyPerksTab
@onready var _toolkit_page: Control = %ToolkitPage
@onready var _perks_page: Control = %PerksPage
@onready var _perks_grid: GridContainer = %PerksGrid
@onready var _no_perks: Control = %NoPerksNote

## One perk card on the My Perks page.
const PERK_CARD := Vector2(300, 240)

## The run last shown, for switching tabs without being handed it again.
var _run: RunState

func _ready() -> void:
	_close.pressed.connect(func(): visible = false)
	_toolkit_tab.pressed.connect(func(): show_deck(_run))
	_perks_tab.pressed.connect(func(): show_perks(_run))

## The My Perks page: one little card per dealership perk the run has picked,
## in the order it picked them.
func show_perks(run: RunState) -> void:
	_run = run
	_page(false)
	var owned := run.dealership.filter(func(u): return u != null)
	_title.text = "%d perk%s" % [owned.size(), "" if owned.size() == 1 else "s"]
	_clear(_perks_grid)
	for u in owned:
		_perks_grid.add_child(_perk_card(u))
	_no_perks.visible = owned.is_empty()
	visible = true

func _page(toolkit: bool) -> void:
	_toolkit_page.visible = toolkit
	_perks_page.visible = not toolkit
	AppWindow.dress_tab(_toolkit_tab, toolkit)
	AppWindow.dress_tab(_perks_tab, not toolkit)
	var address := find_child("Address", true, false) as Label
	if address != null:
		address.text = "portal.dealership.local/" + ("toolkit" if toolkit else "perks")

func show_deck(run: RunState) -> void:
	_run = run
	_page(true)
	_title.text = "%d cards" % run.deck.cards.size()

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

## One perk, as a little card: its badge (icon, or initials), its name and what
## it does - everything on show, nothing behind a hover.
func _perk_card(u: DealershipUpgrade) -> Control:
	var card := PanelContainer.new()
	card.name = "Perk_%s" % u.id
	card.custom_minimum_size = PERK_CARD
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.color(&"paper")
	style.border_color = Palette.color(&"primary")
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(16)
	style.shadow_color = Color(0, 0, 0, 0.12)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 2)
	card.add_theme_stylebox_override("panel", style)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	card.add_child(col)
	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(56, 56)
	badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var disc := StyleBoxFlat.new()
	disc.bg_color = Palette.color(&"primary")
	disc.set_corner_radius_all(28)
	badge.add_theme_stylebox_override("panel", disc)
	col.add_child(badge)
	if u.icon != null:
		var icon := TextureRect.new()
		icon.texture = u.icon
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		badge.add_child(icon)
	else:
		var letters := Label.new()
		letters.text = initials(u.display_name)
		letters.theme_type_variation = &"Heading"
		letters.add_theme_font_size_override("font_size", 22)
		letters.add_theme_color_override("font_color", Palette.color(&"paper"))
		letters.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		letters.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.add_child(letters)
	var title := Label.new()
	title.name = "PerkName"
	title.text = u.display_name
	title.theme_type_variation = &"Heading"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Palette.color(&"text"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(title)
	var blurb := Label.new()
	blurb.name = "PerkBlurb"
	blurb.text = u.blurb
	blurb.add_theme_font_size_override("font_size", 19)
	blurb.add_theme_color_override("font_color", Palette.color(&"text_dim"))
	blurb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(blurb)
	return card

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
