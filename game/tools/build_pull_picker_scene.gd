extends SceneTree
## Builds res://scenes/pull_picker.tscn - the mid-shift "reveal N cards, keep
## one" popup PullCards.apply() stages via Shift.pending_pull, as a dialog box
## over the floor (see AppWindow).
##
## PullRow is EMPTY here and filled at runtime by pull_picker.gd, the same
## "structure varies, build it in the script" approach deck_viewer.gd
## already uses for its own row counts - how many chips there are is data
## (Shift.pending_pull.revealed's own size), not a fixed shape this builder
## should have to know. The dialog sizes to its content for the same reason:
## a pull's chip count varies, and a fixed width would either crowd four
## chips or leave two rattling around.

func _init() -> void:
	var root := PanelContainer.new()
	root.name = "PullPicker"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.visible = false
	root.set_script(load("res://scripts/view/pull_picker.gd"))
	AppWindow.desktop(root, 0.86)

	var made := AppWindow.build(root, root, "PullWindow", "Pick a card", Vector2(640, 0), "", 36)
	var col: VBoxContainer = made["body"]
	col.add_theme_constant_override("separation", 20)

	var title := AppWindow.label(col, root, "PullTitleLabel", "CHOOSE ONE", 32, &"text",
		true, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub := AppWindow.label(col, root, "PullSubLabel", "Keep one. The rest go back.", 20,
		&"text_dim")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var row := HBoxContainer.new()
	row.name = "PullRow"
	row.unique_name_in_owner = true
	row.add_theme_constant_override("separation", 20)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	row.owner = root

	var buttons := HBoxContainer.new()
	buttons.name = "Buttons"
	buttons.alignment = BoxContainer.ALIGNMENT_END
	col.add_child(buttons)
	buttons.owner = root
	var cancel := Button.new()
	cancel.name = "PullCancelButton"
	cancel.unique_name_in_owner = true
	cancel.text = "CANCEL"
	cancel.custom_minimum_size = Vector2(200, 60)
	cancel.add_theme_font_size_override("font_size", 22)
	ButtonStyle.outlined(cancel, Palette.color(&"ink_dim"))
	buttons.add_child(cancel)
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
