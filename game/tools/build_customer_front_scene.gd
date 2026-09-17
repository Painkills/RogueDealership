extends SceneTree
## Builds res://scenes/cards/customer_front_2d.tscn - the face of a CUSTOMER
## card, drawn as 2D UI at 500x700 and rendered to a texture by the card.
##
## Everything you need to TRIAGE, and nothing you need to negotiate. Since the
## carousel, this face is on screen for all three customers all the time - two
## of them at 179 px wide - so it has to answer "who deserves the next tick"
## on its own, at that size, without anybody sitting down.
##
## Five rows: who they are, how long they will wait, what they are asking for
## right now, what you know about their list, and what is riding on them.
##
## THE PORTRAIT BOX IS GONE. It was 268 of 700 px - 38% of the card - holding a
## grey rectangle and the word PORTRAIT, reserved for art that does not exist
## and has not been scheduled. The interest grid lives there now. If real
## portraits ever arrive, putting it back is an edit to this file.

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

	# Placeholder text below is the longest string the real data can actually
	# produce (data/archetype_pool.tres names/archetypes, data/demands/*.tres
	# telegraphs, data/card_pool.tres product names) rather than a generic
	# filler word, so this scene shows its own worst case in the editor.
	var name_label := _label("NameLabel", 50, Palette.color(&"text"))
	name_label.text = "Sandra Okonkwo"   # longest name in archetype_pool.tres
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.custom_minimum_size = Vector2(0, 116)
	col.add_child(name_label)
	name_label.owner = root

	var arch_label := _label("ArchetypeLabel", 32, Palette.color(&"accent"))
	arch_label.text = "Tech Enthusiast  [C]"   # longest archetype display_name + chair key
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
	patience_label.text = "patience 16/16"
	patience_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(patience_label)
	patience_label.owner = root

	# ABOVE THEIR HEADS. What they are asking for, and how long you have - the
	# only thing on this card that is a countdown, so it gets the alert role and
	# a reserved height, because a row that appears and disappears would shove
	# everything below it up and down the card every few ticks.
	var demand_label := _label("DemandLabel", 38, Palette.color(&"alert"))
	demand_label.text = "BETTER QUOTE  3t"   # longest telegraph in data/demands/*.tres
	demand_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	demand_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	demand_label.custom_minimum_size = Vector2(0, 52)
	col.add_child(demand_label)
	demand_label.owner = root

	var grid := Control.new()
	grid.name = "InterestGrid"
	grid.set_script(load("res://scripts/view/interest_grid.gd"))
	# An EXPLICIT box, not a stretch. A bare Control has no intrinsic width, so
	# left to size_flags it reports 0 until the container next resorts - and
	# container resorts are deferred, which makes "how wide is the grid" a
	# question with two answers depending on when you ask. 420 of the 448 the
	# padding leaves, with the cell arithmetic falling out of it: 3 cells of
	# 130 and two 14 px gaps.
	#
	# 224 tall, not 250: at 250 the column wanted 673 px of the 648 the face
	# has and ran its status line off the bottom. Cells come out wider than
	# they are tall, which is fine - they are labelled boxes, not squares.
	grid.custom_minimum_size = Vector2(420, 224)
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(grid)
	grid.owner = root

	var status_label := _label("StatusLabel", 26, Palette.color(&"margin"))
	# The longest product on the table plus a realistic two-product unsigned
	# total, not a generic hint string - status_text() joins both lines when
	# both are true at once, which is the actual worst case to check against.
	status_label.text = "on the table: Anti-Theft & Key Protection\n$1,700 unsigned"
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(status_label)
	status_label.owner = root

	# What they just SAID, not just what they are asking for - "all customer
	# actions need to show on the screen, not just in the log". Covers the
	# name row and stops right where the archetype row starts: PAD (26) down
	# to NameLabel's own 116 px plus the column's 12 px separation, all in
	# ROOT coordinates since this sits outside Margin. Added last, so it
	# draws over Name/Archetype rather than beside them - a customer saying
	# something is the most urgent thing on their own card, more than their
	# name is once you already know who they are.
	var bubble := Control.new()
	bubble.name = "SpeechBubble"
	bubble.set_script(load("res://scripts/view/speech_bubble.gd"))
	bubble.position = Vector2.ZERO
	bubble.size = Vector2(W, PAD + 116 + 12)
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.visible = false
	root.add_child(bubble)
	bubble.owner = root

	var bubble_panel := PanelContainer.new()
	bubble_panel.name = "Panel"
	bubble_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	bubble_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bubble_style := StyleBoxFlat.new()
	bubble_style.bg_color = Palette.color(&"panel_hi")
	bubble_style.border_width_bottom = 3
	bubble_style.border_color = Palette.color(&"action")
	bubble_style.content_margin_left = PAD
	bubble_style.content_margin_right = PAD
	bubble_style.content_margin_top = 18
	bubble_style.content_margin_bottom = 18
	bubble_panel.add_theme_stylebox_override("panel", bubble_style)
	bubble.add_child(bubble_panel)
	bubble_panel.owner = root

	var bubble_label := Label.new()
	bubble_label.name = "Label"
	bubble_label.add_theme_font_size_override("font_size", 32)
	bubble_label.add_theme_color_override("font_color", Palette.color(&"text"))
	bubble_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	bubble_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bubble_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bubble_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The longest dialogue line in data/demands/*.tres, so this scene shows
	# its own worst case in the editor - the same discipline every other
	# label on this card already follows.
	bubble_label.text = "\"The place on Dundas does this for less.\""
	bubble_panel.add_child(bubble_label)
	bubble_label.owner = root

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
