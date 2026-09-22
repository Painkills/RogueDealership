extends SceneTree
## Builds res://scenes/pull_picker.tscn - the mid-shift "reveal N cards, keep
## one" popup PullCards.apply() stages via Shift.pending_pull.
##
## PullRow is EMPTY here and filled at runtime by pull_picker.gd, the same
## "structure varies, build it in the script" approach deck_viewer.gd
## already uses for its own row counts - how many chips there are is data
## (Shift.pending_pull.revealed's own size), not a fixed shape this builder
## should have to know.
##
## Same PanelContainer-card-over-a-full-rect-ground shape report.tscn
## already uses, minus report's fixed card width - a pull's chip count
## varies far more than the report's own fixed nine lines do, so the card
## sizes to its content instead of forcing a width that would either
## crowd four chips or leave two rattling around in too much room.

func _init() -> void:
	var root := PanelContainer.new()
	root.name = "PullPicker"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.visible = false
	var ground := StyleBoxFlat.new()
	ground.bg_color = Palette.color(&"bg")
	root.add_theme_stylebox_override("panel", ground)
	root.set_script(load("res://scripts/view/pull_picker.gd"))

	var wrap := CenterContainer.new()
	wrap.name = "CenterWrap"
	wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(wrap)
	wrap.owner = root

	var card := PanelContainer.new()
	card.name = "Card"
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Palette.color(&"panel_hi")
	card_style.set_border_width_all(2)
	card_style.border_color = Palette.color(&"neutral_3")
	card_style.set_content_margin_all(40)
	card.add_theme_stylebox_override("panel", card_style)
	wrap.add_child(card)
	card.owner = root

	var vbox := VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.add_theme_constant_override("separation", 24)
	card.add_child(vbox)
	vbox.owner = root

	var title := Label.new()
	title.name = "PullTitleLabel"
	title.unique_name_in_owner = true
	title.text = "CHOOSE ONE"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Palette.color(&"text"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	title.owner = root

	var row := HBoxContainer.new()
	row.name = "PullRow"
	row.unique_name_in_owner = true
	row.add_theme_constant_override("separation", 20)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(row)
	row.owner = root

	var cancel_wrap := CenterContainer.new()
	cancel_wrap.name = "CancelWrap"
	vbox.add_child(cancel_wrap)
	cancel_wrap.owner = root

	var cancel := Button.new()
	cancel.name = "PullCancelButton"
	cancel.unique_name_in_owner = true
	cancel.text = "CANCEL"
	cancel.custom_minimum_size = Vector2(240, 64)
	cancel.add_theme_font_size_override("font_size", 24)
	cancel_wrap.add_child(cancel)
	cancel.owner = root

	var packed := PackedScene.new()
	packed.pack(root)
	var err := ResourceSaver.save(packed, "res://scenes/pull_picker.tscn")
	if err != OK:
		push_error("failed to save pull_picker.tscn: %d" % err)
		quit(1)
		return
	print("saved pull_picker.tscn")
	root.free()
	quit(0)
