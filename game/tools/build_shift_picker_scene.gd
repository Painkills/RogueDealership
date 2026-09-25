extends SceneTree
## Builds res://scenes/shift_picker.tscn - shown before every shift, so you
## pick a ShiftProfile before opening the floor. Laid out as a calendar's week
## view (see shift_picker_screen.gd): the frame is built here, and the week
## itself - which day is today, what each past day went like - is filled in at
## runtime, since it changes every visit.

func _init() -> void:
	var root := PanelContainer.new()
	root.name = "ShiftPickerScreen"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.set_script(load("res://scripts/view/shift_picker_screen.gd"))
	var ground := StyleBoxFlat.new()
	ground.bg_color = Palette.color(&"bg")
	root.add_theme_stylebox_override("panel", ground)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 28)
	root.add_child(margin)
	margin.owner = root

	var col := VBoxContainer.new()
	col.name = "Column"
	col.add_theme_constant_override("separation", 16)
	margin.add_child(col)
	col.owner = root

	# --- the header: what week this is, and how to play ---------------------
	var header := HBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", 24)
	col.add_child(header)
	header.owner = root

	var titles := VBoxContainer.new()
	titles.name = "Titles"
	titles.add_theme_constant_override("separation", 0)
	header.add_child(titles)
	titles.owner = root

	var title := Label.new()
	title.name = "TitleLabel"
	title.text = "THIS WEEK"
	title.theme_type_variation = &"Heading"
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Palette.color(&"text"))
	titles.add_child(title)
	title.owner = root

	var sub := Label.new()
	sub.name = "SubLabel"
	sub.text = "Shift 1 of 5 - pick today's  |  quota $3,600"
	sub.add_theme_font_size_override("font_size", 20)
	sub.add_theme_color_override("font_color", Palette.color(&"text_dim"))
	sub.unique_name_in_owner = true
	titles.add_child(sub)
	sub.owner = root

	var spacer := Control.new()
	spacer.name = "Spacer"
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	spacer.owner = root

	# The practice shift, on demand - it opens the game by itself only once.
	var tutorial := Button.new()
	tutorial.name = "TutorialButton"
	tutorial.text = "HOW TO PLAY"
	tutorial.custom_minimum_size = Vector2(200, 52)
	tutorial.size_flags_vertical = Control.SIZE_SHRINK_END
	tutorial.add_theme_font_size_override("font_size", 20)
	ButtonStyle.outlined(tutorial, Palette.color(&"primary"))
	tutorial.unique_name_in_owner = true
	header.add_child(tutorial)
	tutorial.owner = root

	# Clear of the run's own VIEW DECK button, which sits in the top-right
	# corner over every screen (see build_run_scene.gd).
	var corner := Control.new()
	corner.name = "CornerReserve"
	corner.custom_minimum_size = Vector2(200, 0)
	header.add_child(corner)
	corner.owner = root

	# --- the week ----------------------------------------------------------
	var calendar := PanelContainer.new()
	calendar.name = "Calendar"
	calendar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var card := StyleBoxFlat.new()
	card.bg_color = Palette.color(&"panel")
	card.border_color = Palette.color(&"neutral_2")
	card.set_border_width_all(1)
	card.set_corner_radius_all(16)
	card.content_margin_left = 12
	card.content_margin_right = 12
	card.content_margin_top = 8
	card.content_margin_bottom = 12
	card.shadow_color = Color(0, 0, 0, 0.1)
	card.shadow_size = 10
	card.shadow_offset = Vector2(0, 4)
	calendar.add_theme_stylebox_override("panel", card)
	col.add_child(calendar)
	calendar.owner = root

	var week := HBoxContainer.new()
	week.name = "Week"
	week.add_theme_constant_override("separation", 0)
	week.unique_name_in_owner = true
	calendar.add_child(week)
	week.owner = root

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
