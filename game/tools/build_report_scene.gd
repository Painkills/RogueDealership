extends SceneTree

func _init() -> void:
	var root := PanelContainer.new()
	root.name = "ReportPanel"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.set_script(load("res://scripts/view/report_panel.gd"))

	var vbox := VBoxContainer.new()
	vbox.name = "VBoxContainer"
	root.add_child(vbox)
	vbox.owner = root

	var title := Label.new()
	title.name = "TitleLabel"
	title.text = "CLOSING TIME"
	vbox.add_child(title)
	title.owner = root

	var banked := Label.new()
	banked.name = "BankedLabel"
	banked.unique_name_in_owner = true
	vbox.add_child(banked)
	banked.owner = root

	var bonus := Label.new()
	bonus.name = "BonusLabel"
	bonus.unique_name_in_owner = true
	vbox.add_child(bonus)
	bonus.owner = root

	var customers := Label.new()
	customers.name = "CustomersLabel"
	customers.unique_name_in_owner = true
	vbox.add_child(customers)
	customers.owner = root

	var offers := Label.new()
	offers.name = "OffersLabel"
	offers.unique_name_in_owner = true
	vbox.add_child(offers)
	offers.owner = root

	var margin := Label.new()
	margin.name = "MarginMovedLabel"
	margin.unique_name_in_owner = true
	vbox.add_child(margin)
	margin.owner = root

	var lost := Label.new()
	lost.name = "LostLabel"
	lost.unique_name_in_owner = true
	vbox.add_child(lost)
	lost.owner = root

	var restart := Button.new()
	restart.name = "RestartButton"
	restart.text = "Continue"
	restart.unique_name_in_owner = true
	vbox.add_child(restart)
	restart.owner = root

	var packed := PackedScene.new()
	packed.pack(root)
	ResourceSaver.save(packed, "res://scenes/report.tscn")
	print("saved report.tscn")
	quit(0)
