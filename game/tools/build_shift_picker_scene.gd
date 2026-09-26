extends SceneTree
## Builds res://scenes/shift_picker.tscn - shown before every shift, so you
## pick a ShiftProfile before opening the floor. Laid out as a calendar's week
## view (see shift_picker_screen.gd): the frame is built here, and the week
## itself - which day is today, what each past day went like - is filled in at
## runtime, since it changes every visit.

## A calendar app's window, nearly the width of the screen. Its height comes
## from the week it holds (CalendarDay.HOUR_PX), and it stays clear of the
## run's corner VIEW TOOLKIT button above it.
const WINDOW := Vector2(1840, 0)

func _init() -> void:
	var root := PanelContainer.new()
	root.name = "ShiftPickerScreen"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.set_script(load("res://scripts/view/shift_picker_screen.gd"))
	AppWindow.desktop(root)

	var made := AppWindow.build(root, root, "CalendarWindow", "Calendar", WINDOW, "", 16)
	var col: VBoxContainer = made["body"]
	col.add_theme_constant_override("separation", 10)

	# --- the header: what week this is, and how to play ---------------------
	# One line, title and subtitle side by side: a window's own title bar
	# already took the height a second line would need.
	var header := HBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", 20)
	col.add_child(header)
	header.owner = root

	var title := AppWindow.label(header, root, "TitleLabel", "THIS WEEK", 38, &"text", true)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sub := AppWindow.label(header, root, "SubLabel",
		"Shift 1 of 5 - pick today's  |  quota $3,600", 20, &"text_dim", false, true)
	sub.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var spacer := Control.new()
	spacer.name = "Spacer"
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	spacer.owner = root

	# The practice shift, on demand - it also opens the game by itself.
	var tutorial := Button.new()
	tutorial.name = "TutorialButton"
	tutorial.text = "HOW TO PLAY"
	tutorial.custom_minimum_size = Vector2(200, 52)
	tutorial.add_theme_font_size_override("font_size", 20)
	ButtonStyle.outlined(tutorial, Palette.color(&"primary"))
	tutorial.unique_name_in_owner = true
	header.add_child(tutorial)
	tutorial.owner = root

	# --- the week ----------------------------------------------------------
	var calendar := PanelContainer.new()
	calendar.name = "Calendar"
	calendar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var card := StyleBoxFlat.new()
	card.bg_color = Palette.color(&"panel")
	card.border_color = Palette.color(&"neutral_2")
	card.set_border_width_all(1)
	card.set_corner_radius_all(12)
	card.content_margin_left = 12
	card.content_margin_right = 12
	card.content_margin_top = 8
	card.content_margin_bottom = 12
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
