extends SceneTree
## Builds res://scenes/shop.tscn - the between-shifts screen.
##
## A plain 2D Control. G2's bar is mechanical - add, remove or upgrade a card -
## and says nothing about presentation, so this follows the panel style G1 used
## before the 3D pivot rather than staging a second 3D scene.
##
## Cards, not text rows: the shelf and the deck browser both show the SAME
## card face the floor renders (shop_card_button.tscn - a real card wrapped
## in a flat Button), with the shop price underneath each one rather than
## folded into a line of button text. ShelfRow and DeckRow are EMPTY here
## and filled at runtime - what is on the shelf and which of the deck's
## cards may be edited both change every visit.
##
## DeckRow shows Shop.upgrade_offers, not the whole deck: a random, capped
## subset of cards you can actually DO something with this visit, the same
## shape the shelf's own offers already have. A card with nothing to upgrade
## does not appear here at all - see shop_screen.gd's own header comment for
## why that is a deliberate scope cut, not an oversight.

const DETAIL_SCENE := "res://scenes/cards/shop_card_detail.tscn"

func _init() -> void:
	var root := PanelContainer.new()
	root.name = "ShopScreen"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	# STOP, not IGNORE: this sits over a 3D table whose colliders do not stop
	# existing just because the table is hidden.
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.set_script(load("res://scripts/view/shop_screen.gd"))
	# Themed rather than left at the engine's default gray PanelContainer style
	# - the one thing this screen shared with the report screen before either
	# got a design pass, and the most direct fix for "make the menus look like
	# they belong to this game" that touches only one property.
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Palette.color(&"bg")
	root.add_theme_stylebox_override("panel", panel_style)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 48)
	root.add_child(margin)
	margin.owner = root

	var col := VBoxContainer.new()
	col.name = "Column"
	# Trimmed from 16 once the money row grew a second line for Shop.perk_text()
	# - six gaps between seven rows, so a few px back here is real headroom
	# without shrinking any row's own content.
	col.add_theme_constant_override("separation", 10)
	margin.add_child(col)
	col.owner = root

	_label(col, root, "TitleLabel", "BETWEEN SHIFTS", 40, &"text")

	# The quota line doubles as a mobile stand-in for Ctrl+M (+$10,000) - the
	# same "no keyboard on touch" gap the shift's tick counter has, and the
	# same fix: PanelContainer stacks every child at the SAME rect instead of
	# laying them out, so the label sizes the wrapper and the invisible
	# button (added after, on top for input) exactly covers it for free.
	var shift_wrap := PanelContainer.new()
	shift_wrap.name = "ShiftWrap"
	shift_wrap.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	# IGNORE: the wrapper itself must never be what a click actually hits -
	# only the Button inside it should. shift.tscn's own equivalent
	# (TickWrap) has a dedicated test for exactly this; this screen has no
	# 3D table underneath to protect, but the same rule still applies.
	shift_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(shift_wrap)
	shift_wrap.owner = root

	var shift_label := Label.new()
	shift_label.name = "ShiftLabel"
	shift_label.text = "shift 1 of 5"
	shift_label.add_theme_font_size_override("font_size", 24)
	shift_label.add_theme_color_override("font_color", Palette.color(&"text_dim"))
	shift_label.unique_name_in_owner = true
	shift_wrap.add_child(shift_label)
	shift_label.owner = root

	var shift_tap := Button.new()
	shift_tap.name = "ShiftTapTarget"
	shift_tap.flat = true   # no visible chrome at all - the ask was invisible
	shift_tap.unique_name_in_owner = true
	shift_wrap.add_child(shift_tap)
	shift_tap.owner = root

	_label(col, root, "MoneyLabel", "$0 to spend", 30, &"margin")

	_card_section(col, root, "ShelfSection", "OnShelfTitle", "ON THE SHELF",
		"ShelfRow")
	_card_section(col, root, "DeckSection", "DeckTitle",
		"CARDS YOU CAN EDIT - upgrade or drop", "DeckRow")

	_label(col, root, "LogLabel", "", 22, &"alert")

	var done := Button.new()
	done.name = "DoneButton"
	done.text = "OPEN THE FLOOR"
	done.custom_minimum_size = Vector2(360, 72)
	done.add_theme_font_size_override("font_size", 28)
	done.unique_name_in_owner = true
	col.add_child(done)
	done.owner = root

	var detail: Control = (load(DETAIL_SCENE) as PackedScene).instantiate()
	detail.name = "Detail"
	detail.unique_name_in_owner = true
	root.add_child(detail)
	detail.owner = root

	var packed := PackedScene.new()
	packed.pack(root)
	var err := ResourceSaver.save(packed, "res://scenes/shop.tscn")
	if err != OK:
		push_error("failed to save shop.tscn: %d" % err)
		quit(1)
		return
	print("saved shop.tscn")
	root.free()
	quit(0)

## A titled row of cards: the shelf and the deck browser are built from the
## exact same shape, since both are "some cards, click one" - only what a
## click DOES differs, and that is wired at runtime by shop_screen.gd, not
## here.
func _card_section(parent: Node, root: Node, section_name: String,
		title_name: String, title_text: String, row_name: String) -> void:
	var section := VBoxContainer.new()
	section.name = section_name
	section.add_theme_constant_override("separation", 10)
	parent.add_child(section)
	section.owner = root

	_label(section, root, title_name, title_text, 22, &"text_dim")

	var row := HBoxContainer.new()
	row.name = row_name
	row.unique_name_in_owner = true
	row.add_theme_constant_override("separation", 28)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	section.add_child(row)
	row.owner = root

func _label(parent: Node, root: Node, node_name: String, text: String,
		size: int, role: StringName) -> Label:
	var l := Label.new()
	l.name = node_name
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Palette.color(role))
	l.unique_name_in_owner = true
	parent.add_child(l)
	l.owner = root
	return l
