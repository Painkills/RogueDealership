extends SceneTree
## Builds res://scenes/tutorial_coach.tscn - the practice shift's training memo
## and highlighter. See scripts/view/tutorial_coach.gd.
##
## Its own CanvasLayer, above the shift's HUD, so the memo and the highlighter
## draw over the log and the buttons they are pointing at. The memo is pinned
## over the top of the shift log: the log is the one thing on screen the
## lesson never asks you to look at, and the left rail is the one side the
## table never reaches toward (see build_shift_scene.gd's LOG_RECT).

const LAYER := 50
const DESIGN := Vector2(1920, 1080)
const MEMO_POS := Vector2(18, 80)
const MEMO_WIDTH := 370.0

func _init() -> void:
	var root := CanvasLayer.new()
	root.name = "TutorialCoach"
	root.layer = LAYER
	root.set_script(load("res://scripts/view/tutorial_coach.gd"))

	# The design canvas outright rather than anchored to the window - there is
	# no resize this layer should ever have to hear about (see
	# build_shift_scene.gd's _cover_the_hud() for what anchoring cost once).
	var canvas := Control.new()
	canvas.name = "Canvas"
	canvas.size = DESIGN
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(canvas)
	canvas.owner = root

	var highlight := Control.new()
	highlight.name = "Highlight"
	highlight.set_script(load("res://scripts/view/tutorial_highlight.gd"))
	highlight.size = DESIGN
	highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	highlight.unique_name_in_owner = true
	canvas.add_child(highlight)
	highlight.owner = root

	var memo := PanelContainer.new()
	memo.name = "Memo"
	memo.position = MEMO_POS
	memo.custom_minimum_size = Vector2(MEMO_WIDTH, 0)
	# STOP, but only over its own rect: its buttons need the click, and nothing
	# behind the memo is anything the lesson asks you to press.
	memo.mouse_filter = Control.MOUSE_FILTER_STOP
	memo.unique_name_in_owner = true
	# A white card with the house blue down its leading edge.
	var card := StyleBoxFlat.new()
	card.bg_color = Palette.color(&"panel")
	card.border_color = Palette.color(&"primary")
	card.border_width_left = 6
	card.set_corner_radius_all(14)
	card.content_margin_left = 22
	card.content_margin_right = 18
	card.content_margin_top = 16
	card.content_margin_bottom = 16
	card.shadow_color = Color(0, 0, 0, 0.35)
	card.shadow_size = 14
	card.shadow_offset = Vector2(0, 6)
	memo.add_theme_stylebox_override("panel", card)
	canvas.add_child(memo)
	memo.owner = root

	var col := VBoxContainer.new()
	col.name = "Column"
	col.add_theme_constant_override("separation", 8)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	memo.add_child(col)
	col.owner = root

	var header := HBoxContainer.new()
	header.name = "Header"
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(header)
	header.owner = root

	# A small pill saying what this is.
	var badge := PanelContainer.new()
	badge.name = "Badge"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pill := StyleBoxFlat.new()
	pill.bg_color = Palette.color(&"primary")
	pill.set_corner_radius_all(10)
	pill.content_margin_left = 10
	pill.content_margin_right = 10
	pill.content_margin_top = 1
	pill.content_margin_bottom = 2
	badge.add_theme_stylebox_override("panel", pill)
	header.add_child(badge)
	badge.owner = root
	var badge_label := _label(badge, root, "BadgeLabel", "TUTORIAL", 16, &"paper")
	badge_label.theme_type_variation = &"Heading"

	var spacer := Control.new()
	spacer.name = "Spacer"
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(spacer)
	spacer.owner = root
	_label(header, root, "StepLabel", "1 / 13", 18, &"text_dim")

	var title := _label(col, root, "TitleLabel", "Welcome to the F&I office", 28, &"text")
	title.theme_type_variation = &"Heading"
	var body := _label(col, root, "BodyLabel",
		"Their file: who they are, what kind of buyer they are, and their patience. When patience runs out they walk - and a walkout costs you standing.",
		20, &"text")
	body.autowrap_mode = TextServer.AUTOWRAP_WORD
	var hint := _label(col, root, "HintLabel", "", 19, &"stamp")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	hint.visible = false
	var prompt := _label(col, root, "PromptLabel", "", 18, &"text_dim")
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD

	var buttons := HBoxContainer.new()
	buttons.name = "Buttons"
	buttons.add_theme_constant_override("separation", 12)
	buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(buttons)
	buttons.owner = root

	var skip := Button.new()
	skip.name = "SkipButton"
	skip.text = "SKIP TUTORIAL"
	skip.add_theme_font_size_override("font_size", 16)
	ButtonStyle.outlined(skip, Palette.color(&"ink_dim"))
	skip.unique_name_in_owner = true
	buttons.add_child(skip)
	skip.owner = root

	var gap := Control.new()
	gap.name = "Gap"
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	buttons.add_child(gap)
	gap.owner = root

	var next := Button.new()
	next.name = "NextButton"
	next.text = "NEXT"
	next.add_theme_font_size_override("font_size", 20)
	ButtonStyle.filled(next, Palette.color(&"primary"))
	next.unique_name_in_owner = true
	buttons.add_child(next)
	next.owner = root

	var packed := PackedScene.new()
	packed.pack(root)
	var err := ResourceSaver.save(packed, "res://scenes/tutorial_coach.tscn")
	if err != OK:
		push_error("failed to save tutorial_coach.tscn: %d" % err)
		quit(1)
		return
	print("saved tutorial_coach.tscn")
	root.free()
	quit(0)

func _label(parent: Node, owner_root: Node, node_name: String, text: String,
		size: int, role: StringName) -> Label:
	var l := Label.new()
	l.name = node_name
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Palette.color(role))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.unique_name_in_owner = true
	parent.add_child(l)
	l.owner = owner_root
	return l
