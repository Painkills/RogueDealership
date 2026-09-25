extends SceneTree
## Builds res://scenes/tutorial_coach.tscn - the practice shift's welcome, its
## training memo, its highlighter, and the way out. See
## scripts/view/tutorial_coach.gd.
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
## Top right, on the same row as the run's own VIEW DECK button and just left
## of it (see build_run_scene.gd) - where a way out of anything lives.
const EXIT_RECT := Rect2(1448, 8, 240, 56)
## The first-day welcome, centred on the floor it is welcoming you to.
const SPLASH_WIDTH := 880.0
const SPLASH_BUTTON := Vector2(320, 72)
const NAME_TAG := Vector2(360, 150)

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

	_memo(canvas, root)
	_exit_button(canvas, root)
	_splash(canvas, root)

	# Last, so it rains down over the welcome rather than behind it.
	var confetti := CPUParticles2D.new()
	confetti.name = "Confetti"
	confetti.unique_name_in_owner = true
	confetti.position = Vector2(DESIGN.x * 0.5, -40)
	confetti.emitting = false
	confetti.one_shot = true
	confetti.amount = 140
	confetti.lifetime = 3.4
	confetti.explosiveness = 0.8
	confetti.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	confetti.emission_rect_extents = Vector2(DESIGN.x * 0.48, 10)
	confetti.direction = Vector2(0, 1)
	confetti.spread = 30.0
	confetti.gravity = Vector2(0, 460)
	confetti.initial_velocity_min = 180.0
	confetti.initial_velocity_max = 520.0
	confetti.damping_min = 10.0
	confetti.damping_max = 50.0
	confetti.angle_min = 0.0
	confetti.angle_max = 360.0
	confetti.angular_velocity_min = -420.0
	confetti.angular_velocity_max = 420.0
	confetti.scale_amount_min = 0.8
	confetti.scale_amount_max = 1.5
	# Each piece one of the showroom's own colours, never a blend of two.
	var colours := Gradient.new()
	colours.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	var roles := [&"primary", &"accent", &"money", &"sticky", &"stamp", &"action"]
	colours.offsets = PackedFloat32Array(range(roles.size()).map(
		func(k): return float(k) / roles.size()))
	colours.colors = PackedColorArray(roles.map(func(r): return Palette.color(r)))
	confetti.color_initial_ramp = colours
	# And gone by the end rather than piling up on the floor.
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.75, 1.0])
	fade.colors = PackedColorArray([Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)])
	confetti.color_ramp = fade
	canvas.add_child(confetti)
	confetti.owner = root

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

## The training memo, pinned over the shift log.
func _memo(canvas: Control, root: Node) -> void:
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
	var badge_label := _label(badge, root, "BadgeLabel", "TRAINING", 16, &"paper")
	badge_label.theme_type_variation = &"Heading"

	var spacer := Control.new()
	spacer.name = "Spacer"
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(spacer)
	spacer.owner = root
	_label(header, root, "StepLabel", "1 / 12", 18, &"text_dim")

	var title := _label(col, root, "TitleLabel", "Meet your first customer", 28, &"text")
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

	# NEXT only - the way out is the EXIT TUTORIAL button at the top of the
	# screen, not a small button tucked beside it.
	var buttons := HBoxContainer.new()
	buttons.name = "Buttons"
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(buttons)
	buttons.owner = root

	var next := Button.new()
	next.name = "NextButton"
	next.text = "NEXT"
	next.add_theme_font_size_override("font_size", 20)
	ButtonStyle.filled(next, Palette.color(&"primary"))
	next.unique_name_in_owner = true
	buttons.add_child(next)
	next.owner = root

## The way out, for the whole lesson: big, dark and top right, where the way
## out of anything lives. It used to be a small outlined SKIP at the foot of
## the memo, easy to miss beside the blue NEXT.
func _exit_button(canvas: Control, root: Node) -> void:
	var exit := Button.new()
	exit.name = "ExitButton"
	exit.text = "EXIT TUTORIAL  ×"
	exit.position = EXIT_RECT.position
	exit.size = EXIT_RECT.size
	exit.custom_minimum_size = EXIT_RECT.size
	exit.add_theme_font_size_override("font_size", 22)
	ButtonStyle.filled(exit, Palette.color(&"ink"))
	exit.visible = false
	exit.unique_name_in_owner = true
	canvas.add_child(exit)
	exit.owner = root

## Day one: a name tag, a welcome, and two ways forward of equal size - learn
## the desk, or skip straight to the week.
func _splash(canvas: Control, root: Node) -> void:
	var splash := Control.new()
	splash.name = "Splash"
	splash.size = DESIGN
	splash.visible = false
	splash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	splash.unique_name_in_owner = true
	canvas.add_child(splash)
	splash.owner = root

	# Dims the floor behind it and takes its clicks: nothing on the table is
	# yours to touch until you have picked a way forward.
	var dim := Panel.new()
	dim.name = "Dim"
	dim.size = DESIGN
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := StyleBoxFlat.new()
	shade.bg_color = Color(Palette.color(&"neutral_1"), 0.62)
	dim.add_theme_stylebox_override("panel", shade)
	dim.unique_name_in_owner = true
	splash.add_child(dim)
	dim.owner = root

	var card := PanelContainer.new()
	card.name = "SplashCard"
	card.custom_minimum_size = Vector2(SPLASH_WIDTH, 0)
	card.position = Vector2((DESIGN.x - SPLASH_WIDTH) * 0.5, 210)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.unique_name_in_owner = true
	var face := StyleBoxFlat.new()
	face.bg_color = Palette.color(&"panel")
	face.set_corner_radius_all(26)
	face.content_margin_left = 56
	face.content_margin_right = 56
	face.content_margin_top = 44
	face.content_margin_bottom = 48
	face.shadow_color = Color(0, 0, 0, 0.45)
	face.shadow_size = 30
	face.shadow_offset = Vector2(0, 10)
	card.add_theme_stylebox_override("panel", face)
	splash.add_child(card)
	card.owner = root

	var col := VBoxContainer.new()
	col.name = "Column"
	col.add_theme_constant_override("separation", 14)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(col)
	col.owner = root

	_name_tag(col, root)

	var eyebrow := _label(col, root, "Eyebrow", "FIRST DAY ON THE JOB", 24, &"accent")
	eyebrow.theme_type_variation = &"Heading"
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title := _label(col, root, "SplashTitle", "Welcome aboard, Manager.", 58, &"text")
	title.theme_type_variation = &"Heading"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var body := _label(col, root, "SplashBody",
		"Sales just sold them the car. Now they're sitting at YOUR desk, and everything else is yours to sell - warranties, GAP, protection plans.\n\nThe GM is watching your numbers. No pressure.",
		25, &"text_dim")
	body.autowrap_mode = TextServer.AUTOWRAP_WORD
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var gap := Control.new()
	gap.name = "Gap"
	gap.custom_minimum_size = Vector2(0, 10)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(gap)
	gap.owner = root

	var buttons := HBoxContainer.new()
	buttons.name = "SplashButtons"
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 22)
	buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	buttons.unique_name_in_owner = true
	col.add_child(buttons)
	buttons.owner = root
	# Both the same size, on purpose: skipping is a real choice, not a small
	# print escape hatch. Which one is filled in is decided at runtime - see
	# tutorial_coach.gd's _dress_the_splash().
	for spec in [["SplashSkipButton", "SKIP TRAINING"], ["StartButton", "SHOW ME THE ROPES"]]:
		var b := Button.new()
		b.name = spec[0]
		b.text = spec[1]
		b.custom_minimum_size = SPLASH_BUTTON
		b.add_theme_font_size_override("font_size", 26)
		b.unique_name_in_owner = true
		buttons.add_child(b)
		b.owner = root

## A "HELLO my name is" sticker, filled in: the one thing on the first day that
## tells everyone who you are now.
func _name_tag(col: Control, root: Node) -> void:
	# The tag is tilted, and a tilted Control inside a container still takes
	# its untilted room - so it sits in a holder that centres it.
	var holder := CenterContainer.new()
	holder.name = "NameTagHolder"
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(holder)
	holder.owner = root

	var tag := PanelContainer.new()
	tag.name = "NameTag"
	tag.custom_minimum_size = NAME_TAG
	tag.pivot_offset = NAME_TAG * 0.5
	tag.rotation = deg_to_rad(-4.0)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.unique_name_in_owner = true
	var sticker := StyleBoxFlat.new()
	sticker.bg_color = Palette.color(&"paper")
	sticker.border_color = Palette.color(&"stamp")
	sticker.set_border_width_all(4)
	sticker.set_corner_radius_all(14)
	sticker.shadow_color = Color(0, 0, 0, 0.22)
	sticker.shadow_size = 8
	sticker.shadow_offset = Vector2(0, 3)
	tag.add_theme_stylebox_override("panel", sticker)
	holder.add_child(tag)
	tag.owner = root

	var col_tag := VBoxContainer.new()
	col_tag.name = "Column"
	col_tag.add_theme_constant_override("separation", 0)
	col_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.add_child(col_tag)
	col_tag.owner = root

	var band := PanelContainer.new()
	band.name = "Band"
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var red := StyleBoxFlat.new()
	red.bg_color = Palette.color(&"stamp")
	red.corner_radius_top_left = 10
	red.corner_radius_top_right = 10
	red.content_margin_top = 4
	red.content_margin_bottom = 6
	band.add_theme_stylebox_override("panel", red)
	col_tag.add_child(band)
	band.owner = root

	var band_col := VBoxContainer.new()
	band_col.name = "Column"
	band_col.add_theme_constant_override("separation", -6)
	band_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(band_col)
	band_col.owner = root
	var hello := _label(band_col, root, "Hello", "HELLO", 40, &"paper")
	hello.theme_type_variation = &"Heading"
	hello.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var my_name := _label(band_col, root, "MyNameIs", "my name is", 20, &"paper")
	my_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var who := _label(col_tag, root, "TagName", "F&I MANAGER", 46, &"ink")
	who.theme_type_variation = &"Heading"
	who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	who.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	who.size_flags_vertical = Control.SIZE_EXPAND_FILL

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
