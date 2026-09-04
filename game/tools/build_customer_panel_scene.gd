extends SceneTree

func _init() -> void:
	var root := PanelContainer.new()
	root.name = "CustomerPanel"
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.set_script(load("res://scripts/view/customer_panel.gd"))

	var vbox := VBoxContainer.new()
	vbox.name = "VBoxContainer"
	root.add_child(vbox)
	vbox.owner = root

	var header := Label.new()
	header.name = "HeaderLabel"
	header.unique_name_in_owner = true
	vbox.add_child(header)
	header.owner = root

	var line_label := Label.new()
	line_label.name = "LineLabel"
	line_label.unique_name_in_owner = true
	vbox.add_child(line_label)
	line_label.owner = root

	var behaviour_title := Label.new()
	behaviour_title.name = "BehaviourTitle"
	behaviour_title.text = "WHAT THEY DO"
	behaviour_title.add_theme_color_override("font_color", Palette.color(&"text_dim"))
	vbox.add_child(behaviour_title)
	behaviour_title.owner = root

	var behaviour := Label.new()
	behaviour.name = "BehaviourLabel"
	behaviour.autowrap_mode = TextServer.AUTOWRAP_WORD
	# Deliberately NOT the same string the runtime can produce for an archetype
	# with no actions. If the placeholder and a real value can look identical, a
	# test that reads this label proves nothing - which is exactly what happened.
	behaviour.text = "(what this archetype does shows here)"
	behaviour.unique_name_in_owner = true
	vbox.add_child(behaviour)
	behaviour.owner = root

	var unsigned_title := Label.new()
	unsigned_title.name = "UnsignedTitle"
	unsigned_title.text = "ON THE TABLE, UNSIGNED"
	unsigned_title.add_theme_color_override("font_color", Palette.color(&"text_dim"))
	vbox.add_child(unsigned_title)
	unsigned_title.owner = root

	var unsigned_row := HBoxContainer.new()
	unsigned_row.name = "UnsignedRow"
	unsigned_row.unique_name_in_owner = true
	vbox.add_child(unsigned_row)
	unsigned_row.owner = root

	var offer_box := PanelContainer.new()
	offer_box.name = "OfferBox"
	offer_box.unique_name_in_owner = true
	vbox.add_child(offer_box)
	offer_box.owner = root

	var offer_vbox := VBoxContainer.new()
	offer_vbox.name = "VBoxContainer"
	offer_box.add_child(offer_vbox)
	offer_vbox.owner = root

	var offer_name := Label.new()
	offer_name.name = "OfferNameLabel"
	offer_name.unique_name_in_owner = true
	offer_vbox.add_child(offer_name)
	offer_name.owner = root

	var offer_category := Label.new()
	offer_category.name = "OfferCategoryLabel"
	offer_category.unique_name_in_owner = true
	offer_vbox.add_child(offer_category)
	offer_category.owner = root

	var offer_margin := Label.new()
	offer_margin.name = "OfferMarginLabel"
	offer_margin.unique_name_in_owner = true
	offer_vbox.add_child(offer_margin)
	offer_margin.owner = root

	var appeal_bar := Control.new()
	appeal_bar.name = "AppealBar"
	appeal_bar.custom_minimum_size = Vector2(200, 20)
	appeal_bar.unique_name_in_owner = true
	appeal_bar.set_script(load("res://scripts/view/appeal_bar.gd"))
	offer_vbox.add_child(appeal_bar)
	appeal_bar.owner = root

	var gap_label := Label.new()
	gap_label.name = "GapLabel"
	gap_label.unique_name_in_owner = true
	offer_vbox.add_child(gap_label)
	gap_label.owner = root

	var known := Label.new()
	known.name = "KnownLabel"
	known.unique_name_in_owner = true
	vbox.add_child(known)
	known.owner = root

	var packed := PackedScene.new()
	packed.pack(root)
	ResourceSaver.save(packed, "res://scenes/customer_panel.tscn")
	print("saved customer_panel.tscn")
	quit(0)
