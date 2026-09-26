extends SceneTree
## Builds res://scenes/cards/customer_front_2d.tscn - the face of a CUSTOMER
## card, drawn as 2D UI and rendered to a texture by the card.
##
## A CUSTOMER FILE, landscape like a real file folder: the tab says what kind of
## buyer this is, and the sheet inside is their profile - their photo, their
## name and their patience across the top, then what they are asking for, their
## list of interests, and what is riding on them.
##
## Wider than every other card on purpose (see CustomerCard3D.CARD_SIZE). It
## started as a 500x700 portrait card like the products, and the interest grid
## - the one thing on this face you actually have to READ - got cells 97 px
## wide, with "Value Retention" shrunk to fit them. At 800 px the grid runs the
## full width of the sheet and every cell is twice as wide.
##
## Everything you need to TRIAGE, and nothing you need to negotiate. Since the
## carousel this face is on screen for all three customers all the time, two of
## them small, so it has to answer "who deserves the next tick" on its own,
## without anybody sitting down.

const W := 800
const H := 700
## The folder's tab, which the archetype is written on.
const TAB_H := 52
## The sheet of paper inside the folder, this far in from its edges.
const SHEET_INSET := 16
const MARGIN_X := 36
const MARGIN_TOP := TAB_H + 28
const MARGIN_BOTTOM := 28
## Photo, name and patience - which nothing is ever drawn over, the speech
## bubble included (see GRID_TOP).
const HEADER_H := 160
const PHOTO := 150
const SEP := 10
## The demand countdown's reserved row, under the name and patience: at least
## one line of its 36 px heading face (54 px), so the row never grows past what
## the speech bubble below it is placed against.
const DEMAND_H := 56
## Where the interest grid starts, and so where a speech bubble may start: below
## the name, the patience and the countdown. See drive_shift.gd's own
## restatement of this arithmetic.
const GRID_TOP := MARGIN_TOP + HEADER_H + SEP + DEMAND_H + SEP

func _init() -> void:
	var root := Control.new()
	root.name = "CustomerFront"
	root.custom_minimum_size = Vector2(W, H)
	root.size = Vector2(W, H)

	# The folder's BACK flap, which is all that shows above the front flap
	# either side of the tab - darker, so the tab reads as sticking up out of
	# the folder rather than as a notch cut into the card.
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Palette.color(&"manila_back")
	root.add_child(bg)
	bg.owner = root

	var front := ColorRect.new()
	front.name = "FrontFlap"
	front.position = Vector2(0, TAB_H)
	front.size = Vector2(W, H - TAB_H)
	front.color = Palette.color(&"manila")
	root.add_child(front)
	front.owner = root

	var tab := Panel.new()
	tab.name = "Tab"
	tab.position = Vector2(24, 6)
	tab.size = Vector2(400, TAB_H - 6 + 2)
	var tab_style := StyleBoxFlat.new()
	tab_style.bg_color = Palette.color(&"manila")
	tab_style.corner_radius_top_left = 14
	tab_style.corner_radius_top_right = 14
	tab.add_theme_stylebox_override("panel", tab_style)
	root.add_child(tab)
	tab.owner = root

	# Placeholder text below is the longest string the real data can actually
	# produce (data/archetype_pool.tres names/archetypes, data/demands/*.tres
	# telegraphs, data/card_pool.tres product names) rather than a generic
	# filler word, so this scene shows its own worst case in the editor.
	var arch_label := _label("ArchetypeLabel", 30, Palette.color(&"text"))
	arch_label.theme_type_variation = &"Heading"
	arch_label.text = "Tech Enthusiast  [C]"   # longest archetype display_name + chair key
	arch_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	arch_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arch_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tab.add_child(arch_label)
	arch_label.owner = root

	var sheet := Panel.new()
	sheet.name = "Sheet"
	sheet.position = Vector2(SHEET_INSET, TAB_H + SHEET_INSET - 4)
	sheet.size = Vector2(W - SHEET_INSET * 2, H - TAB_H - SHEET_INSET * 2 + 4)
	var paper := StyleBoxFlat.new()
	paper.bg_color = Palette.color(&"panel")
	paper.set_corner_radius_all(10)
	paper.shadow_color = Color(0, 0, 0, 0.12)
	paper.shadow_size = 6
	paper.shadow_offset = Vector2(0, 3)
	sheet.add_theme_stylebox_override("panel", paper)
	root.add_child(sheet)
	sheet.owner = root

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", MARGIN_X)
	margin.add_theme_constant_override("margin_right", MARGIN_X)
	margin.add_theme_constant_override("margin_top", MARGIN_TOP)
	margin.add_theme_constant_override("margin_bottom", MARGIN_BOTTOM)
	root.add_child(margin)
	margin.owner = root

	var col := VBoxContainer.new()
	col.name = "Column"
	col.add_theme_constant_override("separation", SEP)
	margin.add_child(col)
	col.owner = root

	# --- photo, name, patience --------------------------------------------
	var header := HBoxContainer.new()
	header.name = "Header"
	header.custom_minimum_size = Vector2(0, HEADER_H)
	header.add_theme_constant_override("separation", 22)
	col.add_child(header)
	header.owner = root

	var photo := Control.new()
	photo.name = "Photo"
	photo.set_script(load("res://scripts/view/photo_frame.gd"))
	photo.custom_minimum_size = Vector2(PHOTO, PHOTO)
	photo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(photo)
	photo.owner = root

	var info := VBoxContainer.new()
	info.name = "Info"
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 8)
	header.add_child(info)
	info.owner = root

	var name_label := _label("NameLabel", 50, Palette.color(&"text"))
	name_label.theme_type_variation = &"Heading"
	name_label.text = "Sandra Okonkwo"   # longest name in archetype_pool.tres
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	info.add_child(name_label)
	name_label.owner = root

	var patience_bar := ProgressBar.new()
	patience_bar.name = "PatienceBar"
	patience_bar.min_value = 0
	patience_bar.max_value = 16
	patience_bar.value = 12
	patience_bar.show_percentage = false
	patience_bar.custom_minimum_size = Vector2(0, 22)
	info.add_child(patience_bar)
	patience_bar.owner = root

	var patience_label := _label("PatienceLabel", 26, Palette.color(&"text_dim"))
	patience_label.text = "patience 16/16"
	info.add_child(patience_label)
	patience_label.owner = root

	# ABOVE THEIR HEADS. What they are asking for, and how long you have - the
	# only thing on this card that is a countdown, so it gets the alert role and
	# a reserved height, because a row that appears and disappears would shove
	# everything below it up and down the card every few ticks.
	var demand_label := _label("DemandLabel", 36, Palette.color(&"alert"))
	demand_label.theme_type_variation = &"Heading"
	demand_label.text = "BETTER QUOTE  3t"   # longest telegraph in data/demands/*.tres
	demand_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	demand_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	demand_label.custom_minimum_size = Vector2(0, DEMAND_H)
	col.add_child(demand_label)
	demand_label.owner = root

	var grid := Control.new()
	grid.name = "InterestGrid"
	grid.set_script(load("res://scripts/view/interest_grid.gd"))
	# An EXPLICIT box, not a stretch. A bare Control has no intrinsic width, so
	# left to size_flags it reports 0 until the container next resorts - and
	# container resorts are deferred, which makes "how wide is the grid" a
	# question with two answers depending on when you ask. The full width of
	# the sheet's content, and EXPAND_FILL takes whatever height is left: every
	# other row is text that must not clip, so this is the row that gives.
	grid.custom_minimum_size = Vector2(W - MARGIN_X * 2, 236)
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
	# actions need to show on the screen, not just in the log". Over their
	# INTEREST GRID, never their name or patience: those are what you glance at
	# to decide who needs you next, and a line of dialogue covering the patience
	# meter hid the one number that says how long you have. The countdown above
	# the grid stays uncovered too. Added last, so it draws over the grid, in
	# ROOT coordinates since it sits outside Margin; a tail points up at the
	# photo, so it still reads as that person talking.
	var bubble := Control.new()
	bubble.name = "SpeechBubble"
	bubble.set_script(load("res://scripts/view/speech_bubble.gd"))
	bubble.position = Vector2(MARGIN_X - 12, GRID_TOP - 6)
	bubble.size = Vector2(W - (MARGIN_X - 12) * 2, H - MARGIN_BOTTOM + 6 - (GRID_TOP - 6))
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.visible = false
	root.add_child(bubble)
	bubble.owner = root

	# The tail, under the photo: its outline behind the panel, and its white
	# fill in front, reaching just past the panel's border so the tail opens
	# into the bubble rather than being cut off from it by a line.
	var tail_x: float = PHOTO * 0.5 + 12   # the photo's centre, in the bubble's space
	_tail(bubble, root, "TailEdge", &"action",
		[Vector2(tail_x - 24, 2), Vector2(tail_x + 24, 2), Vector2(tail_x, -28)])

	var bubble_panel := PanelContainer.new()
	bubble_panel.name = "Panel"
	bubble_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	bubble_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bubble_style := StyleBoxFlat.new()
	bubble_style.bg_color = Palette.color(&"panel")
	bubble_style.set_border_width_all(4)
	bubble_style.border_color = Palette.color(&"action")
	bubble_style.set_corner_radius_all(18)
	bubble_style.content_margin_left = MARGIN_X
	bubble_style.content_margin_right = MARGIN_X
	bubble_style.content_margin_top = 18
	bubble_style.content_margin_bottom = 18
	bubble_style.shadow_color = Color(0, 0, 0, 0.15)
	bubble_style.shadow_size = 8
	bubble_style.shadow_offset = Vector2(0, 3)
	bubble_panel.add_theme_stylebox_override("panel", bubble_style)
	bubble.add_child(bubble_panel)
	bubble_panel.owner = root
	_tail(bubble, root, "Tail", &"panel",
		[Vector2(tail_x - 23, 8), Vector2(tail_x + 23, 8), Vector2(tail_x, -21)])

	var bubble_label := Label.new()
	bubble_label.name = "Label"
	bubble_label.add_theme_font_size_override("font_size", 38)
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

func _tail(bubble: Control, root: Node, node_name: String, role: StringName,
		points: Array) -> void:
	var tail := Polygon2D.new()
	tail.name = node_name
	tail.polygon = PackedVector2Array(points)
	tail.color = Palette.color(role)
	bubble.add_child(tail)
	tail.owner = root

func _label(node_name: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.name = node_name
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	# A faint shadow in the label's own ink - see build_card_front_scene.gd.
	l.add_theme_color_override("font_shadow_color", Color(Palette.color(&"ink"), 0.2))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	return l
