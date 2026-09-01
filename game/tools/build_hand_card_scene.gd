extends SceneTree

func _init() -> void:
	var root := PanelContainer.new()
	root.name = "HandCard"
	root.custom_minimum_size = Vector2(96, 132)
	root.set_script(load("res://scripts/view/hand_card.gd"))

	var vbox := VBoxContainer.new()
	vbox.name = "VBoxContainer"
	root.add_child(vbox)
	vbox.owner = root

	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_label.unique_name_in_owner = true
	vbox.add_child(name_label)
	name_label.owner = root

	var cost_label := Label.new()
	cost_label.name = "CostLabel"
	cost_label.unique_name_in_owner = true
	vbox.add_child(cost_label)
	cost_label.owner = root

	var kind_label := Label.new()
	kind_label.name = "KindLabel"
	kind_label.unique_name_in_owner = true
	vbox.add_child(kind_label)
	kind_label.owner = root

	var effect_label := Label.new()
	effect_label.name = "EffectLabel"
	effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	effect_label.unique_name_in_owner = true
	vbox.add_child(effect_label)
	effect_label.owner = root

	var clicker := Button.new()
	clicker.name = "Clicker"
	clicker.flat = true
	clicker.unique_name_in_owner = true
	clicker.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(clicker)
	clicker.owner = root

	var packed := PackedScene.new()
	packed.pack(root)
	DirAccess.make_dir_recursive_absolute("res://scenes")
	ResourceSaver.save(packed, "res://scenes/hand_card.tscn")
	print("saved hand_card.tscn")
	quit(0)
