extends SceneTree
## Builds res://scenes/deck_viewer.tscn - the "see your whole deck" overlay,
## reachable from both the shop and the floor. ProductsColumn and
## SupportColumn are EMPTY GridContainers here, filled entirely at runtime by
## deck_viewer.gd, the same "structure varies, build it in the script"
## approach shift_picker_screen.gd already uses for its own per-profile
## cards - simpler than pre-baking a skeleton for a layout whose cell COUNT
## and GROUPING (categories, interests) are themselves data, not a fixed
## shape this builder should have to know. Both are fixed at 3 columns: a
## square 3x3 for products (3 categories x 3 interests each), and a plain
## wrapping list for support cards.

func _init() -> void:
	var root := PanelContainer.new()
	root.name = "DeckViewer"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.visible = false
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Palette.color(&"bg")
	root.add_theme_stylebox_override("panel", panel_style)
	root.set_script(load("res://scripts/view/deck_viewer.gd"))

	var margin := MarginContainer.new()
	margin.name = "Margin"
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	root.add_child(margin)
	margin.owner = root

	var col := VBoxContainer.new()
	col.name = "Column"
	col.add_theme_constant_override("separation", 16)
	margin.add_child(col)
	col.owner = root

	var title := Label.new()
	title.name = "DeckViewerTitle"
	title.text = "YOUR DECK"
	title.theme_type_variation = &"Heading"
	title.unique_name_in_owner = true
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Palette.color(&"text"))
	col.add_child(title)
	title.owner = root

	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	scroll.owner = root

	var halves := HBoxContainer.new()
	halves.name = "Halves"
	halves.add_theme_constant_override("separation", 96)
	scroll.add_child(halves)
	halves.owner = root

	# Each frame's border echoes the kind-icon colour that side's own cards
	# already carry (card_face_3d.gd's _kind_icon: accent for a product,
	# action-purple for support) - the same colour language the cards
	# themselves use, not a new one invented for this overlay.
	_side(halves, root, "ProductsSide", "PRODUCTS", "ProductsColumn", 3,
		Palette.color(&"accent"))
	_side(halves, root, "SupportSide", "SUPPORT", "SupportColumn", 3,
		Palette.color(&"action"))

	var close := Button.new()
	close.name = "DeckCloseButton"
	close.text = "CLOSE"
	close.unique_name_in_owner = true
	close.custom_minimum_size = Vector2(240, 64)
	close.add_theme_font_size_override("font_size", 24)
	col.add_child(close)
	close.owner = root

	var packed := PackedScene.new()
	packed.pack(root)
	var err := ResourceSaver.save(packed, "res://scenes/deck_viewer.tscn")
	if err != OK:
		push_error("failed to save deck_viewer.tscn: %d" % err)
		quit(1)
		return
	print("saved deck_viewer.tscn")
	root.free()
	quit(0)

## One half of the split: a heading ("PRODUCTS"/"SUPPORT") over a bordered
## frame holding an empty, uniquely-named GridContainer deck_viewer.gd fills
## with cells or chips. The frame is what makes the grid itself read as a
## grid rather than just loose cards floating on the overlay's own background.
func _side(parent: Node, root: Node, side_name: String, heading_text: String,
		column_name: String, columns: int, border_color: Color) -> void:
	var side := VBoxContainer.new()
	side.name = side_name
	side.add_theme_constant_override("separation", 16)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(side)
	side.owner = root

	var heading := Label.new()
	heading.name = side_name + "Heading"
	heading.text = heading_text
	heading.add_theme_font_size_override("font_size", 26)
	heading.add_theme_color_override("font_color", Palette.color(&"margin"))
	side.add_child(heading)
	heading.owner = root

	var frame := PanelContainer.new()
	frame.name = side_name + "Frame"
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Palette.color(&"panel")
	frame_style.border_color = border_color
	frame_style.set_border_width_all(3)
	frame_style.set_corner_radius_all(10)
	frame_style.set_content_margin_all(16)
	frame.add_theme_stylebox_override("panel", frame_style)
	side.add_child(frame)
	frame.owner = root

	var column := GridContainer.new()
	column.name = column_name
	column.unique_name_in_owner = true
	column.columns = columns
	column.add_theme_constant_override("h_separation", 20)
	column.add_theme_constant_override("v_separation", 20)
	frame.add_child(column)
	column.owner = root
