extends SceneTree
## Builds res://scenes/cards/card_front_2d.tscn - the face of a card, authored
## as ordinary 2D UI at 500x700 and rendered to a texture by card_face_3d.tscn.
##
## This is the approach Card3D's own example_battle uses, and the reason it is
## legible: the face is drawn at 500x700 with 40-70px type and then MINIFIED
## onto a card roughly 100px wide on screen. Label3D text sized in world units
## goes the other way - it is drawn at its final size and has nothing in hand
## when it lands on a small card.
##
## 500x700 is exactly the 2.5 x 3.5 aspect of card_3d.tscn's PlaneMesh, so
## nothing stretches.

const W := 500
const H := 700
const PAD := 24
## A card's picture, when it has one: as wide as the text, this tall.
const ART_H := 170
## The clock in the top right corner that shows the tick cost.
const CLOCK := 72
## The room between the grey rules and what they frame.
const RULE_GAP := 8

func _init() -> void:
	var root := Control.new()
	root.name = "CardFront"
	root.set_script(load("res://scripts/view/card_front.gd"))
	root.custom_minimum_size = Vector2(W, H)
	root.size = Vector2(W, H)

	var bg := ColorRect.new()
	bg.name = "Background"
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Palette.color(&"panel")
	root.add_child(bg)
	bg.owner = root

	# A hairline inset so a card reads as an object with an edge rather than a
	# floating rectangle of text.
	var inset := ColorRect.new()
	inset.name = "Inset"
	inset.set_anchors_preset(Control.PRESET_FULL_RECT)
	inset.offset_left = 10
	inset.offset_top = 10
	inset.offset_right = -10
	inset.offset_bottom = -10
	inset.color = Palette.color(&"panel_hi")
	root.add_child(inset)
	inset.owner = root

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, PAD)
	root.add_child(margin)
	margin.owner = root

	var col := VBoxContainer.new()
	col.name = "Column"
	col.add_theme_constant_override("separation", 8)
	margin.add_child(col)
	col.owner = root

	# A small type badge beside the word itself, above the name - the same
	# CardTypeIcon glyphs the card back draws from too (though the back always
	# shows the car, regardless of type - see CardBack2D), so what kind of
	# card this is is the very first thing read, before the name competes
	# for attention.
	var kind_row := HBoxContainer.new()
	kind_row.name = "KindRow"
	kind_row.add_theme_constant_override("separation", 10)
	col.add_child(kind_row)
	kind_row.owner = root

	var kind_icon := Control.new()
	kind_icon.name = "KindIcon"
	kind_icon.set_script(load("res://scripts/view/card_type_icon_control.gd"))
	kind_icon.custom_minimum_size = Vector2(34, 34)
	kind_row.add_child(kind_icon)
	kind_icon.owner = root

	var kind := _label("KindLabel", 33, Palette.color(&"accent"))
	kind.text = "PRODUCT"
	kind_row.add_child(kind)
	kind.owner = root

	var header := HBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", 12)
	col.add_child(header)
	header.owner = root

	# Placeholder text throughout is the longest string CardText can actually
	# produce for the real card pool (data/card_pool.tres), not a generic
	# filler word - so opening this scene in the editor already shows whether
	# a layout change survives the worst real card, not just a short one.
	var name_label := _label("NameLabel", 53, Palette.color(&"text"))
	name_label.text = "Anti-Theft & Key Protection"   # longest CardText.title()
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	header.add_child(name_label)
	name_label.owner = root
	# The tick cost as words - kept for what reads it, but the clock shows it.
	var ticks := _label("TicksLabel", 44, Palette.color(&"text_dim"))
	ticks.text = "3t"
	ticks.visible = false
	header.add_child(ticks)
	ticks.owner = root

	# The card's picture (CardDef.art), when it has one: clipped to rounded
	# corners, with a thin dark frame over it. Hidden on a card without one.
	var art := Panel.new()
	art.name = "Art"
	art.custom_minimum_size = Vector2(W - PAD * 2, ART_H)
	art.add_theme_stylebox_override("panel", _rounded(Palette.color(&"paper_shade")))
	art.visible = false
	col.add_child(art)
	art.owner = root
	var clip := Panel.new()
	clip.name = "Clip"
	clip.set_anchors_preset(Control.PRESET_FULL_RECT)
	clip.add_theme_stylebox_override("panel", _rounded(Palette.color(&"paper_shade")))
	clip.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	art.add_child(clip)
	clip.owner = root
	var picture := TextureRect.new()
	picture.name = "Picture"
	picture.set_anchors_preset(Control.PRESET_FULL_RECT)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	clip.add_child(picture)
	picture.owner = root
	var edge := _rounded(Palette.color(&"neutral_1"))
	edge.draw_center = false
	edge.set_border_width_all(6)
	var art_frame := Panel.new()
	art_frame.name = "Frame"
	art_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	art_frame.add_theme_stylebox_override("panel", edge)
	art.add_child(art_frame)
	art_frame.owner = root

	var rule := ColorRect.new()
	rule.name = "Rule"
	rule.custom_minimum_size = Vector2(0, 3)
	rule.color = Palette.color(&"neutral_2")
	col.add_child(rule)
	rule.owner = root
	_gap(col, root, "RuleGap", RULE_GAP)

	# A support card's effect; a product's category, its flag on the same line.
	# Side by side: CategoryIcon draws its glyph to whatever rect it is handed, so
	# SIZE_SHRINK_CENTER holds it to its own square custom_minimum_size.
	var body_row := HBoxContainer.new()
	body_row.name = "BodyRow"
	body_row.add_theme_constant_override("separation", 10)
	body_row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(body_row)
	body_row.owner = root

	var body_icon := Control.new()
	body_icon.name = "BodyIcon"
	body_icon.set_script(load("res://scripts/view/category_icon_control.gd"))
	body_icon.custom_minimum_size = Vector2(40, 40)
	body_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	body_icon.visible = false
	body_row.add_child(body_icon)
	body_icon.owner = root

	var body := _label("BodyLabel", 46, Palette.color(&"text"))
	body.text = "reveals their Line and the category of their number one"   # longest CardText.body()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_row.add_child(body)
	body.owner = root

	# What a product does beyond its price - WALKAWAY's "-2 Line" - as big as a
	# support card's effect. Hidden when there is nothing (see CardFront).
	var flavor := _label("FlavorLabel", 44, Palette.color(&"text"))
	flavor.text = "-2 Line for everyone"   # longest CardText.flavor()
	flavor.autowrap_mode = TextServer.AUTOWRAP_WORD
	flavor.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(flavor)
	flavor.owner = root

	_gap(col, root, "EffectGap", RULE_GAP)
	var flavor_rule := ColorRect.new()
	flavor_rule.name = "FlavorRule"
	flavor_rule.custom_minimum_size = Vector2(0, 3)
	flavor_rule.color = Palette.color(&"neutral_2")
	col.add_child(flavor_rule)
	flavor_rule.owner = root

	# Whatever a short card leaves, so the price sits at the bottom on every card.
	var rest := Control.new()
	rest.name = "Rest"
	rest.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(rest)
	rest.owner = root

	var money := _label("MarginLabel", 62, Palette.color(&"margin"))
	money.text = "$1,600"   # longest CardText.margin()
	money.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(money)
	money.owner = root

	# The tick cost, on a little stopwatch in the top right corner.
	var clock := Control.new()
	clock.name = "TickClock"
	clock.set_script(load("res://scripts/view/tick_clock.gd"))
	clock.position = Vector2(W - PAD - CLOCK, 18)
	clock.size = Vector2(CLOCK, CLOCK)
	clock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(clock)
	clock.owner = root

	var packed := PackedScene.new()
	packed.pack(root)
	var err := ResourceSaver.save(packed, "res://scenes/cards/card_front_2d.tscn")
	if err != OK:
		push_error("failed to save card_front_2d.tscn: %d" % err)
		quit(1)
		return
	print("saved card_front_2d.tscn")
	root.free()
	quit(0)

func _gap(parent: Node, root: Node, node_name: String, height: int) -> void:
	var g := Control.new()
	g.name = node_name
	g.custom_minimum_size = Vector2(0, height)
	parent.add_child(g)
	g.owner = root

func _rounded(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = color
	s.set_corner_radius_all(12)
	return s

func _label(node_name: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.name = node_name
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	# A shadow is what keeps type readable once this 500x700 face is minified
	# onto a card about a fifth that size; example_battle does the same. On
	# paper it is a faint shadow in ink rather than a hard black one: black
	# under dark ink reads as a smudge, while the same ink at low alpha just
	# thickens every stroke, which is what stops thin type thinning to grey.
	l.add_theme_color_override("font_shadow_color", Color(Palette.color(&"ink"), 0.25))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	return l
