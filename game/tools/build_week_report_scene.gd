extends SceneTree
## Builds res://scenes/week_report.tscn - the week just worked, as the
## dealership system's weekly report, shown between one week and the next.
## The same app window the end-of-day report lives in (see AppWindow); every
## number in it is written at runtime by week_report_panel.gd.

const WINDOW := Vector2(1100, 0)

func _init() -> void:
	var root := PanelContainer.new()
	root.name = "WeekReportPanel"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	# STOP: a screen of its own between weeks, over the floor's colliders.
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.set_script(load("res://scripts/view/week_report_panel.gd"))
	AppWindow.desktop(root)

	var made := AppWindow.build(root, root, "WeekWindow",
		"Dealership System  -  Weekly Report", WINDOW, "", 40)
	var col: VBoxContainer = made["body"]
	col.add_theme_constant_override("separation", 14)

	# --- the headline ----------------------------------------------------------
	AppWindow.label(col, root, "Eyebrow", "WEEKLY REPORT", 20, &"primary", true)
	AppWindow.label(col, root, "WeekTitle", "WEEK 1 IN REVIEW", 48, &"text", true, true)
	var headline := AppWindow.label(col, root, "WeekHeadline", "", 28, &"text", true, true)
	headline.autowrap_mode = TextServer.AUTOWRAP_WORD

	# --- day by day --------------------------------------------------------------
	var box := AppWindow.box(col, root, "Days", &"panel_hi", &"neutral_2", 20, 12)
	var grid := GridContainer.new()
	grid.name = "DaysGrid"
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 10)
	grid.unique_name_in_owner = true
	box.add_child(grid)
	grid.owner = root

	var totals := AppWindow.label(col, root, "TotalsLabel", "", 21, &"text_dim", false, true)
	totals.autowrap_mode = TextServer.AUTOWRAP_WORD

	# --- the week ahead ------------------------------------------------------------
	AppWindow.rule(col, root, "NextRule")
	AppWindow.label(col, root, "NextTitle", "NEXT WEEK", 18, &"text_dim", true)
	var next := AppWindow.label(col, root, "NextLabel", "", 22, &"text", false, true)
	next.autowrap_mode = TextServer.AUTOWRAP_WORD

	var row := HBoxContainer.new()
	row.name = "ButtonRow"
	row.alignment = BoxContainer.ALIGNMENT_END
	col.add_child(row)
	row.owner = root
	var start := Button.new()
	start.name = "StartButton"
	start.text = "START WEEK 2"
	start.custom_minimum_size = Vector2(320, 72)
	start.add_theme_font_size_override("font_size", 26)
	ButtonStyle.filled(start, Palette.color(&"primary"))
	start.unique_name_in_owner = true
	row.add_child(start)
	start.owner = root

	var packed := PackedScene.new()
	packed.pack(root)
	var err := ResourceSaver.save(packed, "res://scenes/week_report.tscn")
	if err != OK:
		push_error("failed to save week_report.tscn: %d" % err)
		quit(1)
		return
	print("saved week_report.tscn")
	root.free()
	quit(0)
