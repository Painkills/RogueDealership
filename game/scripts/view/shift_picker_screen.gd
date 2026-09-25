extends PanelContainer
## Before every shift: pick a ShiftProfile. One button per profile, built
## fresh each setup() the same way shop_screen.gd rebuilds its rows - a
## handful of buttons is cheap enough that patching them is not worth the
## risk of disagreeing with the pool.

signal chosen(profile: ShiftProfile)
## HOW TO PLAY - the practice shift, replayed on demand. It opens the game by
## itself only the first time (see RunController.tutorial_at_boot).
signal tutorial_requested

@onready var _row: HBoxContainer = %ProfileRow

func _ready() -> void:
	(%TutorialButton as Button).pressed.connect(func(): tutorial_requested.emit())

func setup(pool: ShiftProfilePool) -> void:
	for child in _row.get_children():
		_row.remove_child(child)
		child.queue_free()
	for profile in pool.profiles:
		_row.add_child(_build_card(profile))

## Each shift is a sheet on the desk - a paper card with an inked edge - so
## the three read as three things to pick up rather than three columns of text
## floating on the blotter.
func _build_card(profile: ShiftProfile) -> Control:
	var sheet := PanelContainer.new()
	var paper := StyleBoxFlat.new()
	paper.bg_color = Palette.color(&"panel_hi")
	paper.border_color = Palette.color(&"neutral_3")
	paper.set_border_width_all(2)
	paper.set_corner_radius_all(4)
	paper.content_margin_left = 24
	paper.content_margin_right = 24
	paper.content_margin_top = 22
	paper.content_margin_bottom = 22
	paper.shadow_color = Color(0, 0, 0, 0.25)
	paper.shadow_size = 6
	paper.shadow_offset = Vector2(2, 4)
	sheet.add_theme_stylebox_override("panel", paper)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.custom_minimum_size = Vector2(320, 0)
	sheet.add_child(col)

	var name_label := Label.new()
	name_label.text = profile.display_name
	name_label.add_theme_font_size_override("font_size", 30)
	name_label.add_theme_color_override("font_color", Palette.color(&"text"))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(name_label)

	var blurb_label := Label.new()
	blurb_label.text = profile.blurb
	blurb_label.add_theme_font_size_override("font_size", 20)
	blurb_label.add_theme_color_override("font_color", Palette.color(&"text_dim"))
	blurb_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	blurb_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	col.add_child(blurb_label)

	var reward_label := Label.new()
	reward_label.text = profile.reward_preview()
	reward_label.add_theme_font_size_override("font_size", 20)
	reward_label.add_theme_color_override("font_color", Palette.color(&"appeal"))
	reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	col.add_child(reward_label)

	var btn := Button.new()
	btn.text = "WORK THIS SHIFT"
	btn.custom_minimum_size = Vector2(0, 64)
	btn.add_theme_font_size_override("font_size", 22)
	btn.pressed.connect(func(): chosen.emit(profile))
	col.add_child(btn)

	return sheet
