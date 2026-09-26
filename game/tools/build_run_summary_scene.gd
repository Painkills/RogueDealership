extends SceneTree
## Builds res://scenes/run_summary.tscn - the end of a run, as an email from
## the boss: how your week scored, line by line, and how it stacks up against
## the best weeks played on this device.
##
## A mail app, in the same window every report in the game is built in (see
## AppWindow): a folder list down the left, the message on the right. The
## words - subject, greeting, sign-off - are written at runtime by
## run_summary_panel.gd, because they depend on how the week went.

const WINDOW := Vector2(1440, 0)
const SIDEBAR_W := 250

func _init() -> void:
	var root := PanelContainer.new()
	root.name = "RunSummaryPanel"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.set_script(load("res://scripts/view/run_summary_panel.gd"))
	AppWindow.desktop(root, 0.94)

	var made := AppWindow.build(root, root, "MailWindow", "Mail - Inbox", WINDOW, "", 0)
	var body: VBoxContainer = made["body"]

	var split := HBoxContainer.new()
	split.name = "Split"
	split.add_theme_constant_override("separation", 0)
	body.add_child(split)
	split.owner = root

	_sidebar(split, root)

	var message := MarginContainer.new()
	message.name = "Message"
	message.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		message.add_theme_constant_override("margin_" + side, 44)
	message.add_theme_constant_override("margin_top", 32)
	message.add_theme_constant_override("margin_bottom", 36)
	split.add_child(message)
	message.owner = root

	var col := VBoxContainer.new()
	col.name = "Column"
	col.add_theme_constant_override("separation", 16)
	message.add_child(col)
	col.owner = root

	# --- the envelope ----------------------------------------------------------
	# Overridden at runtime; "You're fired." when standing hit 0.
	AppWindow.label(col, root, "TitleLabel", "Your week, by the numbers", 40, &"text",
		true, true)
	_sender(col, root)
	AppWindow.rule(col, root, "EnvelopeRule")

	# --- the letter --------------------------------------------------------------
	AppWindow.label(col, root, "GreetingLabel", "Hi Dana,", 26, &"text", false, true)
	var opening := AppWindow.label(col, root, "OpeningLabel",
		"That's the week. Here's where you landed - every line counts toward the number at the bottom.",
		23, &"text", false, true)
	opening.autowrap_mode = TextServer.AUTOWRAP_WORD

	var columns := HBoxContainer.new()
	columns.name = "Columns"
	columns.add_theme_constant_override("separation", 32)
	col.add_child(columns)
	columns.owner = root
	_scorecard(columns, root)
	_bests(columns, root)

	var sign_off := AppWindow.label(col, root, "SignOffLabel",
		"Keep it up.\n- Dale, General Manager", 23, &"text", false, true)
	sign_off.autowrap_mode = TextServer.AUTOWRAP_WORD

	var buttons := HBoxContainer.new()
	buttons.name = "Buttons"
	buttons.alignment = BoxContainer.ALIGNMENT_END
	col.add_child(buttons)
	buttons.owner = root
	var restart := Button.new()
	restart.name = "RestartButton"
	restart.text = "START A NEW WEEK"
	restart.custom_minimum_size = Vector2(340, 72)
	restart.add_theme_font_size_override("font_size", 26)
	ButtonStyle.filled(restart, Palette.color(&"primary"))
	restart.unique_name_in_owner = true
	buttons.add_child(restart)
	restart.owner = root

	var packed := PackedScene.new()
	packed.pack(root)
	var err := ResourceSaver.save(packed, "res://scenes/run_summary.tscn")
	if err != OK:
		push_error("failed to save run_summary.tscn: %d" % err)
		quit(1)
		return
	print("saved run_summary.tscn")
	root.free()
	quit(0)

## The mail app's folders - scenery, with the inbox you are reading lit.
func _sidebar(parent: Node, root: Node) -> void:
	var side := PanelContainer.new()
	side.name = "Sidebar"
	side.custom_minimum_size = Vector2(SIDEBAR_W, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.color(&"panel_hi")
	style.border_color = Palette.color(&"neutral_2")
	style.border_width_right = 1
	style.corner_radius_bottom_left = AppWindow.RADIUS - 1
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 24
	side.add_theme_stylebox_override("panel", style)
	parent.add_child(side)
	side.owner = root

	var list := VBoxContainer.new()
	list.name = "Folders"
	list.add_theme_constant_override("separation", 6)
	side.add_child(list)
	list.owner = root
	for spec in [["Inbox", "1"], ["Starred", ""], ["Sent", ""], ["Drafts", ""], ["Trash", ""]]:
		var inbox: bool = spec[0] == "Inbox"
		var row := AppWindow.box(list, root, spec[0] + "Folder",
			&"grid_lit" if inbox else &"panel_hi", &"", 12, 10)
		var line := HBoxContainer.new()
		line.name = "Line"
		row.add_child(line)
		line.owner = root
		var name_label := AppWindow.label(line, root, "Name", spec[0], 21,
			&"primary" if inbox else &"text_dim", inbox)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if spec[1] != "":
			AppWindow.label(line, root, "Count", spec[1], 19, &"primary", true)

## Who it is from, who it is to, and when - the header of every email.
func _sender(parent: Node, root: Node) -> void:
	var row := HBoxContainer.new()
	row.name = "Sender"
	row.add_theme_constant_override("separation", 16)
	parent.add_child(row)
	row.owner = root

	var avatar := PanelContainer.new()
	avatar.name = "Avatar"
	avatar.custom_minimum_size = Vector2(56, 56)
	avatar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var disc := StyleBoxFlat.new()
	disc.bg_color = Palette.color(&"primary")
	disc.set_corner_radius_all(28)
	avatar.add_theme_stylebox_override("panel", disc)
	row.add_child(avatar)
	avatar.owner = root
	var initials := AppWindow.label(avatar, root, "Initials", "DW", 22, &"paper", true)
	initials.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	initials.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var who := VBoxContainer.new()
	who.name = "Who"
	who.add_theme_constant_override("separation", 0)
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(who)
	who.owner = root
	AppWindow.label(who, root, "From", "Dale Whitmore  ·  General Manager", 22, &"text", true)
	AppWindow.label(who, root, "ToLabel", "to F&I Manager", 19, &"text_dim", false, true)

	var when := AppWindow.label(row, root, "WhenLabel", "Fri, 6:02 PM", 19, &"text_dim",
		false, true)
	when.size_flags_vertical = Control.SIZE_SHRINK_CENTER

## The week's six scoring lines and the score they add up to, as a table in
## the body of the email.
func _scorecard(parent: Node, root: Node) -> void:
	var card := AppWindow.box(parent, root, "Scorecard", &"panel", &"neutral_2", 22, 12)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col := VBoxContainer.new()
	col.name = "Rows"
	col.add_theme_constant_override("separation", 8)
	card.add_child(col)
	col.owner = root
	for row_name in ["MarginRow", "StandingRow", "StandingLostRow", "WalkoutsRow",
			"StreakRow", "ComboRow"]:
		var row := HBoxContainer.new()
		row.name = row_name
		row.unique_name_in_owner = true
		row.add_theme_constant_override("separation", 12)
		col.add_child(row)
		row.owner = root
		var what := AppWindow.label(row, root, "What", "Margin banked", 21, &"text")
		what.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var measured := AppWindow.label(row, root, "Measured", "$12,400", 21, &"text_dim")
		measured.custom_minimum_size = Vector2(130, 0)
		measured.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var pts := AppWindow.label(row, root, "Points", "+12,400", 21, &"patience_ok", true)
		pts.custom_minimum_size = Vector2(110, 0)
		pts.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	AppWindow.rule(col, root, "TotalRule")
	var total_row := HBoxContainer.new()
	total_row.name = "TotalRow"
	col.add_child(total_row)
	total_row.owner = root
	var caption := AppWindow.label(total_row, root, "Caption", "TOTAL SCORE", 26, &"text", true)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	AppWindow.label(total_row, root, "TotalLabel", "18,450", 44, &"margin", true, true)

## How this week stacks up against the best ones played on this device - the
## personal bests, each signed by whoever played it.
func _bests(parent: Node, root: Node) -> void:
	var card := AppWindow.box(parent, root, "Bests", &"panel_hi", &"neutral_2", 22, 12)
	card.custom_minimum_size = Vector2(430, 0)
	var col := VBoxContainer.new()
	col.name = "Column"
	col.add_theme_constant_override("separation", 10)
	card.add_child(col)
	col.owner = root
	AppWindow.label(col, root, "BestHeadline", "NEW PERSONAL BEST!", 26, &"money", true, true)
	AppWindow.label(col, root, "BestsCaption", "BEST WEEKS ON THIS COMPUTER", 17, &"text_dim",
		true)
	# Filled at runtime - one row per remembered run, best first.
	var list := VBoxContainer.new()
	list.name = "BestsList"
	list.unique_name_in_owner = true
	list.add_theme_constant_override("separation", 4)
	col.add_child(list)
	list.owner = root
