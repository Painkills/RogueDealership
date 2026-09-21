extends SceneTree
## Builds res://scenes/shift_picker.tscn - shown before every shift, so you
## pick a ShiftProfile before opening the floor. ProfileRow is EMPTY here and
## filled at runtime by shift_picker_screen.gd, the same shape shop.tscn's
## ShelfRow/DeckRow already use for content that changes every visit -
## here it does not (three profiles, always), but the pattern still fits.

func _init() -> void:
	var root := PanelContainer.new()
	root.name = "ShiftPickerScreen"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.set_script(load("res://scripts/view/shift_picker_screen.gd"))
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
	col.add_theme_constant_override("separation", 24)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(col)
	col.owner = root

	var title := Label.new()
	title.name = "TitleLabel"
	title.text = "PICK YOUR SHIFT"
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Palette.color(&"text"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	title.owner = root

	var row := HBoxContainer.new()
	row.name = "ProfileRow"
	row.unique_name_in_owner = true
	row.add_theme_constant_override("separation", 40)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	row.owner = root

	var packed := PackedScene.new()
	packed.pack(root)
	var err := ResourceSaver.save(packed, "res://scenes/shift_picker.tscn")
	if err != OK:
		push_error("failed to save shift_picker.tscn: %d" % err)
		quit(1)
		return
	print("saved shift_picker.tscn")
	root.free()
	quit(0)
