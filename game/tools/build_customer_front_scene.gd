extends SceneTree
## Builds res://scenes/cards/customer_front_2d.tscn - the face of a CUSTOMER
## card, drawn as 2D UI at 500x700 and rendered to a texture by the card.
##
## The face has two states. On the floor you see only the bare identity - who
## they are, what type, how much patience is left. Selecting them expands the
## card, and the Detail block below the rule unhides: what their archetype does
## to you, and what is sitting on their table unsigned.
##
## Both states live in one scene rather than two, so there is nothing to keep in
## sync and the expansion is a visibility toggle plus a scale tween.

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
	col.add_theme_constant_override("separation", 10)
	margin.add_child(col)
	col.owner = root

	# --- always visible: who they are ------------------------------------
	var portrait := PanelContainer.new()
	portrait.name = "PortraitFrame"
	portrait.custom_minimum_size = Vector2(0, 210)
	col.add_child(portrait)
	portrait.owner = root

	var portrait_fill := ColorRect.new()
	portrait_fill.name = "PortraitFill"
	portrait_fill.color = Palette.color(&"neutral_2")
	portrait.add_child(portrait_fill)
	portrait_fill.owner = root

	var portrait_label := _label("PortraitLabel", 30, Palette.color(&"text_dim"))
	portrait_label.text = "PORTRAIT"
	portrait_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	portrait_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	portrait.add_child(portrait_label)
	portrait_label.owner = root

	var name_label := _label("NameLabel", 44, Palette.color(&"text"))
	name_label.text = "Customer Name"
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.custom_minimum_size = Vector2(0, 100)
	col.add_child(name_label)
	name_label.owner = root

	var arch_label := _label("ArchetypeLabel", 30, Palette.color(&"accent"))
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
	patience_bar.custom_minimum_size = Vector2(0, 30)
	col.add_child(patience_bar)
	patience_bar.owner = root

	var patience_label := _label("PatienceLabel", 30, Palette.color(&"text"))
	patience_label.text = "patience 12/16"
	patience_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(patience_label)
	patience_label.owner = root

	# --- only once you have selected them --------------------------------
	var detail := VBoxContainer.new()
	detail.name = "Detail"
	detail.visible = false
	detail.add_theme_constant_override("separation", 6)
	col.add_child(detail)
	detail.owner = root

	var rule := ColorRect.new()
	rule.name = "Rule"
	rule.custom_minimum_size = Vector2(0, 3)
	rule.color = Palette.color(&"neutral_2")
	detail.add_child(rule)
	rule.owner = root

	var line_label := _label("LineLabel", 30, Palette.color(&"appeal"))
	line_label.text = "THE LINE  ?"
	line_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.add_child(line_label)
	line_label.owner = root

	var does_title := _label("DoesTitle", 22, Palette.color(&"text_dim"))
	does_title.text = "WHAT THEY DO"
	detail.add_child(does_title)
	does_title.owner = root

	var does_label := _label("DoesLabel", 24, Palette.color(&"text"))
	does_label.text = "(their behaviours show here)"
	does_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	detail.add_child(does_label)
	does_label.owner = root

	var table_title := _label("TableTitle", 22, Palette.color(&"text_dim"))
	table_title.text = "UNSIGNED"
	detail.add_child(table_title)
	table_title.owner = root

	var table_label := _label("TableLabel", 24, Palette.color(&"margin"))
	table_label.text = "(what they have agreed to shows here)"
	table_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	detail.add_child(table_label)
	table_label.owner = root

	var known_label := _label("KnownLabel", 22, Palette.color(&"text_dim"))
	known_label.text = "(what you have learned shows here)"
	known_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	detail.add_child(known_label)
	known_label.owner = root

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
