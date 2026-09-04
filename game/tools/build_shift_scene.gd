extends SceneTree
## Builds res://scenes/shift.tscn.
##
## The layout follows one rule: THINGS THAT ARE YOURS ARE ANCHORED TO THE SCREEN,
## THINGS THAT ARE THEIRS ARE ANCHORED TO THEM.
##
##   yours  - the shift log (far right), your hand (bottom of the table), and
##            the OFFER / DROP / CLOSE bar (middle). These never move, because
##            they belong to you, and you are what the camera carries around.
##   theirs - a customer CARD at each seat carrying name, portrait, archetype
##            and patience, plus a detail panel beside it for everything wordier:
##            what their archetype does to you, what is on the table unsigned,
##            and what you have learned about their priorities.
##
## Two framings: a wide floor shot of all three seats, and a push-in on one.
## Seats sit far enough apart that the push-in physically excludes the others.
## Both framings are Marker3D nodes so they can be dragged in the editor.
##
## Everything is authored to be legible WITHOUT running: seats hold a customer
## card reading "- empty -", zones carry labelled translucent slabs, and every
## HUD label ships with placeholder text.

const COLLECTION := "res://addons/card_3d/scenes/card_collection_3d.tscn"
const CUSTOMER_CARD := "res://scenes/cards/customer_card_3d.tscn"
const CUSTOMER_PANEL := "res://scenes/customer_panel.tscn"
const REPORT := "res://scenes/report.tscn"

# --- table geometry, world units -------------------------------------------
const CHAIR_X := [-14.0, 0.0, 14.0]
const CUSTOMER_Y := 4.0      ## their card
const CHAIR_Y := 0.2         ## the offer slot in front of them
const PILE_Y := 4.0
const DRAW_X := -24.0
const DISCARD_X := 24.0
const HAND_Y_FLOOR := -13.0  ## dropped out of shot while you survey the floor
const HAND_Y_SEAT := -4.4    ## up in reach once you sit down
const FAN_ANGLE := 62.0
const FAN_RADIUS := 9.5

const CAM_FOV := 60.0
## Offset right, so the table composes into the space LEFT of the log panel.
const FLOOR_CAM := Vector3(5.0, 2.0, 24.0)
const FLOOR_CAM_PITCH := -5.0
const SEAT_CAM_Y := -0.2
const SEAT_CAM_Z := 11.0
const SEAT_CAM_PITCH := -4.0

# --- HUD, in 1920x1080 -----------------------------------------------------
const DETAIL_RECT := Rect2(48, 140, 560, 900)
const ACTION_RECT := Rect2(700, 902, 460, 96)
const LOG_RECT := Rect2(1480, 40, 416, 1000)

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
	felt.size = Vector2(140, 80)
	var felt_mat := StandardMaterial3D.new()
	felt_mat.albedo_color = Palette.color(&"bg")
	felt_mat.roughness = 0.95
	var table_mesh := MeshInstance3D.new()
	table_mesh.name = "Felt"
	table_mesh.mesh = felt
	table_mesh.material_override = felt_mat
	table_mesh.position = Vector3(0, 0, -0.8)
	root.add_child(table_mesh)
	table_mesh.owner = root

	var table := Node3D.new()
	table.name = "Table"
	root.add_child(table)
	table.owner = root

	var collection_scene: PackedScene = load(COLLECTION)
	var customer_scene: PackedScene = load(CUSTOMER_CARD)

	for i in range(3):
		# The person: a card, baked into the scene so a seat is never an
		# invisible empty node in the editor.
		var who := customer_scene.instantiate()
		who.name = "Customer%d" % i
		who.position = Vector3(CHAIR_X[i], CUSTOMER_Y, 0.0)
		who.unique_name_in_owner = true
		table.add_child(who)
		who.owner = root

		# The offer slot in front of them.
		var chair := _collection(collection_scene, "Chair%d" % i,
			Vector3(CHAIR_X[i], CHAIR_Y, 0.0), table, root)
		chair.card_layout_strategy = PileCardLayout.new()
		_mark(chair, root, "SEAT %s\nplay a card here" % ["A", "B", "C"][i],
			Palette.color(&"appeal"))

		var seat_cam := Marker3D.new()
		seat_cam.name = "SeatCam%d" % i
		seat_cam.position = Vector3(CHAIR_X[i], SEAT_CAM_Y, SEAT_CAM_Z)
		seat_cam.rotation_degrees = Vector3(SEAT_CAM_PITCH, 0, 0)
		seat_cam.unique_name_in_owner = true
		root.add_child(seat_cam)
		seat_cam.owner = root

	var draw := _collection(collection_scene, "Draw",
		Vector3(DRAW_X, PILE_Y, 0.0), table, root)
	draw.card_layout_strategy = PileCardLayout.new()
	_mark(draw, root, "DRAW", Palette.color(&"neutral_3"))

	var discard := _collection(collection_scene, "Discard",
		Vector3(DISCARD_X, PILE_Y, 0.0), table, root)
	discard.card_layout_strategy = PileCardLayout.new()
	_mark(discard, root, "DISCARD\ndrag here to dig", Palette.color(&"action"))

	var hand := _collection(collection_scene, "Hand",
		Vector3(0.0, HAND_Y_SEAT, 0.0), table, root)
	var fan := FanCardLayout.new()
	fan.arc_angle_deg = FAN_ANGLE
	fan.arc_radius = FAN_RADIUS
	hand.card_layout_strategy = fan
	_mark(hand, root, "YOUR HAND", Palette.color(&"margin"))

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
	label.pixel_size = 0.006
	label.modulate = tint
	label.outline_size = 10
	label.outline_modulate = Palette.color(&"neutral_1")
	label.shaded = false
	label.double_sided = false
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.position = Vector3(0, -2.35, 0.02)
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

	# --- yours: the shift bar ---------------------------------------------
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

	# --- theirs: the detail panel, beside their card ----------------------
	var detail := Control.new()
	detail.name = "CustomerSlot"
	detail.position = DETAIL_RECT.position
	detail.size = DETAIL_RECT.size
	detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail.unique_name_in_owner = true
	hud.add_child(detail)
	detail.owner = root

	var empty := Label.new()
	empty.name = "EmptySlotLabel"
	empty.text = "Nobody selected.\n\nClick a customer's card, or press A / B / C."
	empty.autowrap_mode = TextServer.AUTOWRAP_WORD
	empty.set_anchors_preset(Control.PRESET_FULL_RECT)
	empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
	empty.unique_name_in_owner = true
	detail.add_child(empty)
	empty.owner = root

	# --- yours: the action bar, in the middle where the table is ----------
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
		b.custom_minimum_size = Vector2(140, 84)
		b.add_theme_font_size_override("font_size", 30)
		b.unique_name_in_owner = true
		actions.add_child(b)
		b.owner = root

	# --- yours: the log, far right ----------------------------------------
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

	var report: Control = (load(REPORT) as PackedScene).instantiate()
	report.name = "ReportOverlay"
	report.visible = false
	report.set_anchors_preset(Control.PRESET_FULL_RECT)
	report.unique_name_in_owner = true
	hud.add_child(report)
	report.owner = root
