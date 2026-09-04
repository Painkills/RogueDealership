extends SceneTree
## Builds res://scenes/shift.tscn.
##
## THE CAMERA IS THE PLAYER. Your hand, your draw pile and your discard are
## children of Camera3D, parked just below the bottom of frame. They travel with
## you for free, and arriving at a seat only has to tween them up in camera-local
## space. This is what makes the seat framing tractable: it has to contain the
## customer and their table, and nothing of yours.
##
## Two framings, both Marker3D so they are draggable gizmos in the editor:
##   floor - all three customer cards, hand stowed, nothing of yours in shot
##   seat  - one customer, pushed in; neighbours fall outside the frame
##
## The floor view is deliberately bare: customer cards and the top bar, with
## everything else about a customer behind a hover tooltip or the zoom.

const COLLECTION := "res://addons/card_3d/scenes/card_collection_3d.tscn"
const CUSTOMER_CARD := "res://scenes/cards/customer_card_3d.tscn"
const REPORT := "res://scenes/report.tscn"

# --- table geometry, world units -------------------------------------------
const CHAIR_X := [-17.0, 0.0, 17.0]
const CUSTOMER_Y := 4.0      ## their card
const CHAIR_Y := 0.2         ## the offer slot in front of them

## Well behind everything. Your hand rides at PILE_DEPTH in FRONT of the camera,
## which puts it at world z = seat_cam_z + PILE_DEPTH; if the felt sat closer
## than that the hand would slide behind the table as the camera pushed in and
## simply vanish. It did. test_shift_scene.gd pins the clearance now.
const FELT_Z := -8.0

const CAM_FOV := 60.0
## Offset right so the three cards compose LEFT of the shift log.
const FLOOR_CAM := Vector3(6.0, 3.0, 26.0)
const FLOOR_CAM_PITCH := -6.0
## Pulled back far enough that the customer card and the offer slot both sit
## ABOVE the band the hand occupies, instead of the hand covering the table.
const SEAT_CAM_Y := -0.2
const SEAT_CAM_Z := 12.8
const SEAT_CAM_PITCH := -3.0

# --- yours, in CAMERA-LOCAL space ------------------------------------------
# -Z is forward. Stowed positions sit below the bottom of frame at that depth.
const PILE_DEPTH := -11.0
const HAND_UP := Vector3(0.0, -3.2, PILE_DEPTH)
const HAND_STOWED := Vector3(0.0, -12.5, PILE_DEPTH)
const DISCARD_UP := Vector3(8.6, -4.4, PILE_DEPTH)
const DISCARD_STOWED := Vector3(8.6, -13.5, PILE_DEPTH)
const DRAW_UP := Vector3(-8.6, -4.4, PILE_DEPTH)
const DRAW_STOWED := Vector3(-8.6, -13.5, PILE_DEPTH)
const FAN_ANGLE := 62.0
const FAN_RADIUS := 9.5

# --- HUD, in 1920x1080 -----------------------------------------------------
const MODE_RECT := Rect2(28, 82, 360, 76)
## Stops well above the bottom strip, which is where the discard rises into.
const LOG_RECT := Rect2(1480, 40, 416, 690)
const ACTION_RECT := Rect2(730, 976, 460, 92)
const OFFER_PANEL_SIZE := Vector2(400, 300)
const TOOLTIP_SIZE := Vector2(520, 250)

func _init() -> void:
	var root := Node3D.new()
	root.name = "ShiftRoot"
	root.set_script(load("res://scripts/view/shift_controller.gd"))

	var cam := Camera3D.new()
	cam.name = "Camera3D"
	cam.fov = CAM_FOV
	cam.current = true
	cam.position = FLOOR_CAM
	cam.rotation_degrees = Vector3(FLOOR_CAM_PITCH, 0, 0)
	root.add_child(cam)
	cam.owner = root

	var floor_mark := Marker3D.new()
	floor_mark.name = "CameraFloor"
	floor_mark.position = FLOOR_CAM
	floor_mark.rotation_degrees = Vector3(FLOOR_CAM_PITCH, 0, 0)
	floor_mark.unique_name_in_owner = true
	root.add_child(floor_mark)
	floor_mark.owner = root

	var light := DirectionalLight3D.new()
	light.name = "DirectionalLight3D"
	light.position = Vector3(0, 12, 18)
	light.rotation_degrees = Vector3(-38, -22, 0)
	light.light_energy = 1.2
	light.shadow_enabled = true
	light.shadow_opacity = 0.55
	light.shadow_blur = 3.0
	root.add_child(light)
	light.owner = root

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Palette.color(&"neutral_1")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Palette.color(&"panel_hi")
	env.ambient_light_energy = 1.0
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	root.add_child(we)
	we.owner = root

	var felt := QuadMesh.new()
	felt.size = Vector2(220, 130)
	var felt_mat := StandardMaterial3D.new()
	felt_mat.albedo_color = Palette.color(&"bg")
	felt_mat.roughness = 0.95
	var table_mesh := MeshInstance3D.new()
	table_mesh.name = "Felt"
	table_mesh.mesh = felt
	table_mesh.material_override = felt_mat
	table_mesh.position = Vector3(0, 0, FELT_Z)
	root.add_child(table_mesh)
	table_mesh.owner = root

	# --- theirs: fixed in the world --------------------------------------
	var table := Node3D.new()
	table.name = "Table"
	root.add_child(table)
	table.owner = root

	var collection_scene: PackedScene = load(COLLECTION)
	var customer_scene: PackedScene = load(CUSTOMER_CARD)

	for i in range(3):
		var who := customer_scene.instantiate()
		who.name = "Customer%d" % i
		who.position = Vector3(CHAIR_X[i], CUSTOMER_Y, 0.0)
		who.unique_name_in_owner = true
		table.add_child(who)
		who.owner = root

		var chair := _collection(collection_scene, "Chair%d" % i,
			Vector3(CHAIR_X[i], CHAIR_Y, 0.0), table, root)
		chair.card_layout_strategy = PileCardLayout.new()
		_mark(chair, root, "SEAT %s" % ["A", "B", "C"][i], Palette.color(&"appeal"))

		var seat_cam := Marker3D.new()
		seat_cam.name = "SeatCam%d" % i
		seat_cam.position = Vector3(CHAIR_X[i], SEAT_CAM_Y, SEAT_CAM_Z)
		seat_cam.rotation_degrees = Vector3(SEAT_CAM_PITCH, 0, 0)
		seat_cam.unique_name_in_owner = true
		root.add_child(seat_cam)
		seat_cam.owner = root

	# --- yours: parented to the camera, stowed below frame ----------------
	var hand := _collection(collection_scene, "Hand", HAND_STOWED, cam, root)
	var fan := FanCardLayout.new()
	fan.arc_angle_deg = FAN_ANGLE
	fan.arc_radius = FAN_RADIUS
	hand.card_layout_strategy = fan
	_mark(hand, root, "YOUR HAND", Palette.color(&"margin"))

	var discard := _collection(collection_scene, "Discard", DISCARD_STOWED, cam, root)
	discard.card_layout_strategy = PileCardLayout.new()
	_mark(discard, root, "DISCARD\ndrag here to dig", Palette.color(&"action"))

	var draw := _collection(collection_scene, "Draw", DRAW_STOWED, cam, root)
	draw.card_layout_strategy = PileCardLayout.new()
	_mark(draw, root, "DRAW", Palette.color(&"neutral_3"))

	var drag := DragController.new()
	drag.name = "DragController"
	drag.card_drag_plane = Plane(Vector3(0, 0, 1), 2.0)
	root.add_child(drag)
	drag.owner = root

	_build_hud(root)

	var packed := PackedScene.new()
	packed.pack(root)
	var err := ResourceSaver.save(packed, "res://scenes/shift.tscn")
	if err != OK:
		push_error("failed to save shift.tscn: %d" % err)
		quit(1)
		return
	print("saved shift.tscn")
	root.free()
	quit(0)

func _collection(scene: PackedScene, node_name: String, pos: Vector3,
		parent: Node, owner_root: Node) -> Node3D:
	var c := scene.instantiate()
	c.name = node_name
	c.position = pos
	c.unique_name_in_owner = true
	parent.add_child(c)
	c.owner = owner_root
	return c

## A labelled translucent slab behind a zone - the only thing that makes a
## CardCollection3D visible in the editor, and a useful "drop here" at runtime.
func _mark(zone: Node3D, owner_root: Node, text: String, tint: Color) -> void:
	var slab := QuadMesh.new()
	slab.size = Vector2(2.9, 3.9)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(tint.r, tint.g, tint.b, 0.16)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var mesh := MeshInstance3D.new()
	mesh.name = "ZoneSlab"
	mesh.mesh = slab
	mesh.material_override = mat
	mesh.position = Vector3(0, 0, -0.05)
	zone.add_child(mesh)
	mesh.owner = owner_root

	var label := Label3D.new()
	label.name = "ZoneLabel"
	label.text = text
	label.font_size = 64
	label.pixel_size = 0.005
	label.modulate = tint
	label.outline_size = 10
	label.outline_modulate = Palette.color(&"neutral_1")
	label.shaded = false
	label.double_sided = false
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.position = Vector3(0, -2.3, 0.02)
	zone.add_child(label)
	label.owner = owner_root

func _build_hud(root: Node) -> void:
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	root.add_child(layer)
	layer.owner = root

	var hud := Control.new()
	hud.name = "HudRoot"
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.unique_name_in_owner = true
	layer.add_child(hud)
	hud.owner = root

	# --- the shift bar, always ------------------------------------------
	var top := HBoxContainer.new()
	top.name = "TopBar"
	top.position = Vector2(28, 18)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 48)
	hud.add_child(top)
	top.owner = root

	var placeholders := {
		"TickLabel": "tick 0/24",
		"BankedLabel": "banked $0 / $3,600",
		"AtRiskLabel": "nothing unsigned",
	}
	for label_name in placeholders:
		var l := Label.new()
		l.name = label_name
		l.text = placeholders[label_name]
		l.add_theme_font_size_override("font_size", 30)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.unique_name_in_owner = true
		top.add_child(l)
		l.owner = root

	# --- the one button that changes where you are ------------------------
	# Big and obvious on purpose: with the other two seats off screen while you
	# negotiate, this is how you check on them, so it must never be a hunt.
	var mode := Button.new()
	mode.name = "ModeButton"
	mode.text = "RETURN TO FLOOR"
	mode.position = MODE_RECT.position
	mode.size = MODE_RECT.size
	mode.custom_minimum_size = MODE_RECT.size
	mode.add_theme_font_size_override("font_size", 28)
	mode.unique_name_in_owner = true
	hud.add_child(mode)
	mode.owner = root

	# --- theirs: one offer panel per seat, anchored to their product area --
	# One shared panel repositioned by whoever was selected kept landing on top
	# of the thing it described. Each seat owns its own now, positioned from its
	# OWN chair zone, and only the seat you are with is shown.
	for i in range(3):
		_offer_panel(i, hud, root)

	# --- yours: the action bar, under the arc of the hand -----------------
	var actions := HBoxContainer.new()
	actions.name = "ActionBar"
	actions.position = ACTION_RECT.position
	actions.size = ACTION_RECT.size
	actions.add_theme_constant_override("separation", 18)
	actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	actions.unique_name_in_owner = true
	hud.add_child(actions)
	actions.owner = root

	for spec in [["OfferButton", "OFFER"], ["DropButton", "DROP"], ["CloseButton", "CLOSE"]]:
		var b := Button.new()
		b.name = spec[0]
		b.text = spec[1]
		b.custom_minimum_size = Vector2(140, 80)
		b.add_theme_font_size_override("font_size", 28)
		b.unique_name_in_owner = true
		actions.add_child(b)
		b.owner = root

	# --- yours: the log, right, stopping short of the discard -------------
	var panel := PanelContainer.new()
	panel.name = "SidePanel"
	panel.position = LOG_RECT.position
	panel.size = LOG_RECT.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.unique_name_in_owner = true
	hud.add_child(panel)
	panel.owner = root

	var col := VBoxContainer.new()
	col.name = "Column"
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(col)
	col.owner = root

	var log_title := Label.new()
	log_title.name = "LogTitle"
	log_title.text = "SHIFT LOG"
	log_title.add_theme_color_override("font_color", Palette.color(&"text_dim"))
	log_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(log_title)
	log_title.owner = root

	var log_box := RichTextLabel.new()
	log_box.name = "EventLog"
	log_box.bbcode_enabled = true
	log_box.scroll_following = true
	log_box.text = "Walk-ups, offers and objections show up here."
	log_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	log_box.unique_name_in_owner = true
	col.add_child(log_box)
	log_box.owner = root

	# --- hover tooltip, floor view ----------------------------------------
	var tip := PanelContainer.new()
	tip.name = "Tooltip"
	tip.size = TOOLTIP_SIZE
	tip.custom_minimum_size = TOOLTIP_SIZE
	tip.position = Vector2(700, 620)
	tip.visible = false
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip.unique_name_in_owner = true
	hud.add_child(tip)
	tip.owner = root

	var tip_label := Label.new()
	tip_label.name = "TooltipLabel"
	tip_label.text = "WHAT THEY DO\n(hover a customer on the floor)"
	tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	tip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip_label.unique_name_in_owner = true
	tip.add_child(tip_label)
	tip_label.owner = root

	var report: Control = (load(REPORT) as PackedScene).instantiate()
	report.name = "ReportOverlay"
	report.visible = false
	report.set_anchors_preset(Control.PRESET_FULL_RECT)
	report.unique_name_in_owner = true
	hud.add_child(report)
	report.owner = root


## One seat's product readout. A plain Panel, not a PanelContainer: its size has
## to be exactly what the controller positions against, and a container would
## resize it to its contents behind our back - which is why the old shared panel
## kept ending up over the product instead of beside it.
func _offer_panel(index: int, hud: Control, root: Node) -> void:
	var panel := Panel.new()
	panel.name = "OfferPanel%d" % index
	panel.size = OFFER_PANEL_SIZE
	panel.custom_minimum_size = OFFER_PANEL_SIZE
	panel.position = Vector2(120 + index * 60, 380)
	panel.visible = index == 0        # editor preview; the controller takes over
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.unique_name_in_owner = true
	hud.add_child(panel)
	panel.owner = root

	var row := HBoxContainer.new()
	row.name = "Row"
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 14
	row.offset_top = 14
	row.offset_right = -14
	row.offset_bottom = -14
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	row.owner = root

	# The Line as a column you climb, rather than a bar you fill sideways.
	var bar := Control.new()
	bar.name = "AppealBar"
	bar.custom_minimum_size = Vector2(52, 0)
	bar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.set_script(load("res://scripts/view/appeal_bar.gd"))
	row.add_child(bar)
	bar.owner = root

	var col := VBoxContainer.new()
	col.name = "Column"
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	col.owner = root

	# Named, not unique-named: three panels would collide on unique names, and
	# the controller addresses these through its own panel reference anyway.
	var specs := [
		["OfferTitle", "ON THE TABLE", 20, &"text_dim"],
		["OfferNameLabel", "Vehicle Service Contract", 28, &"text"],
		["OfferCategoryLabel", "Vehicle . Reliability", 22, &"text_dim"],
		["OfferMarginLabel", "$1,600", 30, &"margin"],
		["GapLabel", "12 SHORT", 30, &"alert"],
	]
	for spec in specs:
		var l := Label.new()
		l.name = spec[0]
		l.text = spec[1]
		l.add_theme_font_size_override("font_size", spec[2])
		l.add_theme_color_override("font_color", Palette.color(spec[3]))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(l)
		l.owner = root
