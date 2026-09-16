extends SceneTree
## Builds res://scenes/cards/shop_card_detail.tscn - the deck browser's
## "click to open" overlay. A full-rect scrim with a fixed-width card
## centered on it, the same composition build_report_scene.gd already
## established for the end-of-shift screen.

const PREVIEW_SCENE := "res://scenes/cards/card_preview_2d.tscn"

func _init() -> void:
	var root := PanelContainer.new()
	root.name = "ShopCardDetail"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	# STOP: while this is open it is the only thing on the shop screen you
	# can interact with - a click must not reach a row underneath it.
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.set_script(load("res://scripts/view/shop_card_detail.gd"))
	var scrim := StyleBoxFlat.new()
	scrim.bg_color = Color(Palette.color(&"bg").r, Palette.color(&"bg").g,
		Palette.color(&"bg").b, 0.88)
	root.add_theme_stylebox_override("panel", scrim)

	var wrap := CenterContainer.new()
	wrap.name = "CenterWrap"
	wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(wrap)
	wrap.owner = root

	var card := PanelContainer.new()
	card.name = "Card"
	card.custom_minimum_size = Vector2(700, 0)
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Palette.color(&"panel_hi")
	card_style.border_width_left = 2
	card_style.border_width_top = 2
	card_style.border_width_right = 2
	card_style.border_width_bottom = 2
	card_style.border_color = Palette.color(&"neutral_3")
	card.add_theme_stylebox_override("panel", card_style)
	wrap.add_child(card)
	card.owner = root

	var margin := MarginContainer.new()
	margin.name = "CardMargin"
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	card.add_child(margin)
	margin.owner = root

	var col := VBoxContainer.new()
	col.name = "Column"
	col.add_theme_constant_override("separation", 24)
	margin.add_child(col)
	col.owner = root

	var title := _label(col, root, "DetailTitle", "Card Name", 34, &"text")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.unique_name_in_owner = true

	var cards_row := HBoxContainer.new()
	cards_row.name = "CardsRow"
	cards_row.add_theme_constant_override("separation", 40)
	cards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(cards_row)
	cards_row.owner = root

	_preview_column(cards_row, root, "CurrentWrap", "NOW", "CurrentPreview")
	_preview_column(cards_row, root, "UpgradedWrap", "UPGRADED", "UpgradedPreview")

	var button_row := HBoxContainer.new()
	button_row.name = "ButtonRow"
	button_row.add_theme_constant_override("separation", 20)
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(button_row)
	button_row.owner = root

	_button(button_row, root, "UpgradeButton", "upgrade $0", &"appeal")
	_button(button_row, root, "RemoveButton", "remove $0", &"alert")
	_button(button_row, root, "CloseButton", "close", &"text_dim")

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

	var label := _label(wrap, root, node_name + "Caption", caption, 20, &"text_dim")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var preview: Control = (load(PREVIEW_SCENE) as PackedScene).instantiate()
	preview.name = preview_name
	preview.unique_name_in_owner = true
	preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	wrap.add_child(preview)
	preview.owner = root
	return wrap

func _label(parent: Node, root: Node, node_name: String, text: String,
		size: int, role: StringName) -> Label:
	var l := Label.new()
	l.name = node_name
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Palette.color(role))
	parent.add_child(l)
	l.owner = root
	return l

func _button(parent: Node, root: Node, node_name: String, text: String,
		role: StringName) -> Button:
	var b := Button.new()
	b.name = node_name
	b.text = text
	b.custom_minimum_size = Vector2(180, 64)
	b.add_theme_font_size_override("font_size", 24)
	b.add_theme_color_override("font_color", Palette.color(role))
	b.unique_name_in_owner = true
	parent.add_child(b)
	b.owner = root
	return b
