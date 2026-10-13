extends SceneTree
## Builds res://scenes/run.tscn - the main scene, which hosts the shift and the
## shop and switches between them.

const DECK_VIEWER_SCENE := "res://scenes/deck_viewer.tscn"
## The width the corner's QUIT RUN button takes, the toolkit and calendar
## buttons moved over by it.
const QUIT_W := 186

func _init() -> void:
	var root := Node.new()
	root.name = "Run"
	root.set_script(load("res://scripts/view/run_controller.gd"))

	# Added first, so a picker chosen() before the very first shift's own
	# setup() runs still covers a floor that has never been built yet, the
	# same "on top of whatever's behind it" layering the summary view uses.
	var picker_view: Control = \
		(load("res://scenes/shift_picker.tscn") as PackedScene).instantiate()
	picker_view.name = "ShiftPickerView"
	picker_view.visible = false
	root.add_child(picker_view)
	picker_view.owner = root

	var shift_view: Node = (load("res://scenes/shift.tscn") as PackedScene).instantiate()
	shift_view.name = "ShiftView"
	root.add_child(shift_view)
	shift_view.owner = root

	var shop_view: Control = (load("res://scenes/shop.tscn") as PackedScene).instantiate()
	shop_view.name = "ShopView"
	shop_view.visible = false
	root.add_child(shop_view)
	shop_view.owner = root

	# Added after both, so it draws on top of whichever of them is visible
	# when the run ends - same layering trick as the shift's own ReportOverlay
	# covering the floor underneath it.
	var summary_view: Control = \
		(load("res://scenes/run_summary.tscn") as PackedScene).instantiate()
	summary_view.name = "RunSummaryView"
	summary_view.visible = false
	root.add_child(summary_view)
	summary_view.owner = root

	# Between weeks: how the one just worked went, before the next begins.
	var week_view: Control = \
		(load("res://scenes/week_report.tscn") as PackedScene).instantiate()
	week_view.name = "WeekReportView"
	week_view.visible = false
	root.add_child(week_view)
	week_view.owner = root

	# The front door - the menu, the high scores and a new game's first day.
	# The game opens on it, so it is the one screen visible as built.
	var title_view: Control = (load("res://scenes/title.tscn") as PackedScene).instantiate()
	title_view.name = "TitleView"
	root.add_child(title_view)
	title_view.owner = root

	# Added last of the four+one, so it draws on top of literally anything
	# beneath it - reachable from both the shop and the floor, so it cannot
	# belong to either of them (see run_controller.gd's own comment).
	var deck_viewer: Control = (load(DECK_VIEWER_SCENE) as PackedScene).instantiate()
	deck_viewer.name = "DeckViewer"
	root.add_child(deck_viewer)
	deck_viewer.owner = root

	# The practice shift's teacher. Its own CanvasLayer, above the floor's HUD
	# so it can point at the log and the buttons, and below the badge layer
	# so the corner VIEW TOOLKIT button still sits on top of everything.
	var coach: CanvasLayer = (load("res://scenes/tutorial_coach.tscn") as PackedScene).instantiate()
	coach.name = "TutorialCoach"
	root.add_child(coach)
	coach.owner = root

	# A permanent corner badge, not something either screen owns - so it
	# survives switching between them for free and can never be the thing a
	# screen's own layout work accidentally covers up. Its own CanvasLayer,
	# stacked above the shift's HUD layer, so it is never buried under a
	# customer card at the table's own draw order.
	var badge_layer := CanvasLayer.new()
	badge_layer.name = "BuildBadge"
	badge_layer.layer = 100
	root.add_child(badge_layer)
	badge_layer.owner = root

	var badge := Label.new()
	badge.name = "BuildLabel"
	badge.text = BuildInfo.LABEL
	badge.add_theme_font_size_override("font_size", 18)
	# Brass: the one mid-tone in the office, so it reads over the dark carpet
	# of the floor and the cream of every menu alike.
	badge.add_theme_color_override("font_color", Palette.color(&"brass"))
	badge.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	badge.add_theme_constant_override("shadow_offset_x", 2)
	badge.add_theme_constant_override("shadow_offset_y", 2)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.autowrap_mode = TextServer.AUTOWRAP_OFF
	# Label already defaults to IGNORE, so this changes nothing today - stated
	# explicitly anyway, since the exact bug it heads off (a full-rect
	# ColorRect eating clicks meant for the table, already caught once in
	# this project's own HUD) is one a LATER edit could reintroduce the
	# moment this badge stops being a plain Label.
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	badge.offset_left = -260
	badge.offset_top = -26
	badge.offset_right = -8
	badge.offset_bottom = -6
	badge_layer.add_child(badge)
	badge.owner = root

	# Top-right, same layer as the badge (always on screen, over any of the
	# four screens or the deck viewer itself) - a reliable click target for
	# "your toolkit" that does not depend on hitting the 3D draw pile's own
	# pick shape, which is a real click target too (see shift_controller.gd's
	# _draw_zone wiring) but a much smaller and less forgiving one.
	var view_deck_btn := Button.new()
	view_deck_btn.name = "ViewDeckCornerButton"
	# The same words as the store's own button to the same page - one name
	# for the thing, wherever you reach it from.
	view_deck_btn.text = "VIEW TOOLKIT"
	view_deck_btn.unique_name_in_owner = true
	view_deck_btn.custom_minimum_size = Vector2(240, 56)
	view_deck_btn.add_theme_font_size_override("font_size", 22)
	view_deck_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	# Anchored to the right edge, so any growth has to go left, into the
	# screen, rather than off it.
	view_deck_btn.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	view_deck_btn.offset_left = -256 - QUIT_W
	view_deck_btn.offset_top = 8
	view_deck_btn.offset_right = -16 - QUIT_W
	view_deck_btn.offset_bottom = 64
	badge_layer.add_child(view_deck_btn)
	view_deck_btn.owner = root

	# Beside it, on the floor only: this week's calendar, to look at and not
	# pick from - what the boss wants tomorrow, and when the boss day is.
	var view_calendar_btn := Button.new()
	view_calendar_btn.name = "ViewCalendarCornerButton"
	view_calendar_btn.text = "VIEW CALENDAR"
	view_calendar_btn.unique_name_in_owner = true
	view_calendar_btn.visible = false
	view_calendar_btn.custom_minimum_size = Vector2(240, 56)
	view_calendar_btn.add_theme_font_size_override("font_size", 22)
	view_calendar_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	view_calendar_btn.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	view_calendar_btn.offset_left = -512 - QUIT_W
	view_calendar_btn.offset_top = 8
	view_calendar_btn.offset_right = -272 - QUIT_W
	view_calendar_btn.offset_bottom = 64
	badge_layer.add_child(view_calendar_btn)
	view_calendar_btn.owner = root

	# The very corner, in a run only: give it up and go back to the front door -
	# asked first, since a run quit is a run lost.
	var quit_btn := Button.new()
	quit_btn.name = "QuitRunCornerButton"
	quit_btn.text = "QUIT RUN"
	quit_btn.unique_name_in_owner = true
	quit_btn.visible = false
	quit_btn.custom_minimum_size = Vector2(QUIT_W - 16, 56)
	quit_btn.add_theme_font_size_override("font_size", 22)
	ButtonStyle.outlined(quit_btn, Palette.color(&"alert"))
	quit_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	quit_btn.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	quit_btn.offset_left = -QUIT_W
	quit_btn.offset_top = 8
	quit_btn.offset_right = -16
	quit_btn.offset_bottom = 64
	badge_layer.add_child(quit_btn)
	quit_btn.owner = root

	# Over the build badge, on the title screen only: the touch equivalent of
	# Ctrl+B, a shortcut to the last fight (run_controller.gd's
	# _debug_last_fight()). No visible chrome at all - it is a testing
	# convenience, like the tick and standing counters' own.
	var last_fight_tap := Button.new()
	last_fight_tap.name = "LastFightTapTarget"
	last_fight_tap.flat = true
	last_fight_tap.visible = false
	last_fight_tap.unique_name_in_owner = true
	last_fight_tap.focus_mode = Control.FOCUS_NONE
	last_fight_tap.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	last_fight_tap.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	last_fight_tap.grow_vertical = Control.GROW_DIRECTION_BEGIN
	last_fight_tap.offset_left = -300
	last_fight_tap.offset_top = -44
	last_fight_tap.offset_right = -4
	last_fight_tap.offset_bottom = -4
	badge_layer.add_child(last_fight_tap)
	last_fight_tap.owner = root

	# And beside it, to its left: the same for the Repo Man (_debug_repo_fight()).
	var repo_tap := Button.new()
	repo_tap.name = "RepoManTapTarget"
	repo_tap.flat = true
	repo_tap.visible = false
	repo_tap.unique_name_in_owner = true
	repo_tap.focus_mode = Control.FOCUS_NONE
	repo_tap.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	repo_tap.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	repo_tap.grow_vertical = Control.GROW_DIRECTION_BEGIN
	repo_tap.offset_left = -600
	repo_tap.offset_top = -44
	repo_tap.offset_right = -304
	repo_tap.offset_bottom = -4
	badge_layer.add_child(repo_tap)
	repo_tap.owner = root

	_quit_popup(badge_layer, root)

	var packed := PackedScene.new()
	packed.pack(root)
	var err := ResourceSaver.save(packed, "res://scenes/run.tscn")
	if err != OK:
		push_error("failed to save run.tscn: %d" % err)
		quit(1)
		return
	print("saved run.tscn")
	root.free()
	quit(0)

## "Have a popup to confirm saying the run will be lost": over everything, on the
## corner buttons' own layer, so nothing on any screen can be pressed behind it.
func _quit_popup(layer: Node, root: Node) -> void:
	var popup := Control.new()
	popup.name = "QuitPopup"
	popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup.mouse_filter = Control.MOUSE_FILTER_STOP
	popup.visible = false
	popup.unique_name_in_owner = true
	layer.add_child(popup)
	popup.owner = root

	var dim := Panel.new()
	dim.name = "Dim"
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shade := StyleBoxFlat.new()
	shade.bg_color = Color(0, 0, 0, 0.6)
	dim.add_theme_stylebox_override("panel", shade)
	popup.add_child(dim)
	dim.owner = root

	var centre := CenterContainer.new()
	centre.name = "Centre"
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.add_child(centre)
	centre.owner = root

	var card := PanelContainer.new()
	card.name = "QuitCard"
	card.custom_minimum_size = Vector2(640, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.color(&"panel")
	style.border_color = Palette.color(&"neutral_3")
	style.set_border_width_all(1)
	style.set_corner_radius_all(18)
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 30
	style.set_content_margin_all(40)
	card.add_theme_stylebox_override("panel", style)
	centre.add_child(card)
	card.owner = root
	var col := VBoxContainer.new()
	col.name = "Column"
	col.add_theme_constant_override("separation", 16)
	card.add_child(col)
	col.owner = root
	AppWindow.label(col, root, "QuitEyebrow", "BEFORE YOU WALK OUT", 20, &"alert", true)
	AppWindow.label(col, root, "QuitTitle", "Quit this run?", 46, &"ink", true)
	var why := AppWindow.label(col, root, "QuitWhy",
		"The run will be lost - every day worked, your toolkit and your money. There's no getting it back.",
		22, &"text_dim")
	why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var buttons := HBoxContainer.new()
	buttons.name = "QuitButtons"
	buttons.add_theme_constant_override("separation", 16)
	col.add_child(buttons)
	buttons.owner = root
	var keep := _popup_button(buttons, root, "KeepPlayingButton", "KEEP PLAYING", &"primary", true)
	keep.custom_minimum_size = Vector2(260, 64)
	var spacer := Control.new()
	spacer.name = "Spacer"
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(spacer)
	spacer.owner = root
	var quit_it := _popup_button(buttons, root, "ConfirmQuitButton", "QUIT RUN", &"alert", false)
	quit_it.custom_minimum_size = Vector2(220, 64)

func _popup_button(parent: Node, root: Node, node_name: String, text: String,
		role: StringName, filled: bool) -> Button:
	var b := Button.new()
	b.name = node_name
	b.text = text
	b.add_theme_font_size_override("font_size", 24)
	if filled:
		ButtonStyle.filled(b, Palette.color(role))
	else:
		ButtonStyle.outlined(b, Palette.color(role))
	b.unique_name_in_owner = true
	parent.add_child(b)
	b.owner = root
	return b
