extends SceneTree
## Builds res://scenes/title.tscn - the front door: a drawn dealership
## (DealershipArt) with three cards over it, one showing at a time - the menu,
## the high scores, and a new game's first-day welcome. See title_screen.gd.

## Clear of the showroom, which DealershipArt draws right of centre.
const CARD_LEFT := 110

func _init() -> void:
	var root := Control.new()
	root.name = "TitleScreen"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.set_script(load("res://scripts/view/title_screen.gd"))

	var art := Control.new()
	art.name = "Art"
	art.set_script(load("res://scripts/view/dealership_art.gd"))
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.unique_name_in_owner = true
	root.add_child(art)
	art.owner = root

	_menu(root)
	_scores(root)
	_intro(root)

	var packed := PackedScene.new()
	packed.pack(root)
	var err := ResourceSaver.save(packed, "res://scenes/title.tscn")
	if err != OK:
		push_error("failed to save title.tscn: %d" % err)
		quit(1)
		return
	print("saved title.tscn")
	root.free()
	quit(0)

# --- the menu --------------------------------------------------------------

func _menu(root: Control) -> void:
	var col := _card(root, "MenuCard", 560)
	AppWindow.label(col, root, "Eyebrow", "AN F&I CARD GAME", 20, &"accent", true)
	var title := AppWindow.label(col, root, "GameTitle", "ROGUE\nDEALERSHIP", 72, &"ink", true)
	title.add_theme_constant_override("line_spacing", -8)
	var tag := AppWindow.label(col, root, "Tagline",
		"They bought the car. Now sell them everything else.", 24, &"text_dim")
	tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_gap(col, root, 14)
	_button(col, root, "NewGameButton", "NEW GAME", &"primary", true)
	_button(col, root, "TutorialButton", "TUTORIAL", &"primary", false)
	_button(col, root, "HighScoresButton", "HIGH SCORES", &"ink", false)

# --- the high scores -------------------------------------------------------

func _scores(root: Control) -> void:
	var col := _card(root, "ScoresCard", 780)
	AppWindow.label(col, root, "ScoresTitle", "HIGH SCORES", 48, &"ink", true)
	AppWindow.label(col, root, "ScoresSub", "The best weeks worked on this device.", 22, &"text_dim")
	AppWindow.rule(col, root, "ScoresRule")
	var list := VBoxContainer.new()
	list.name = "ScoresList"
	list.add_theme_constant_override("separation", 8)
	list.unique_name_in_owner = true
	col.add_child(list)
	list.owner = root
	var empty := AppWindow.label(col, root, "ScoresEmpty",
		"No weeks on the board yet. Go sell something.", 24, &"text_dim", false, true)
	empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_gap(col, root, 8)
	var back := _button(col, root, "ScoresBackButton", "BACK", &"ink", false)
	back.custom_minimum_size = Vector2(220, 60)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN

# --- a new game's first day ------------------------------------------------

func _intro(root: Control) -> void:
	var col := _card(root, "IntroCard", 820)
	AppWindow.label(col, root, "IntroEyebrow", "FIRST DAY ON THE JOB", 20, &"accent", true)
	AppWindow.label(col, root, "IntroTitle", "You got the job!", 54, &"ink", true)
	var body := AppWindow.label(col, root, "IntroBody",
		"Congratulations - you're the new F&I Manager at Rogue Dealership.\n\n"
		+ "Sales sells them the car. Then they sit down at YOUR desk, and "
		+ "everything else is yours to sell: warranties, GAP, protection plans.\n\n"
		+ "It's your first day. Every shift has a quota, and the GM is watching "
		+ "your numbers. Pick today's shift from your calendar - and try not to "
		+ "get fired.", 24, &"text", false, true)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var tag_row := HBoxContainer.new()
	tag_row.name = "NameRow"
	tag_row.add_theme_constant_override("separation", 16)
	col.add_child(tag_row)
	tag_row.owner = root
	var tag_label := AppWindow.label(tag_row, root, "NameLabel", "Name on your badge:", 24, &"text_dim")
	tag_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var field := LineEdit.new()
	field.name = "IntroName"
	field.placeholder_text = "WRITE YOUR NAME"
	field.custom_minimum_size = Vector2(380, 58)
	field.add_theme_font_size_override("font_size", 26)
	field.unique_name_in_owner = true
	tag_row.add_child(field)
	field.owner = root

	_gap(col, root, 6)
	var buttons := HBoxContainer.new()
	buttons.name = "IntroButtons"
	buttons.add_theme_constant_override("separation", 16)
	col.add_child(buttons)
	buttons.owner = root
	var back := _button(buttons, root, "IntroBackButton", "BACK", &"ink", false)
	back.custom_minimum_size = Vector2(220, 64)
	var spacer := Control.new()
	spacer.name = "Spacer"
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(spacer)
	spacer.owner = root
	var start := _button(buttons, root, "StartDayButton", "START MY FIRST DAY", &"primary", true)
	start.custom_minimum_size = Vector2(380, 64)

# --- pieces ----------------------------------------------------------------

## A white card on the left of the screen, centred top to bottom. Returns the
## column to fill.
func _card(root: Control, node_name: String, width: int) -> VBoxContainer:
	var card := PanelContainer.new()
	card.name = node_name
	card.unique_name_in_owner = true
	card.custom_minimum_size = Vector2(width, 0)
	card.anchor_left = 0.0
	card.anchor_right = 0.0
	card.anchor_top = 0.5
	card.anchor_bottom = 0.5
	card.offset_left = CARD_LEFT
	card.offset_right = CARD_LEFT + width
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.color(&"panel")
	style.border_color = Palette.color(&"neutral_3")
	style.set_border_width_all(1)
	style.set_corner_radius_all(18)
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 30
	style.shadow_offset = Vector2(0, 10)
	style.set_content_margin_all(40)
	card.add_theme_stylebox_override("panel", style)
	root.add_child(card)
	card.owner = root

	var col := VBoxContainer.new()
	col.name = "Column"
	col.add_theme_constant_override("separation", 14)
	card.add_child(col)
	col.owner = root
	return col

func _button(parent: Node, root: Control, node_name: String, text: String,
		role: StringName, filled: bool) -> Button:
	var b := Button.new()
	b.name = node_name
	b.text = text
	b.custom_minimum_size = Vector2(0, 66)
	b.add_theme_font_size_override("font_size", 26)
	if filled:
		ButtonStyle.filled(b, Palette.color(role))
	else:
		ButtonStyle.outlined(b, Palette.color(role))
	b.unique_name_in_owner = true
	parent.add_child(b)
	b.owner = root
	return b

func _gap(parent: Node, root: Control, height: int) -> void:
	var g := Control.new()
	g.name = "Gap"
	g.custom_minimum_size = Vector2(0, height)
	parent.add_child(g)
	g.owner = root
