extends SceneTree
## Builds res://scenes/cards/customer_front_2d.tscn - the face of a CUSTOMER
## card, drawn as 2D UI at 500x700 and rendered to a texture by the card.
##
## Identity ONLY: portrait, name, archetype, patience. Everything else about a
## customer now lives on the detail card that slides out from behind this one
## when you sit down, which is what stopped this face from having to grow - and
## a growing card was what kept colliding with the product slot below it.
##
## The one thing here that is not identity is the status line, and it earns its
## place: with the floor framed on the customer row alone you would otherwise
## have no way at all to see that you left a product sitting with someone.

const W := 500
const H := 700
const PAD := 26

func _init() -> void:
	var root := Control.new()
	root.name = "CustomerFront"
	root.custom_minimum_size = Vector2(W, H)
	root.size = Vector2(W, H)

	var bg := ColorRect.new()
	bg.name = "Background"
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Palette.color(&"panel")
	root.add_child(bg)
	bg.owner = root

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, PAD)
	root.add_child(margin)
	margin.owner = root

	var col := VBoxContainer.new()
	col.name = "Column"
	col.add_theme_constant_override("separation", 12)
	margin.add_child(col)
	col.owner = root

	var portrait := PanelContainer.new()
	portrait.name = "PortraitFrame"
	portrait.custom_minimum_size = Vector2(0, 268)
	col.add_child(portrait)
	portrait.owner = root

	var portrait_fill := ColorRect.new()
	portrait_fill.name = "PortraitFill"
	portrait_fill.color = Palette.color(&"neutral_2")
	portrait.add_child(portrait_fill)
	portrait_fill.owner = root

	var portrait_label := _label("PortraitLabel", 32, Palette.color(&"text_dim"))
	portrait_label.text = "PORTRAIT"
	portrait_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	portrait_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	portrait.add_child(portrait_label)
	portrait_label.owner = root

	var name_label := _label("NameLabel", 50, Palette.color(&"text"))
	name_label.text = "Customer Name"
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.custom_minimum_size = Vector2(0, 116)
	col.add_child(name_label)
	name_label.owner = root

	var arch_label := _label("ArchetypeLabel", 32, Palette.color(&"accent"))
	arch_label.text = "Archetype"
	arch_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(arch_label)
	arch_label.owner = root

	var patience_bar := ProgressBar.new()
	patience_bar.name = "PatienceBar"
	patience_bar.min_value = 0
	patience_bar.max_value = 16
	patience_bar.value = 12
	patience_bar.show_percentage = false
	patience_bar.custom_minimum_size = Vector2(0, 34)
	col.add_child(patience_bar)
	patience_bar.owner = root

	var patience_label := _label("PatienceLabel", 30, Palette.color(&"text"))
	patience_label.text = "patience 12/16"
	patience_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(patience_label)
	patience_label.owner = root

	var status_label := _label("StatusLabel", 26, Palette.color(&"margin"))
	status_label.text = "(what is on their table shows here)"
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(status_label)
	status_label.owner = root

	var packed := PackedScene.new()
	packed.pack(root)
	var err := ResourceSaver.save(packed, "res://scenes/cards/customer_front_2d.tscn")
	if err != OK:
		push_error("failed to save customer_front_2d.tscn: %d" % err)
		quit(1)
		return
	print("saved customer_front_2d.tscn")
	root.free()
	quit(0)

func _label(node_name: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.name = node_name
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("shadow_offset_x", 3)
	l.add_theme_constant_override("shadow_offset_y", 3)
	return l
