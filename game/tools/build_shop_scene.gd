extends SceneTree
## Builds res://scenes/shop.tscn - the between-shifts screen, as the
## Store page of the dealership's employee portal: a website in a browser
## window (see AppWindow). Its other page, My Toolkit, is the deck viewer.
##
## Every visit opens on a popup first - FreePick, a few cards on the house to
## take ONE of - and then the store behind it, two aisles side by side:
##   FOR SALE       the cards the shift you worked put up for sale, bought
##                  with the bonus you earned
##   UPGRADES       a few of your own cards to upgrade (or drop)
## How many of each is the shift's own (ShiftProfile.cards_for_sale and
## upgrades); buy or upgrade as many as the bonus covers. An aisle the shift
## does not stock says so in words, filled in at runtime with everything else
## here - FreePickRow, ShelfRow and DeckRow are EMPTY in the scene, because
## what is in them changes every visit.
##
## Cards, not text rows: every aisle shows the SAME card face the floor renders
## (shop_card_button.tscn - a real card wrapped in a flat Button), with what it
## costs underneath rather than folded into a line of button text.

const DETAIL_SCENE := "res://scenes/cards/shop_card_detail.tscn"
const WINDOW := Vector2(1800, 1000)
## Room kept clear at the top of the desktop, for the run's VIEW TOOLKIT button
## in the corner - see AppWindow.build().
const TOP_INSET := 70.0
## One card on offer, as shop_screen.gd's _build_slot() stacks it: a rarity
## line, the 336-tall card itself, and a price line. drive_run.gd measures a
## real slot against this.
const SLOT_HEIGHT := 410
## The free pick's window: room for three card slots side by side.
const FREE_PICK_WINDOW := Vector2(960, 0)
const DEALERSHIP_PICK_WINDOW := Vector2(1300, 0)

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
		"portal.dealership.local/store", 28, TOP_INSET)
	var col: VBoxContainer = made["body"]
	col.add_theme_constant_override("separation", 10)

	# The portal knows who is signed in - see shop_screen.gd's _render().
	var header := AppWindow.portal_header(col, root, "Store")
	var account := AppWindow.box(header, root, "Account", &"panel_hi", &"neutral_2", 12, 20)
	account.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	AppWindow.label(account, root, "AccountLabel", "F&I Manager", 24, &"text", true, true)

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
	AppWindow.label(titles, root, "TitleLabel", "Your perks for that shift", 44, &"text",
		true, true)

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

	var shift_label := AppWindow.label(shift_wrap, root, "ShiftLabel", "shift 1 of 5", 26,
		&"text_dim", false, true)
	# Wraps rather than widening the whole store: the dealership's upgrades are
	# listed here, and that line grows over a run.
	shift_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var shift_tap := Button.new()
	shift_tap.name = "ShiftTapTarget"
	shift_tap.flat = true   # no visible chrome at all - the ask was invisible
	shift_tap.unique_name_in_owner = true
	shift_wrap.add_child(shift_tap)
	shift_tap.owner = root

	# In the portal's header row, beside who is signed in: out of the way of the
	# lines about the shift, which then get the whole width to say their piece.
	var money := AppWindow.label(header, root, "MoneyLabel", "$0 to spend", 30, &"margin",
		true, true)
	money.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	money.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.move_child(money, account.get_index())

	# --- the two aisles -----------------------------------------------------------
	# Either can hold a few cards, depending on the shift. shop_screen.gd shows
	# only the ones the shift stocks and widens each by how much it holds; with
	# neither, StoreEmptyNote stands in their place.
	var aisles := HBoxContainer.new()
	aisles.name = "Aisles"
	aisles.add_theme_constant_override("separation", 28)
	col.add_child(aisles)
	aisles.owner = root
	_card_section(aisles, root, "ShelfSection", "OnShelfTitle", "FOR SALE", "ShelfRow", 1.0)
	_card_section(aisles, root, "DeckSection", "DeckTitle", "UPGRADE YOUR CARDS",
		"DeckRow", 1.0)
	var empty := AppWindow.label(aisles, root, "StoreEmptyNote",
		"Nothing on the shelves after this shift.", 30, &"text_dim", false, true)
	empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	empty.custom_minimum_size = Vector2(0, SLOT_HEIGHT)
	empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	empty.visible = false

	var button_row := HBoxContainer.new()
	button_row.name = "ButtonRow"
	button_row.add_theme_constant_override("separation", 20)
	button_row.alignment = BoxContainer.ALIGNMENT_END
	col.add_child(button_row)
	button_row.owner = root

	# What the last thing you did said, in the empty half of the row the two
	# buttons leave - the line it needs is already there, so a message coming
	# and going moves nothing on the page.
	var log_label := AppWindow.label(button_row, root, "LogLabel", "", 28, &"alert", false,
		true)
	log_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var view_deck := Button.new()
	view_deck.name = "ViewDeckButton"
	view_deck.text = "VIEW TOOLKIT"
	view_deck.custom_minimum_size = Vector2(300, 84)
	view_deck.add_theme_font_size_override("font_size", 30)
	ButtonStyle.outlined(view_deck, Palette.color(&"primary"))
	view_deck.unique_name_in_owner = true
	button_row.add_child(view_deck)
	view_deck.owner = root

	var done := Button.new()
	done.name = "DoneButton"
	done.text = "CLOCK IN FOR THE NEXT SHIFT"
	done.custom_minimum_size = Vector2(500, 84)
	done.add_theme_font_size_override("font_size", 32)
	ButtonStyle.filled(done, Palette.color(&"primary"))
	done.unique_name_in_owner = true
	button_row.add_child(done)
	done.owner = root

	_free_pick(root)
	_dealership_pick(root)

	# After the popup, so a card's details open over it rather than under it.
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

## "First, you get a popup with the one out of three." Over the whole store, so
## nothing behind it can be clicked until you pick one - or pass. The cards go
## in FreePickRow at runtime, the same slots the aisles use.
func _free_pick(root: Control) -> void:
	var popup := PanelContainer.new()
	popup.name = "FreePick"
	popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup.mouse_filter = Control.MOUSE_FILTER_STOP
	popup.unique_name_in_owner = true
	AppWindow.desktop(popup, 0.6)
	root.add_child(popup)
	popup.owner = root

	var made := AppWindow.build(popup, root, "FreePickWindow", "On the house",
		FREE_PICK_WINDOW, "", 36)
	var col: VBoxContainer = made["body"]
	col.add_theme_constant_override("separation", 18)

	var title := AppWindow.label(col, root, "FreePickTitle", "Pick one, on the house", 42,
		&"text", true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub := AppWindow.label(col, root, "FreePickSub",
		"It goes straight into your toolkit. The store is next.", 26, &"text_dim")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var row := HBoxContainer.new()
	row.name = "FreePickRow"
	row.unique_name_in_owner = true
	row.add_theme_constant_override("separation", 24)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.custom_minimum_size = Vector2(0, SLOT_HEIGHT)
	col.add_child(row)
	row.owner = root

	var buttons := HBoxContainer.new()
	buttons.name = "FreePickButtons"
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(buttons)
	buttons.owner = root
	var skip := Button.new()
	skip.name = "SkipFreeButton"
	skip.text = "no thanks"
	skip.custom_minimum_size = Vector2(250, 76)
	skip.add_theme_font_size_override("font_size", 28)
	ButtonStyle.outlined(skip, Palette.color(&"ink_dim"))
	skip.unique_name_in_owner = true
	buttons.add_child(skip)
	skip.owner = root

## The night store's other popup, in front of the free pick: a few upgrades for
## the dealership itself, to take ONE of for the rest of the run. Built after
## FreePick so it draws over it; DealershipRow is filled at runtime by
## shop_screen.gd, one button per upgrade on offer.
func _dealership_pick(root: Control) -> void:
	var popup := PanelContainer.new()
	popup.name = "DealershipPick"
	popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup.mouse_filter = Control.MOUSE_FILTER_STOP
	popup.unique_name_in_owner = true
	popup.visible = false
	AppWindow.desktop(popup, 0.6)
	root.add_child(popup)
	popup.owner = root

	var made := AppWindow.build(popup, root, "DealershipPickWindow", "Perk",
		DEALERSHIP_PICK_WINDOW, "", 36)
	var col: VBoxContainer = made["body"]
	col.add_theme_constant_override("separation", 18)

	var title := AppWindow.label(col, root, "DealershipPickTitle",
		"You made quota - pick a perk", 40, &"text", true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub := AppWindow.label(col, root, "DealershipPickSub",
		"Pick one. It stays for the rest of the run.", 26, &"text_dim")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var row := HBoxContainer.new()
	row.name = "DealershipRow"
	row.unique_name_in_owner = true
	row.add_theme_constant_override("separation", 20)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	row.owner = root

## A titled aisle of cards: both are built from the exact same shape,
## since each is "some cards, click one" - only what a click DOES differs, and
## that is wired at runtime by shop_screen.gd, not here. `share` is how much of
## the width it gets against the others.
func _card_section(parent: Node, root: Node, section_name: String,
		title_name: String, title_text: String, row_name: String, share: float) -> void:
	var section := AppWindow.box(parent, root, section_name, &"panel_hi", &"neutral_2", 20, 14)
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.size_flags_stretch_ratio = share
	section.unique_name_in_owner = true
	var col := VBoxContainer.new()
	col.name = "Column"
	col.add_theme_constant_override("separation", 10)
	section.add_child(col)
	col.owner = root

	AppWindow.label(col, root, title_name, title_text, 26, &"text_dim", true, true)

	var row := HBoxContainer.new()
	row.name = row_name
	row.unique_name_in_owner = true
	row.add_theme_constant_override("separation", 24)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	# One card slot tall, whether it holds a card or only the words saying it
	# is empty - taking the free card must not pull the page (and the button
	# you are about to press) up the screen.
	row.custom_minimum_size = Vector2(0, SLOT_HEIGHT)
	col.add_child(row)
	row.owner = root
