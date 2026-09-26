extends SceneTree
## Builds res://scenes/report.tscn - the end of a shift, as the dealership
## system's end-of-day report: an app window over the floor you just worked,
## the way everything the game reports is something on a screen (see AppWindow).
##
## The one number that matters most - banked vs quota - is the largest text in
## the report after its title; the rest is the supporting detail, in a panel
## of its own below it, in descending emphasis.

const WINDOW := Vector2(1100, 0)

func _init() -> void:
	var root := PanelContainer.new()
	root.name = "ReportPanel"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.set_script(load("res://scripts/view/report_panel.gd"))
	# See-through, so the floor you just worked is still there behind the
	# report on it.
	AppWindow.desktop(root, 0.88)

	var made := AppWindow.build(root, root, "ReportWindow",
		"Dealership System  -  End of Day Report", WINDOW, "", 40)
	var col: VBoxContainer = made["body"]
	col.add_theme_constant_override("separation", 14)

	# --- the headline: what happened, and by how much ----------------------
	AppWindow.label(col, root, "Eyebrow", "END OF DAY REPORT", 20, &"primary", true)
	# Overridden to "YOU'RE FIRED" on a fatal shift.
	AppWindow.label(col, root, "TitleLabel", "CLOSING TIME", 56, &"text", true, true)
	var banked := AppWindow.label(col, root, "BankedLabel", "", 36, &"text", true, true)
	banked.autowrap_mode = TextServer.AUTOWRAP_WORD
	var bonus := AppWindow.label(col, root, "BonusLabel", "", 24, &"text_dim", false, true)
	bonus.autowrap_mode = TextServer.AUTOWRAP_WORD

	# --- the supporting detail, in its own panel -----------------------------
	var detail := AppWindow.box(col, root, "Detail", &"panel_hi", &"neutral_2", 24, 12)
	var rows := VBoxContainer.new()
	rows.name = "Rows"
	rows.add_theme_constant_override("separation", 10)
	detail.add_child(rows)
	rows.owner = root
	AppWindow.label(rows, root, "StandingLabel", "", 26, &"text", false, true)
	var walkouts := AppWindow.label(rows, root, "WalkoutsLabel", "", 22, &"text", false, true)
	walkouts.autowrap_mode = TextServer.AUTOWRAP_WORD
	AppWindow.rule(rows, root, "DetailRule")
	AppWindow.label(rows, root, "CustomersLabel", "", 21, &"text_dim", false, true)
	AppWindow.label(rows, root, "OffersLabel", "", 21, &"text_dim", false, true)
	var moved := AppWindow.label(rows, root, "MarginMovedLabel", "", 21, &"text_dim",
		false, true)
	moved.autowrap_mode = TextServer.AUTOWRAP_WORD
	var lost := AppWindow.label(rows, root, "LostLabel", "", 21, &"text_dim", false, true)
	lost.autowrap_mode = TextServer.AUTOWRAP_WORD

	# The report's own button, bottom right where an app keeps it.
	var buttons := HBoxContainer.new()
	buttons.name = "Buttons"
	buttons.alignment = BoxContainer.ALIGNMENT_END
	col.add_child(buttons)
	buttons.owner = root
	var restart := Button.new()
	restart.name = "RestartButton"
	restart.text = "Continue"
	restart.custom_minimum_size = Vector2(320, 72)
	restart.add_theme_font_size_override("font_size", 28)
	ButtonStyle.filled(restart, Palette.color(&"primary"))
	restart.unique_name_in_owner = true
	buttons.add_child(restart)
	restart.owner = root

	var packed := PackedScene.new()
	packed.pack(root)
	var err := ResourceSaver.save(packed, "res://scenes/report.tscn")
	if err != OK:
		push_error("failed to save report.tscn: %d" % err)
		quit(1)
		return
	print("saved report.tscn")
	root.free()
	quit(0)
