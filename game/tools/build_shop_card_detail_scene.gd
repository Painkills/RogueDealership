extends SceneTree
## Builds res://scenes/cards/shop_card_detail.tscn - the store's
## confirm-before-you-spend popup, as the employee portal's own product-details
## dialog (see AppWindow): the card as it is, the card upgraded where there is
## an upgrade to sell, and what it costs.

const PREVIEW_SCENE := "res://scenes/cards/card_preview_2d.tscn"

func _init() -> void:
	var root := PanelContainer.new()
	root.name = "ShopCardDetail"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	# STOP: while this is open it is the only thing on the store page you can
	# interact with - a click must not reach a row underneath it.
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.set_script(load("res://scripts/view/shop_card_detail.gd"))
	AppWindow.desktop(root, 0.6)

	var made := AppWindow.build(root, root, "DetailWindow", "Product details",
		Vector2(760, 0), "", 36)
	var col: VBoxContainer = made["body"]
	col.add_theme_constant_override("separation", 22)

	var title := AppWindow.label(col, root, "DetailTitle", "Card Name", 34, &"text", true, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var cards_row := HBoxContainer.new()
	cards_row.name = "CardsRow"
	cards_row.add_theme_constant_override("separation", 40)
	cards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(cards_row)
	cards_row.owner = root

	_preview_column(cards_row, root, "CurrentWrap", "NOW", "CurrentPreview")
	var upgraded_wrap := _preview_column(cards_row, root, "UpgradedWrap", "UPGRADED",
		"UpgradedPreview")
	# Hidden by show_shelf_card() - an unowned card has nothing "upgraded" to
	# compare against, unlike show_card()'s deck-browser path.
	upgraded_wrap.unique_name_in_owner = true

	var button_row := HBoxContainer.new()
	button_row.name = "ButtonRow"
	button_row.add_theme_constant_override("separation", 16)
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(button_row)
	button_row.owner = root

	# Spending is filled in; taking a card out, or backing out, is not.
	_button(button_row, root, "BuyButton", "buy $0", &"money", true)
	_button(button_row, root, "UpgradeButton", "upgrade $0", &"primary", true)
	_button(button_row, root, "RemoveButton", "remove $0", &"stamp", false)
	_button(button_row, root, "CloseButton", "close", &"ink_dim", false)

	var packed := PackedScene.new()
	packed.pack(root)
	var err := ResourceSaver.save(packed, "res://scenes/cards/shop_card_detail.tscn")
	if err != OK:
		push_error("failed to save shop_card_detail.tscn: %d" % err)
		quit(1)
		return
	print("saved shop_card_detail.tscn")
	root.free()
	quit(0)

func _preview_column(parent: Node, root: Node, node_name: String, caption: String,
		preview_name: String) -> VBoxContainer:
	var wrap := VBoxContainer.new()
	wrap.name = node_name
	wrap.add_theme_constant_override("separation", 8)
	wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(wrap)
	wrap.owner = root

	var label := AppWindow.label(wrap, root, node_name + "Caption", caption, 18, &"text_dim",
		true)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var preview: Control = (load(PREVIEW_SCENE) as PackedScene).instantiate()
	preview.name = preview_name
	preview.unique_name_in_owner = true
	preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	wrap.add_child(preview)
	preview.owner = root
	return wrap

func _button(parent: Node, root: Node, node_name: String, text: String,
		role: StringName, filled: bool) -> Button:
	var b := Button.new()
	b.name = node_name
	b.text = text
	b.custom_minimum_size = Vector2(160, 60)
	b.add_theme_font_size_override("font_size", 22)
	if filled:
		ButtonStyle.filled(b, Palette.color(role))
	else:
		ButtonStyle.outlined(b, Palette.color(role))
	b.unique_name_in_owner = true
	parent.add_child(b)
	b.owner = root
	return b
