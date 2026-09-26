extends SceneTree
## Builds res://scenes/shop.tscn - the between-shifts screen, as the
## Store page of the dealership's employee portal: a website in a browser
## window (see AppWindow), where the bonus you earned buys new cards and
## upgrades the ones you have. Its other page, My Toolkit, is the deck viewer.
##
## Cards, not text rows: the shelf and the deck browser both show the SAME
## card face the floor renders (shop_card_button.tscn - a real card wrapped
## in a flat Button), with the store price underneath each one rather than
## folded into a line of button text. ShelfRow and DeckRow are EMPTY here
## and filled at runtime - what is on the shelf and which of the deck's
## cards may be edited both change every visit.
##
## DeckRow shows Shop.upgrade_offers, not the whole deck: a random, capped
## subset of cards you can actually DO something with this visit, the same
## shape the shelf's own offers already have. A card with nothing to upgrade
## does not appear here at all - see shop_screen.gd's own header comment for
## why that is a deliberate scope cut, not an oversight.
##
## The two aisles sit side by side rather than stacked: a browser window's
## own chrome takes height a full-screen menu never had to give up.

const DETAIL_SCENE := "res://scenes/cards/shop_card_detail.tscn"
const WINDOW := Vector2(1680, 940)

func _init() -> void:
	var root := PanelContainer.new()
	root.name = "ShopScreen"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	# STOP, not IGNORE: this sits over a 3D table whose colliders do not stop
	# existing just because the table is hidden.
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.set_script(load("res://scripts/view/shop_screen.gd"))
	AppWindow.desktop(root)

	var made := AppWindow.build(root, root, "PortalWindow", "Employee Portal", WINDOW,
		"portal.dealership.local/store", 28)
	var col: VBoxContainer = made["body"]
	col.add_theme_constant_override("separation", 14)

	# The portal knows who is signed in - see shop_screen.gd's _render().
	var header := AppWindow.portal_header(col, root, "Store")
	var account := AppWindow.box(header, root, "Account", &"panel_hi", &"neutral_2", 12, 20)
	account.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	AppWindow.label(account, root, "AccountLabel", "F&I Manager", 20, &"text", true, true)

	AppWindow.rule(col, root, "HeaderRule")

	# --- what you have to spend, and on what shift ------------------------------
	var intro := HBoxContainer.new()
	intro.name = "Intro"
	intro.add_theme_constant_override("separation", 24)
	col.add_child(intro)
	intro.owner = root

	var titles := VBoxContainer.new()
	titles.name = "Titles"
	titles.add_theme_constant_override("separation", 2)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	intro.add_child(titles)
	titles.owner = root
	AppWindow.label(titles, root, "TitleLabel", "Spend your bonus", 36, &"text", true, true)

	# The quota line doubles as a mobile stand-in for Ctrl+M (+$10,000) - the
	# same "no keyboard on touch" gap the shift's tick counter has, and the
	# same fix: PanelContainer stacks every child at the SAME rect instead of
	# laying them out, so the label sizes the wrapper and the invisible
	# button (added after, on top for input) exactly covers it for free.
	var shift_wrap := PanelContainer.new()
	shift_wrap.name = "ShiftWrap"
	shift_wrap.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	# IGNORE: the wrapper itself must never be what a click actually hits -
	# only the Button inside it should.
	shift_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	titles.add_child(shift_wrap)
	shift_wrap.owner = root

	AppWindow.label(shift_wrap, root, "ShiftLabel", "shift 1 of 5", 21, &"text_dim", false, true)

	var shift_tap := Button.new()
	shift_tap.name = "ShiftTapTarget"
	shift_tap.flat = true   # no visible chrome at all - the ask was invisible
	shift_tap.unique_name_in_owner = true
	shift_wrap.add_child(shift_tap)
	shift_tap.owner = root

	var money := AppWindow.label(intro, root, "MoneyLabel", "$0 to spend", 24, &"margin",
		true, true)
	money.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	money.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	# --- the two aisles ------------------------------------------------------------
	var aisles := HBoxContainer.new()
	aisles.name = "Aisles"
	aisles.add_theme_constant_override("separation", 28)
	col.add_child(aisles)
	aisles.owner = root
	_card_section(aisles, root, "ShelfSection", "OnShelfTitle", "NEW IN THE STORE",
		"ShelfRow")
	_card_section(aisles, root, "DeckSection", "DeckTitle",
		"YOUR TOOLKIT - upgrade or drop", "DeckRow")

	AppWindow.label(col, root, "LogLabel", "", 22, &"alert", false, true)

	var button_row := HBoxContainer.new()
	button_row.name = "ButtonRow"
	button_row.add_theme_constant_override("separation", 20)
	button_row.alignment = BoxContainer.ALIGNMENT_END
	col.add_child(button_row)
	button_row.owner = root

	var view_deck := Button.new()
	view_deck.name = "ViewDeckButton"
	view_deck.text = "MY TOOLKIT"
	view_deck.custom_minimum_size = Vector2(240, 72)
	view_deck.add_theme_font_size_override("font_size", 24)
	ButtonStyle.outlined(view_deck, Palette.color(&"primary"))
	view_deck.unique_name_in_owner = true
	button_row.add_child(view_deck)
	view_deck.owner = root

	var done := Button.new()
	done.name = "DoneButton"
	done.text = "CLOCK IN FOR THE NEXT SHIFT"
	done.custom_minimum_size = Vector2(400, 72)
	done.add_theme_font_size_override("font_size", 26)
	ButtonStyle.filled(done, Palette.color(&"primary"))
	done.unique_name_in_owner = true
	button_row.add_child(done)
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

## A titled aisle of cards: the shelf and the deck browser are built from the
## exact same shape, since both are "some cards, click one" - only what a
## click DOES differs, and that is wired at runtime by shop_screen.gd, not
## here.
func _card_section(parent: Node, root: Node, section_name: String,
		title_name: String, title_text: String, row_name: String) -> void:
	var section := AppWindow.box(parent, root, section_name, &"panel_hi", &"neutral_2", 20, 14)
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col := VBoxContainer.new()
	col.name = "Column"
	col.add_theme_constant_override("separation", 10)
	section.add_child(col)
	col.owner = root

	AppWindow.label(col, root, title_name, title_text, 20, &"text_dim", true, true)

	var row := HBoxContainer.new()
	row.name = row_name
	row.unique_name_in_owner = true
	row.add_theme_constant_override("separation", 24)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	row.owner = root
