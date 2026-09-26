extends SceneTree
## Builds res://scenes/cards/detail_front_2d.tscn - the face of the BACK of a
## customer's folder: what their kind of buyer does to you, and what they have
## agreed to but not yet signed.
##
## It sits flush behind the folder, facing the other way, so the two read as
## one folder with a front and a back - and it LOOKS like the back of one: the
## same manila cover and tab, with their name on the tab, and a sheet of paper
## taped to the cover. The tab stays in the front's corner rather than turning
## to the other: the other corner is where CLOSE SOON hangs, over either side. The sheet's headings are stickers stuck on it
## rather than printed rules, the way a file that gets handled gets labelled.
##
## Laid out at the folder's own 800x700 (see DetailCard3D.face_size). What you
## have worked out about their priorities used to have a section here too; the
## interest grid on the front says all of it.

const W := 800
const H := 700
## The folder's tab, as on the front (build_customer_front_scene.gd).
const TAB_H := 52
const TAB_W := 400
const TAB_INSET := 24
## The sheet taped to the cover, this far in from its edges.
const SHEET_INSET := 26
const PAD := 30
## The row a sticker heading takes: its 26 px words and their padding, and a
## little room for the tilt.
const STICKER_H := 50

func _init() -> void:
	var root := Control.new()
	root.name = "DetailFront"
	root.custom_minimum_size = Vector2(W, H)
	root.size = Vector2(W, H)

	# The folder's back cover, the whole face, with its tab standing up out of
	# it - the area either side of the tab is the table showing past it, the
	# same darker tone the front shows there.
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Palette.color(&"manila_back")
	root.add_child(bg)
	bg.owner = root

	var cover := ColorRect.new()
	cover.name = "Cover"
	cover.position = Vector2(0, TAB_H)
	cover.size = Vector2(W, H - TAB_H)
	cover.color = Palette.color(&"manila")
	root.add_child(cover)
	cover.owner = root

	var tab := Panel.new()
	tab.name = "Tab"
	tab.position = Vector2(TAB_INSET, 6)
	tab.size = Vector2(TAB_W, TAB_H - 6 + 2)
	var tab_style := StyleBoxFlat.new()
	tab_style.bg_color = Palette.color(&"manila")
	tab_style.corner_radius_top_left = 14
	tab_style.corner_radius_top_right = 14
	tab.add_theme_stylebox_override("panel", tab_style)
	root.add_child(tab)
	tab.owner = root

	# Their name on the tab, the way a file is labelled.
	var title := _label("TitleLabel", 32, Palette.color(&"text"), true)
	title.text = "Sandra Okonkwo"   # the longest name in archetype_pool.tres
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.clip_text = true
	tab.add_child(title)
	title.owner = root

	# The sheet, taped to the cover at its two top corners.
	var sheet := Panel.new()
	sheet.name = "Sheet"
	sheet.position = Vector2(SHEET_INSET, TAB_H + SHEET_INSET - 8)
	sheet.size = Vector2(W - SHEET_INSET * 2, H - TAB_H - SHEET_INSET * 2 + 8)
	var paper := StyleBoxFlat.new()
	paper.bg_color = Palette.color(&"panel")
	paper.set_corner_radius_all(6)
	paper.shadow_color = Color(0, 0, 0, 0.14)
	paper.shadow_size = 6
	paper.shadow_offset = Vector2(0, 3)
	sheet.add_theme_stylebox_override("panel", paper)
	root.add_child(sheet)
	sheet.owner = root
	for spec in [["TapeLeft", sheet.position + Vector2(-22, -10), -14.0],
			["TapeRight", sheet.position + Vector2(sheet.size.x - 70, -14), 12.0]]:
		var tape := Panel.new()
		tape.name = spec[0]
		tape.position = spec[1]
		tape.size = Vector2(96, 30)
		tape.rotation_degrees = spec[2]
		var strip := StyleBoxFlat.new()
		strip.bg_color = Color(1.0, 0.98, 0.9, 0.7)
		tape.add_theme_stylebox_override("panel", strip)
		root.add_child(tape)
		tape.owner = root

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.position = sheet.position
	margin.size = sheet.size
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, PAD)
	root.add_child(margin)
	margin.owner = root

	var col := VBoxContainer.new()
	col.name = "Column"
	col.add_theme_constant_override("separation", 10)
	margin.add_child(col)
	col.owner = root

	var sub := _label("SubLabel", 32, Palette.color(&"accent"), true)
	sub.text = "Tech Enthusiast"   # the longest archetype name
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD
	col.add_child(sub)
	sub.owner = root

	# --- theirs ----------------------------------------------------------
	var who := VBoxContainer.new()
	who.name = "CustomerBody"
	who.add_theme_constant_override("separation", 8)
	col.add_child(who)
	who.owner = root

	# Placeholder bodies are each the actual worst case behaviour_text() /
	# unsigned_text() can produce against the real data (data/archetypes/*.tres,
	# data/products/*.tres) - see tools/drive_shift.gd's own wordiest-customer
	# overflow check, which this same worst case has to survive.
	_section(who, root, "DoesTitle", "WHAT THEY DO", &"sticky", &"ink", -1.5,
		"DoesLabel", "WILL NOT SIGN until they have bought something in Reliability.\n" +
			"Needs a minute to talk it over - every 6 ticks. Work someone else for 3 and they come back easier, or lose 5 patience",
		&"text")
	_section(who, root, "TableTitle", "UNSIGNED", &"money", &"paper", 1.2,
		"TableLabel", "Anti-Theft & Key Protection $800\nAppearance & Wheel Package $900\n($1,700 at risk)",
		&"margin")

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

## A heading stuck on as a sticker - a rounded label in `fill`, tilted a touch
## the way a hand puts one on - and the text it heads under it.
##
## The sticker sits in a plain Control that holds its row in the column: a
## container resets the rotation of anything it lays out, so a tilted child of
## the column itself would be laid out straight again. Inside a plain Control
## it keeps its tilt, and sizes itself to its words.
func _section(parent: Node, root: Node, title_name: String, title_text: String,
		fill: StringName, ink: StringName, tilt: float, body_name: String,
		body_text: String, body_role: StringName) -> void:
	var spot := Control.new()
	spot.name = title_name
	spot.custom_minimum_size = Vector2(0, STICKER_H)
	parent.add_child(spot)
	spot.owner = root
	var sticker := PanelContainer.new()
	sticker.name = "Sticker"
	sticker.position = Vector2(4, 2)
	sticker.rotation_degrees = tilt
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.color(fill)
	style.set_corner_radius_all(7)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	style.shadow_color = Color(0, 0, 0, 0.18)
	style.shadow_size = 3
	style.shadow_offset = Vector2(1, 2)
	sticker.add_theme_stylebox_override("panel", style)
	spot.add_child(sticker)
	sticker.owner = root
	var words := _label("Words", 26, Palette.color(ink), true)
	words.text = title_text
	sticker.add_child(words)
	words.owner = root

	var b := _label(body_name, 30, Palette.color(body_role))
	b.text = body_text
	b.autowrap_mode = TextServer.AUTOWRAP_WORD
	parent.add_child(b)
	b.owner = root

func _label(node_name: String, size: int, color: Color, heading: bool = false) -> Label:
	var l := Label.new()
	l.name = node_name
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if heading:
		l.theme_type_variation = &"Heading"
	return l
