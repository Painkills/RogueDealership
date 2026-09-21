extends PanelContainer
## Before every shift: pick a ShiftProfile. One button per profile, built
## fresh each setup() the same way shop_screen.gd rebuilds its rows - a
## handful of buttons is cheap enough that patching them is not worth the
## risk of disagreeing with the pool.

signal chosen(profile: ShiftProfile)

@onready var _row: HBoxContainer = %ProfileRow

func setup(pool: ShiftProfilePool) -> void:
	for child in _row.get_children():
		_row.remove_child(child)
		child.queue_free()
	for profile in pool.profiles:
		_row.add_child(_build_card(profile))

func _build_card(profile: ShiftProfile) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.custom_minimum_size = Vector2(320, 0)

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

	return col
