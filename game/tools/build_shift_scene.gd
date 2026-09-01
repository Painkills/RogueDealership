extends SceneTree

func _init() -> void:
	var root := Control.new()
	root.name = "ShiftController"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.set_script(load("res://scripts/view/shift_controller.gd"))

	var background := ColorRect.new()
	background.name = "Background"
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.unique_name_in_owner = true
	root.add_child(background)
	background.owner = root

	var vbox := VBoxContainer.new()
	vbox.name = "Root"
	root.add_child(vbox)
	vbox.owner = root

	var top_bar := HBoxContainer.new()
	top_bar.name = "TopBar"
	vbox.add_child(top_bar)
	top_bar.owner = root

	var tick_label := Label.new()
	tick_label.name = "TickLabel"
	tick_label.unique_name_in_owner = true
	top_bar.add_child(tick_label)
	tick_label.owner = root

	var banked_label := Label.new()
	banked_label.name = "BankedLabel"
	banked_label.unique_name_in_owner = true
	top_bar.add_child(banked_label)
	banked_label.owner = root

	var at_risk_label := Label.new()
	at_risk_label.name = "AtRiskLabel"
	at_risk_label.unique_name_in_owner = true
	top_bar.add_child(at_risk_label)
	at_risk_label.owner = root

	var floor_row := HBoxContainer.new()
	floor_row.name = "FloorRow"
	floor_row.unique_name_in_owner = true
	vbox.add_child(floor_row)             # empty - populated at runtime
	floor_row.owner = root

	var customer_slot := Control.new()
	customer_slot.name = "CustomerSlot"
	customer_slot.unique_name_in_owner = true
	vbox.add_child(customer_slot)
	customer_slot.owner = root

	var empty_slot_label := Label.new()
	empty_slot_label.name = "EmptySlotLabel"
	empty_slot_label.text = "Stand with a customer to negotiate."
	empty_slot_label.visible = true       # matches the starting state: nobody is selected yet
	empty_slot_label.unique_name_in_owner = true
	customer_slot.add_child(empty_slot_label)
	empty_slot_label.owner = root

	var hand_row := HBoxContainer.new()
	hand_row.name = "HandRow"
	hand_row.unique_name_in_owner = true
	vbox.add_child(hand_row)               # empty - populated at runtime
	hand_row.owner = root

	var event_log := RichTextLabel.new()
	event_log.name = "EventLog"
	event_log.bbcode_enabled = true
	event_log.scroll_following = true
	event_log.unique_name_in_owner = true
	vbox.add_child(event_log)
	event_log.owner = root

	var report_scene: PackedScene = load("res://scenes/report.tscn")
	var report_overlay := report_scene.instantiate()
	report_overlay.name = "ReportOverlay"
	report_overlay.visible = false
	report_overlay.unique_name_in_owner = true
	root.add_child(report_overlay)
	report_overlay.owner = root

	var packed := PackedScene.new()
	packed.pack(root)
	ResourceSaver.save(packed, "res://scenes/shift.tscn")
	print("saved shift.tscn")
	quit(0)
