extends SceneTree
## Builds res://scenes/cards/detail_front_2d.tscn - the face of a DETAIL card.
##
## A detail card is the second card of a pair: it sits flush behind the thing it
## describes, facing the other way, so the two read as one card with a front and
## a back. There are two per seat and they show different things, but they share
## one face scene with two mutually exclusive body blocks, for the same reason
## the customer face used to carry its own two states: one scene cannot drift
## from itself.
##
##   CustomerBody - what they do, what is unsigned, what you have worked out
##   OfferBody    - the product, its margin, and the appeal meter
##
## 500x700 on a 2.5 x 3.5 quad, exactly like every other card. It was briefly
## wider, which broke the illusion the moment the pair flipped: a back that is
## not the same size as its front is not a back.

const W := 500
const H := 700
const PAD := 24

func _init() -> void:
	var root := Control.new()
	root.name = "DetailFront"
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
	col.add_theme_constant_override("separation", 8)
	margin.add_child(col)
	col.owner = root

	# --- header, shared by both bodies -----------------------------------
	var title := _label("TitleLabel", 40, Palette.color(&"text"))
	title.text = "Detail Card"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD
	col.add_child(title)
	title.owner = root

	var sub := _label("SubLabel", 27, Palette.color(&"accent"))
	sub.text = "subtitle"
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD
	col.add_child(sub)
	sub.owner = root

	var rule := ColorRect.new()
	rule.name = "Rule"
	rule.custom_minimum_size = Vector2(0, 3)
	rule.color = Palette.color(&"neutral_2")
	col.add_child(rule)
	rule.owner = root

	# --- theirs ----------------------------------------------------------
	var who := VBoxContainer.new()
	who.name = "CustomerBody"
	who.add_theme_constant_override("separation", 2)
	col.add_child(who)
	who.owner = root

	_section(who, root, "DoesTitle", "WHAT THEY DO",
		"DoesLabel", "(their behaviours show here)", &"text")
	_section(who, root, "TableTitle", "UNSIGNED",
		"TableLabel", "(what they have agreed to shows here)", &"margin")
	_section(who, root, "KnownTitle", "WHAT YOU KNOW",
		"KnownLabel", "(what you have worked out shows here)", &"text_dim")

	# --- the product in front of them ------------------------------------
	var what := VBoxContainer.new()
	what.name = "OfferBody"
	what.visible = false
	what.add_theme_constant_override("separation", 4)
	col.add_child(what)
	what.owner = root

	var margin_title := _label("MarginTitle", 22, Palette.color(&"text_dim"))
	margin_title.text = "MARGIN"
	what.add_child(margin_title)
	margin_title.owner = root

	var margin_label := _label("MarginLabel", 44, Palette.color(&"margin"))
	margin_label.text = "$1,600"
	what.add_child(margin_label)
	margin_label.owner = root

	var appeal_title := _label("AppealTitle", 22, Palette.color(&"text_dim"))
	appeal_title.text = "APPEAL"
	what.add_child(appeal_title)
	appeal_title.owner = root

	# Fill is how much appeal this offer carries, colour is how that compares
	# with their Line, and the marker only appears once you have earned the Line.
	var bar := Control.new()
	bar.name = "AppealBar"
	bar.custom_minimum_size = Vector2(0, 54)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.set_script(load("res://scripts/view/appeal_bar.gd"))
	what.add_child(bar)
	bar.owner = root

	var status := _label("StatusLabel", 32, Palette.color(&"text"))
	status.text = "12 SHORT"
	what.add_child(status)
	status.owner = root

	var hint := _label("HintLabel", 22, Palette.color(&"text_dim"))
	hint.text = "offer, or read the room, to learn their Line"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	what.add_child(hint)
	hint.owner = root

	var packed := PackedScene.new()
	packed.pack(root)
	var err := ResourceSaver.save(packed, "res://scenes/cards/detail_front_2d.tscn")
	if err != OK:
		push_error("failed to save detail_front_2d.tscn: %d" % err)
		quit(1)
		return
	print("saved detail_front_2d.tscn")
	root.free()
	quit(0)

func _section(parent: Node, root: Node, title_name: String, title_text: String,
		body_name: String, body_text: String, body_role: StringName) -> void:
	var t := _label(title_name, 22, Palette.color(&"text_dim"))
	t.text = title_text
	parent.add_child(t)
	t.owner = root

	var b := _label(body_name, 28, Palette.color(body_role))
	b.text = body_text
	b.autowrap_mode = TextServer.AUTOWRAP_WORD
	parent.add_child(b)
	b.owner = root

func _label(node_name: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.name = node_name
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("shadow_offset_x", 3)
	l.add_theme_constant_override("shadow_offset_y", 3)
	return l
