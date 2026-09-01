extends SceneTree

func _init() -> void:
	var root := PanelContainer.new()
	root.name = "FloorCard"
	root.custom_minimum_size = Vector2(160, 112)
	root.set_script(load("res://scripts/view/floor_card.gd"))

	var vbox := VBoxContainer.new()
	vbox.name = "VBoxContainer"
	root.add_child(vbox)
	vbox.owner = root

	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.unique_name_in_owner = true
	vbox.add_child(name_label)
	name_label.owner = root

	var arch_label := Label.new()
	arch_label.name = "ArchetypeLabel"
	arch_label.unique_name_in_owner = true
	vbox.add_child(arch_label)
	arch_label.owner = root

	var patience_bar := ProgressBar.new()
	patience_bar.name = "PatienceBar"
	patience_bar.min_value = 0
	patience_bar.show_percentage = false
	patience_bar.unique_name_in_owner = true
	vbox.add_child(patience_bar)
	patience_bar.owner = root

	var patience_label := Label.new()
	patience_label.name = "PatienceLabel"
	patience_label.unique_name_in_owner = true
	vbox.add_child(patience_label)
	patience_label.owner = root

	var unsigned_label := Label.new()
	unsigned_label.name = "UnsignedLabel"
	unsigned_label.unique_name_in_owner = true
	vbox.add_child(unsigned_label)
	unsigned_label.owner = root

	var alert_label := Label.new()
	alert_label.name = "AlertLabel"
	alert_label.unique_name_in_owner = true
	vbox.add_child(alert_label)
	alert_label.owner = root

	var clicker := Button.new()
	clicker.name = "Clicker"
	clicker.flat = true
	clicker.unique_name_in_owner = true
	clicker.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(clicker)
	clicker.owner = root

	var hover := PanelContainer.new()
	hover.name = "HoverPanel"
	hover.visible = false
	hover.unique_name_in_owner = true
	root.add_child(hover)
	hover.owner = root

	var hover_vbox := VBoxContainer.new()
	hover_vbox.name = "VBoxContainer"
	hover.add_child(hover_vbox)
	hover_vbox.owner = root

	var hover_title := Label.new()
	hover_title.name = "HoverTitle"
	hover_title.text = "WHAT THEY DO"
	hover_vbox.add_child(hover_title)
	hover_title.owner = root

	var hover_body := Label.new()
	hover_body.name = "HoverBody"
	hover_body.autowrap_mode = TextServer.AUTOWRAP_WORD
	hover_body.unique_name_in_owner = true
	hover_vbox.add_child(hover_body)
	hover_body.owner = root

	var packed := PackedScene.new()
	packed.pack(root)
	ResourceSaver.save(packed, "res://scenes/floor_card.tscn")
	print("saved floor_card.tscn")
	quit(0)
