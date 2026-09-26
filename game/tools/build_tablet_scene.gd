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
## How far a hardware button stands out past the case's edge, and how far it
## is sunk into it, in world units - about 6 px on screen at the desk.
const HARDWARE_OUT := 0.055
const HARDWARE_IN := 0.015

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

	_status_bar(screen, root)

	# Where the product stands. The card itself is a real card in front of the
	# screen - you drag it on, and off again to offer or drop it - so all the
	# screen draws is the place it goes.
	var well := _flat(&"paper_shade", 16)
	well.set_border_width_all(3)
	well.border_color = Palette.color(&"neutral_3")
	_box(screen, root, "Well", Rect2(OfferTablet.WELL_RECT), well)

	# --- left: how it is landing -------------------------------------------
	# The words on the outside and the meter on the inside, standing right up
	# against the product it is measuring.
	var appeal := _panel(screen, root, "AppealPanel", OfferTablet.APPEAL_RECT)
	var row := HBoxContainer.new()
	row.name = "Row"
	row.add_theme_constant_override("separation", 20)
	appeal.add_child(row)
	row.owner = root
	var col := _column(row, root, 14)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(col, root, "AppealTitle", "APPEAL", 34, &"text_dim", true)
	# Placeholders are the longest thing each can say.
	var status := _label(col, root, "StatusLabel", "READY TO SIGN", 42, &"text", true)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD
	var hint := _label(col, root, "HintLabel",
		"their Line is marked - clear it before you offer", 28, &"text_dim")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	# Fill is how much appeal this offer carries, colour is how that compares
	# with their Line, and the marker only appears once you have earned the Line.
	# Upright and the panel's full height - see appeal_bar.gd.
	var bar := Control.new()
	bar.name = "AppealBar"
	bar.custom_minimum_size = Vector2(OfferTablet.METER_WIDTH, 0)
	bar.set_script(load("res://scripts/view/appeal_bar.gd"))
	row.add_child(bar)
	bar.owner = root

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

	# Its hardware, as real slivers of the case sticking out past the glass: a
	# lock button along the top edge and a volume rocker down the right-hand
	# side, where a tablet lying in landscape keeps them. Seen head-on they are
	# thin, the way a real one on a desk shows them. Scenery like the rest -
	# meshes only, nothing to take a click.
	var case := StandardMaterial3D.new()
	case.albedo_color = Palette.color(&"tablet").lightened(0.22)
	case.roughness = 0.45
	# Each spans from HARDWARE_IN inside the edge to HARDWARE_OUT past it.
	var top: float = OfferTablet.SIZE.y * 0.5 + (HARDWARE_OUT - HARDWARE_IN) * 0.5
	var side: float = OfferTablet.SIZE.x * 0.5 + (HARDWARE_OUT - HARDWARE_IN) * 0.5
	var thick: float = HARDWARE_OUT + HARDWARE_IN
	for spec in [["LockButton", Vector3(2.55, top, 0.0), Vector3(0.62, thick, 0.08)],
			["VolumeUp", Vector3(side, 1.02, 0.0), Vector3(thick, 0.48, 0.08)],
			["VolumeDown", Vector3(side, 0.42, 0.0), Vector3(thick, 0.48, 0.08)]]:
		var box := BoxMesh.new()
		box.size = spec[2]
		var button := MeshInstance3D.new()
		button.name = spec[0]
		button.mesh = box
		button.position = spec[1]
		button.material_override = case
		root.add_child(button)
		button.owner = root

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

## A tablet's status bar along the top of its screen: the time on the left,
## signal bars and the battery on the right. The time is the shift's own clock
## (OfferTablet.show_clock()); the rest is the furniture that makes the screen
## read as a tablet's rather than as a panel's.
func _status_bar(screen: Control, root: Node) -> void:
	var r := OfferTablet.STATUS_RECT
	var bar := Control.new()
	bar.name = "StatusBar"
	bar.position = Vector2(r.position)
	bar.size = Vector2(r.size)
	screen.add_child(bar)
	bar.owner = root

	var clock := _label(bar, root, "ClockLabel", "10:20 AM", 24, &"text", true)
	clock.position = Vector2(0, -2)

	var w := float(r.size.x)
	var ink := Palette.color(&"text")
	# The battery, at the far right: its outline, what is left in it, and the
	# nub on its end.
	var shell := StyleBoxFlat.new()
	shell.bg_color = Color(ink, 0.0)
	shell.border_color = ink
	shell.set_border_width_all(2)
	shell.set_corner_radius_all(5)
	_box(bar, root, "BatteryShell", Rect2(w - 48, 4, 42, 22), shell)
	var solid := StyleBoxFlat.new()
	solid.bg_color = ink
	solid.set_corner_radius_all(2)
	_box(bar, root, "BatteryCharge", Rect2(w - 44, 8, 28, 14), solid)
	_box(bar, root, "BatteryNub", Rect2(w - 5, 11, 4, 8), solid)
	var charge := _label(bar, root, "BatteryLabel", "82%", 20, &"text")
	charge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	charge.position = Vector2(w - 116, 0)
	charge.size = Vector2(60, 30)
	# Four signal bars, climbing, left of that.
	for i in range(4):
		var tall := 8.0 + i * 4.0
		_box(bar, root, "Signal%d" % i, Rect2(w - 156 + i * 9, 26 - tall, 6, tall), solid)

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
