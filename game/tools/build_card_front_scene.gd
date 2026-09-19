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
const PAD := 34

func _init() -> void:
	var root := Control.new()
	root.name = "CardFront"
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
	col.add_theme_constant_override("separation", 14)
	margin.add_child(col)
	col.owner = root

	# A small type badge beside the word itself, above the name - the SAME
	# car/wrench glyph the card back uses (though the back no longer varies
	# by type - see CardBack2D), so what kind of card this is is the very
	# first thing read, before the name competes for attention.
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

	var kind := _label("KindLabel", 30, Palette.color(&"accent"))
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
	var name_label := _label("NameLabel", 46, Palette.color(&"text"))
	name_label.text = "Anti-Theft & Key Protection"   # longest CardText.title()
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_label.custom_minimum_size = Vector2(0, 130)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	header.add_child(name_label)
	name_label.owner = root

	var cost := _label("CostLabel", 40, Palette.color(&"text_dim"))
	cost.text = "3t"
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(cost)
	cost.owner = root

	var rule := ColorRect.new()
	rule.name = "Rule"
	rule.custom_minimum_size = Vector2(0, 3)
	rule.color = Palette.color(&"neutral_2")
	col.add_child(rule)
	rule.owner = root

	# The icon only means something for a PRODUCT, whose body line IS a
	# category - a support card's body is its effects' own describe() text, and
	# has no category to show. So the icon is a sibling the running script
	# shows or hides per card, not something baked into every card alike.
	#
	# Stacked - badge above caption - not side by side: a VBoxContainer
	# stretches a child's WIDTH to fill it by default, and CategoryIcon.draw()
	# scales its glyph to whatever rect.size it is handed with no aspect
	# correction, so a non-square icon draws visibly distorted.
	# SIZE_SHRINK_CENTER holds it to its own square custom_minimum_size.
	var body_row := VBoxContainer.new()
	body_row.name = "BodyRow"
	body_row.add_theme_constant_override("separation", 10)
	body_row.alignment = BoxContainer.ALIGNMENT_CENTER
	body_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body_row)
	body_row.owner = root

	var body_icon := Control.new()
	body_icon.name = "BodyIcon"
	body_icon.set_script(load("res://scripts/view/category_icon_control.gd"))
	body_icon.custom_minimum_size = Vector2(80, 80)
	body_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	body_icon.visible = false
	body_row.add_child(body_icon)
	body_icon.owner = root

	var body := _label("BodyLabel", 38, Palette.color(&"text"))
	body.text = "reveals their Line and the category of their number one"   # longest CardText.body()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_row.add_child(body)
	body.owner = root

	var money := _label("MarginLabel", 68, Palette.color(&"margin"))
	money.text = "$1,600"   # longest CardText.margin()
	money.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(money)
	money.owner = root

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

func _label(node_name: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.name = node_name
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	# A hard shadow is what keeps type readable once this 500x700 face is
	# minified onto a card about a fifth that size; example_battle does the same.
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("shadow_offset_x", 3)
	l.add_theme_constant_override("shadow_offset_y", 3)
	return l
