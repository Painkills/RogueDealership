extends SceneTree
## Builds res://scenes/offer_tablet.tscn - the tablet on the desk you are
## sitting at. See offer_tablet.gd for what it is for.
##
## The whole face - black edge, screen, and both side panels - is one 2D scene
## rendered into a SubViewport and shown on a single quad, the way every card
## face in the game is. Every rect comes from offer_tablet.gd's own constants,
## so the script that finds a panel on screen and the scene that draws it can
## never disagree about where it is.

const OUT := "res://scenes/offer_tablet.tscn"
## The black edge's outer corners, and the screen's own inside them.
const EDGE_RADIUS := 48
const SCREEN_RADIUS := 30
const PANEL_RADIUS := 22

func _init() -> void:
	var root := Node3D.new()
	root.name = "OfferTablet"
	root.set_script(load("res://scripts/view/offer_tablet.gd"))

	var vp := SubViewport.new()
	vp.name = "ScreenViewport"
	vp.size = OfferTablet.SIZE_PX
	vp.disable_3d = true
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(vp)
	vp.owner = root

	var w: int = OfferTablet.SIZE_PX.x
	var h: int = OfferTablet.SIZE_PX.y
	var screen := Control.new()
	screen.name = "TabletScreen"
	screen.custom_minimum_size = Vector2(w, h)
	screen.size = Vector2(w, h)
	vp.add_child(screen)
	screen.owner = root

	# The black glass edge, with a tablet's rounded corners; outside them the
	# viewport stays clear and the quad cuts them away.
	_box(screen, root, "Edge", Rect2(0, 0, w, h), _flat(&"tablet", EDGE_RADIUS))
	# The front camera, centred in the top edge.
	var lens := _flat(&"desk_frame", 5)
	lens.bg_color = Palette.color(&"tablet").lightened(0.16)
	_box(screen, root, "Lens", Rect2(w * 0.5 - 5, 4, 10, 10), lens)

	var b: int = OfferTablet.BEZEL_PX
	_box(screen, root, "Screen", Rect2(b, b, w - b * 2, h - b * 2),
		_flat(&"bg", SCREEN_RADIUS))

	# Where the product stands. The card itself is a real card in front of the
	# screen - you drag it on, and off again to offer or drop it - so all the
	# screen draws is the place it goes.
	var well := _flat(&"paper_shade", 16)
	well.set_border_width_all(3)
	well.border_color = Palette.color(&"neutral_3")
	_box(screen, root, "Well", Rect2(OfferTablet.WELL_RECT), well)

	# --- left: how it is landing -------------------------------------------
	var appeal := _panel(screen, root, "AppealPanel", OfferTablet.APPEAL_RECT)
	var col := _column(appeal, root, 14)
	_label(col, root, "AppealTitle", "APPEAL", 34, &"text_dim", true)
	# Fill is how much appeal this offer carries, colour is how that compares
	# with their Line, and the marker only appears once you have earned the Line.
	var bar := Control.new()
	bar.name = "AppealBar"
	bar.custom_minimum_size = Vector2(0, 64)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.set_script(load("res://scripts/view/appeal_bar.gd"))
	col.add_child(bar)
	bar.owner = root
	# Placeholders are the longest thing each can say.
	_label(col, root, "StatusLabel", "READY TO SIGN", 46, &"text", true)
	var hint := _label(col, root, "HintLabel",
		"their Line is marked - clear it before you offer", 30, &"text_dim")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD

	# --- right: what it is worth ---------------------------------------------
	var deal := _panel(screen, root, "DealPanel", OfferTablet.DEAL_RECT)
	col = _column(deal, root, 4)
	_label(col, root, "MarginTitle", "MARGIN", 34, &"text_dim", true)
	_label(col, root, "MarginLabel", "$1,600", 76, &"margin", true)
	var gap := Control.new()
	gap.name = "Gap"
	gap.custom_minimum_size = Vector2(0, 18)
	col.add_child(gap)
	gap.owner = root
	_label(col, root, "ComboTitle", "COMBO", 34, &"text_dim", true)
	_label(col, root, "ComboLabel", "×2.35", 60, &"accent", true)
	_label(col, root, "WorthLabel", "$3,760 if they buy", 32, &"margin")
	var knobs := _label(col, root, "KnobsLabel", "Each sale: combo +45%, Line +5",
		28, &"text_dim")
	knobs.autowrap_mode = TextServer.AUTOWRAP_WORD

	# The tablet itself: one quad, standing up, facing you.
	var quad := QuadMesh.new()
	quad.size = OfferTablet.SIZE
	var face := MeshInstance3D.new()
	face.name = "Face"
	face.mesh = quad
	root.add_child(face)
	face.owner = root

	var packed := PackedScene.new()
	packed.pack(root)
	var err := ResourceSaver.save(packed, OUT)
	if err != OK:
		push_error("failed to save %s: %d" % [OUT, err])
		quit(1)
		return
	print("saved offer_tablet.tscn")
	root.free()
	quit(0)

func _flat(role: StringName, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Palette.color(role)
	s.set_corner_radius_all(radius)
	return s

func _box(parent: Node, root: Node, node_name: String, r: Rect2, style: StyleBox) -> void:
	var p := Panel.new()
	p.name = node_name
	p.position = r.position
	p.size = r.size
	p.add_theme_stylebox_override("panel", style)
	parent.add_child(p)
	p.owner = root

## A white card on the screen, the way an app lays out its panels.
func _panel(parent: Node, root: Node, node_name: String, r: Rect2i) -> PanelContainer:
	var p := PanelContainer.new()
	p.name = node_name
	p.position = Vector2(r.position)
	p.custom_minimum_size = Vector2(r.size)
	p.size = Vector2(r.size)
	var s := _flat(&"panel", PANEL_RADIUS)
	s.set_border_width_all(2)
	s.border_color = Palette.color(&"neutral_2")
	s.content_margin_left = 26
	s.content_margin_right = 26
	s.content_margin_top = 24
	s.content_margin_bottom = 24
	p.add_theme_stylebox_override("panel", s)
	parent.add_child(p)
	p.owner = root
	return p

func _column(parent: Node, root: Node, separation: int) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.name = "Column"
	col.add_theme_constant_override("separation", separation)
	parent.add_child(col)
	col.owner = root
	return col

func _label(parent: Node, root: Node, node_name: String, text: String, size: int,
		role: StringName, heading: bool = false) -> Label:
	var l := Label.new()
	l.name = node_name
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Palette.color(role))
	if heading:
		l.theme_type_variation = &"Heading"
	parent.add_child(l)
	l.owner = root
	return l
