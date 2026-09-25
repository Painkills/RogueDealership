extends SceneTree
## Builds res://scenes/cards/customer_front_2d.tscn - the face of a CUSTOMER
## card, drawn as 2D UI at 500x700 and rendered to a texture by the card.
##
## A CUSTOMER FILE. The card is a manila folder: its tab says what kind of
## buyer this is, and the sheet inside is their profile - a clipped-on photo
## beside their name, then everything you need to triage them. Everything
## else in the office is paper, and a customer is the one piece of paper you
## would actually keep in a folder.
##
## Everything you need to TRIAGE, and nothing you need to negotiate. Since the
## carousel, this face is on screen for all three customers all the time - two
## of them at 179 px wide - so it has to answer "who deserves the next tick"
## on its own, at that size, without anybody sitting down.
##
## THE PHOTO IS SMALL ON PURPOSE. The old portrait box was 268 of 700 px - 38%
## of the card - holding a grey rectangle reserved for art that does not exist,
## and the interest grid needed that room far more. The photo now sits BESIDE
## the name, in a row the name already took up, so it costs the grid nothing.

const W := 500
const H := 700
## The folder's tab, which the archetype is written on.
const TAB_H := 50
## The sheet of paper inside the folder, this far in from its edges.
const SHEET_INSET := 14
const MARGIN_X := 28
const MARGIN_TOP := TAB_H + 24
const MARGIN_BOTTOM := 24
## The photo and the name beside it. The speech bubble covers exactly this row
## - see drive_shift.gd's own restatement of this arithmetic.
const HEADER_H := 126
const PHOTO := 118
const SEP := 10

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
	tab.position = Vector2(20, 6)
	tab.size = Vector2(340, TAB_H - 6 + 2)
	var tab_style := StyleBoxFlat.new()
	tab_style.bg_color = Palette.color(&"manila")
	tab_style.corner_radius_top_left = 16
	tab_style.corner_radius_top_right = 16
	tab.add_theme_stylebox_override("panel", tab_style)
	root.add_child(tab)
	tab.owner = root

	# Placeholder text below is the longest string the real data can actually
	# produce (data/archetype_pool.tres names/archetypes, data/demands/*.tres
	# telegraphs, data/card_pool.tres product names) rather than a generic
	# filler word, so this scene shows its own worst case in the editor.
	var arch_label := _label("ArchetypeLabel", 28, Palette.color(&"text"))
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
	paper.bg_color = Palette.color(&"panel_hi")
	paper.border_color = Palette.color(&"neutral_2")
	paper.set_border_width_all(2)
	paper.shadow_color = Color(0, 0, 0, 0.18)
	paper.shadow_size = 4
	paper.shadow_offset = Vector2(2, 3)
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

	var header := HBoxContainer.new()
	header.name = "Header"
	header.custom_minimum_size = Vector2(0, HEADER_H)
	header.add_theme_constant_override("separation", 14)
	col.add_child(header)
	header.owner = root

	var photo := Control.new()
	photo.name = "Photo"
	photo.set_script(load("res://scripts/view/photo_frame.gd"))
	photo.custom_minimum_size = Vector2(PHOTO, PHOTO)
	photo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(photo)
	photo.owner = root

	var name_label := _label("NameLabel", 44, Palette.color(&"text"))
	name_label.text = "Sandra Okonkwo"   # longest name in archetype_pool.tres
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(name_label)
	name_label.owner = root

	var patience_bar := ProgressBar.new()
	patience_bar.name = "PatienceBar"
	patience_bar.min_value = 0
	patience_bar.max_value = 16
	patience_bar.value = 12
	patience_bar.show_percentage = false
	patience_bar.custom_minimum_size = Vector2(0, 28)
	col.add_child(patience_bar)
	patience_bar.owner = root

	var patience_label := _label("PatienceLabel", 26, Palette.color(&"text"))
	patience_label.text = "patience 16/16"
	patience_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(patience_label)
	patience_label.owner = root

	# ABOVE THEIR HEADS. What they are asking for, and how long you have - the
	# only thing on this card that is a countdown, so it gets the alert role and
	# a reserved height, because a row that appears and disappears would shove
	# everything below it up and down the card every few ticks.
	var demand_label := _label("DemandLabel", 36, Palette.color(&"alert"))
	demand_label.text = "BETTER QUOTE  3t"   # longest telegraph in data/demands/*.tres
	demand_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	demand_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	demand_label.custom_minimum_size = Vector2(0, 50)
	col.add_child(demand_label)
	demand_label.owner = root

	var grid := Control.new()
	grid.name = "InterestGrid"
	grid.set_script(load("res://scripts/view/interest_grid.gd"))
	# An EXPLICIT box, not a stretch. A bare Control has no intrinsic width, so
	# left to size_flags it reports 0 until the container next resorts - and
	# container resorts are deferred, which makes "how wide is the grid" a
	# question with two answers depending on when you ask. 420 of the 444 the
	# sheet's margins leave, with the cell arithmetic falling out of it.
	#
	# 210 tall, and EXPAND_FILL takes whatever the column has left over. The
	# folder's tab and the sheet's own margins cost the column some height, so
	# this is the row that gives: every other row is text that must not clip.
	grid.custom_minimum_size = Vector2(420, 210)
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
	# photo-and-name row and stops right where the patience bar starts, in ROOT
	# coordinates since this sits outside Margin: from the top of the folder's
	# front flap down to MARGIN_TOP + HEADER_H + SEP. The tab above it stays
	# uncovered, so you can still see WHO is talking. Added last, so it draws
	# over the header rather than beside it - a customer saying something is
	# the most urgent thing on their own card, more than their name is once you
	# already know who they are.
	var bubble := Control.new()
	bubble.name = "SpeechBubble"
	bubble.set_script(load("res://scripts/view/speech_bubble.gd"))
	bubble.position = Vector2(0, TAB_H)
	bubble.size = Vector2(W, MARGIN_TOP - TAB_H + HEADER_H + SEP)
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
	bubble_style.content_margin_left = MARGIN_X
	bubble_style.content_margin_right = MARGIN_X
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
	# A faint ink shadow, not a hard black one - see build_card_front_scene.gd.
	l.add_theme_color_override("font_shadow_color", Color(Palette.color(&"ink"), 0.25))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	return l
