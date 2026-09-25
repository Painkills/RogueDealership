extends SceneTree
## Builds res://scenes/cards/detail_front_2d.tscn - the face of the BACK of a
## customer's folder: what they do, what is unsigned, what you have worked out.
##
## It sits flush behind the folder, facing the other way, so the two read as
## one folder with a front and a back. Laid out at 500x700 and stretched across
## the folder's wider face (see DetailCard3D.face_size), which only gives its
## lines more room.
##
## It used to carry a second body too, for the product slot's own detail card.
## That card is gone - the tablet the product stands on says how it is landing
## (see OfferTablet) - and so is the body.

const W := 500
const H := 700
const PAD := 12   ## trimmed from 16 alongside CustomerBody's own separation, see below

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
	col.add_theme_constant_override("separation", 6)
	margin.add_child(col)
	col.owner = root

	# --- header -------------------------------------------------------------
	# Small: its whole job is to say WHOSE folder this is, and the three sections
	# below need the room far more, especially the tells of an archetype with a
	# lot to say.
	var title := _label("TitleLabel", 34, Palette.color(&"text"))
	title.text = "Anti-Theft & Key Protection"   # a long line, well past any name
	title.autowrap_mode = TextServer.AUTOWRAP_WORD
	col.add_child(title)
	title.owner = root

	var sub := _label("SubLabel", 28, Palette.color(&"accent"))
	sub.text = "Tech Enthusiast"   # the longest archetype name
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
	# Trimmed from 8 once Karen's own tell grew a real sentence longer - three
	# sections' worth of gaps, so a few px back here is real headroom without
	# shrinking any section's own content.
	who.add_theme_constant_override("separation", 4)
	col.add_child(who)
	who.owner = root

	# Placeholder bodies are each the actual worst case behaviour_text() /
	# unsigned_text() / known_text() can produce against the real data
	# (data/archetypes/*.tres, data/products/*.tres, data/interests/*.tres) -
	# see tools/drive_shift.gd's own wordiest-customer overflow check, which
	# this same worst case has to survive.
	_section(who, root, "DoesTitle", "WHAT THEY DO",
		"DoesLabel", "WILL NOT SIGN until they have bought something in Reliability.\n" +
			"Needs a minute to talk it over - every 6 ticks. Work someone else for 3 and they come back easier, or lose 5 patience",
		&"text")
	_section(who, root, "TableTitle", "UNSIGNED",
		"TableLabel", "Anti-Theft & Key Protection $800\nAppearance & Wheel Package $900\n($1,700 at risk)",
		&"margin")
	_section(who, root, "KnownTitle", "WHAT YOU KNOW",
		"KnownLabel", "Their number one is a Vehicle need.",
		&"text_dim")

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
	var t := _label(title_name, 30, Palette.color(&"text_dim"))
	t.text = title_text
	parent.add_child(t)
	t.owner = root

	var b := _label(body_name, 30, Palette.color(body_role))
	b.text = body_text
	b.autowrap_mode = TextServer.AUTOWRAP_WORD
	parent.add_child(b)
	b.owner = root

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
