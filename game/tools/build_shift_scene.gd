extends SceneTree
## Builds res://scenes/shift.tscn - a 3D card table with a 2D HUD over it.
##
## Staging follows Card3D's own example_battle, which is the reference for how
## this is supposed to look: a lit table surface, a directional light with soft
## shadows so cards sit ON something, a camera close enough that a card is a
## real object rather than a stamp, and a FAN for the hand.
##
## Collections MUST be instanced from card_collection_3d.tscn, never
## CardCollection3D.new(): the class's @export setters reach into
## $DropZone/CollisionShape3D, which only the scene provides.
##
## Only a strategy's TYPE and its @export values survive packing. FanCardLayout
## exports arc_angle_deg and arc_radius so those stick; LineCardLayout.max_width
## is a plain var and would not, which is why the hand fans instead.

const COLLECTION := "res://addons/card_3d/scenes/card_collection_3d.tscn"
const REPORT := "res://scenes/report.tscn"

# Table geometry, in world units. Camera is head-on and untilted: legibility is
# this port's stated risk (GODOT_SPEC.md 11), so the faces point straight at the
# viewer. Tilt is the first knob to turn once someone can see it.
const CAM_Z := 11.0
const CAM_Y := -0.5
const CAM_FOV := 60.0

const CHAIR_Y := 2.4
const CHAIR_X := [-4.4, 0.0, 4.4]
const PILE_Y := 2.4
const DRAW_X := -9.3
const DISCARD_X := 9.3
const HAND_Y := -4.4
const FAN_ANGLE := 60.0
const FAN_RADIUS := 9.0

func _init() -> void:
	var root := Node3D.new()
	root.name = "ShiftRoot"
	root.set_script(load("res://scripts/view/shift_controller.gd"))

	var cam := Camera3D.new()
	cam.name = "Camera3D"
	cam.position = Vector3(0, CAM_Y, CAM_Z)
	cam.fov = CAM_FOV
	cam.current = true
	root.add_child(cam)
	cam.owner = root

	# Cards are lit, not unlit: the shading is most of what makes them read as
	# objects lying on a surface rather than decals.
	var light := DirectionalLight3D.new()
	light.name = "DirectionalLight3D"
	light.position = Vector3(0, 6, 12)
	light.rotation_degrees = Vector3(-32, -18, 0)
	light.light_energy = 1.15
	light.shadow_enabled = true
	light.shadow_opacity = 0.6
	light.shadow_blur = 4.0
	root.add_child(light)
	light.owner = root

	# Replaces G1's full-rect ColorRect background. That ColorRect would have
	# made every card in the game unclickable: Godot resolves Control GUI input
	# before physics picking, and ColorRect defaults to MOUSE_FILTER_STOP.
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Palette.color(&"neutral_1")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Palette.color(&"panel_hi")
	env.ambient_light_energy = 0.9
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	root.add_child(we)
	we.owner = root

	# The surface the cards sit on. A QuadMesh is already in the XY plane facing
	# +Z, so it needs no rotation the way a PlaneMesh would.
	var felt := QuadMesh.new()
	felt.size = Vector2(60, 40)
	var felt_mat := StandardMaterial3D.new()
	felt_mat.albedo_color = Palette.color(&"bg")
	felt_mat.roughness = 0.95
	var table_mesh := MeshInstance3D.new()
	table_mesh.name = "Felt"
	table_mesh.mesh = felt
	table_mesh.material_override = felt_mat
	table_mesh.position = Vector3(0, 0, -0.6)
	root.add_child(table_mesh)
	table_mesh.owner = root

	var table := Node3D.new()
	table.name = "Table"
	root.add_child(table)
	table.owner = root

	var collection_scene: PackedScene = load(COLLECTION)
	var zones: Array[Node3D] = []

	for i in range(3):
		var chair := _collection(collection_scene, "Chair%d" % i,
			Vector3(CHAIR_X[i], CHAIR_Y, 0.0), table, root)
		chair.card_layout_strategy = PileCardLayout.new()
		zones.append(chair)

	var draw := _collection(collection_scene, "Draw",
		Vector3(DRAW_X, PILE_Y, 0.0), table, root)
	draw.card_layout_strategy = PileCardLayout.new()
	zones.append(draw)

	var discard := _collection(collection_scene, "Discard",
		Vector3(DISCARD_X, PILE_Y, 0.0), table, root)
	discard.card_layout_strategy = PileCardLayout.new()
	zones.append(discard)

	var hand := _collection(collection_scene, "Hand",
		Vector3(0.0, HAND_Y, 0.0), table, root)
	var fan := FanCardLayout.new()
	fan.arc_angle_deg = FAN_ANGLE
	fan.arc_radius = FAN_RADIUS
	hand.card_layout_strategy = fan
	zones.append(hand)

	var drag := DragController.new()
	drag.name = "DragController"
	# Cards ride in front of the table while dragged, so they never clip into it.
	drag.card_drag_plane = Plane(Vector3(0, 0, 1), 1.5)
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
	print("saved shift.tscn with %d card collections" % zones.size())
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

func _build_hud(root: Node) -> void:
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	root.add_child(layer)
	layer.owner = root

	# Everything here is IGNORE unless it is a real button or a solid panel that
	# SHOULD block the table. A single stray STOP Control over the table makes
	# every card inert; see test_shift_scene.gd.
	var hud := Control.new()
	hud.name = "HudRoot"
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.unique_name_in_owner = true
	layer.add_child(hud)
	hud.owner = root

	var top := HBoxContainer.new()
	top.name = "TopBar"
	top.position = Vector2(10, 6)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 26)
	hud.add_child(top)
	top.owner = root

	for label_name in ["TickLabel", "BankedLabel", "AtRiskLabel"]:
		var l := Label.new()
		l.name = label_name
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.unique_name_in_owner = true
		top.add_child(l)
		l.owner = root

	# Bottom-left, clear of the fanned hand in the centre and the log on the
	# right. Floor panels sit above all three, under their own chairs.
	var slot := Control.new()
	slot.name = "CustomerSlot"
	slot.position = Vector2(8, 350)
	slot.size = Vector2(262, 184)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.unique_name_in_owner = true
	hud.add_child(slot)
	slot.owner = root

	var empty := Label.new()
	empty.name = "EmptySlotLabel"
	empty.text = "Stand with a customer to negotiate."
	empty.autowrap_mode = TextServer.AUTOWRAP_WORD
	empty.size = Vector2(262, 60)
	empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
	empty.unique_name_in_owner = true
	slot.add_child(empty)
	empty.owner = root

	var log_box := RichTextLabel.new()
	log_box.name = "EventLog"
	log_box.bbcode_enabled = true
	log_box.scroll_following = true
	log_box.position = Vector2(690, 350)
	log_box.size = Vector2(262, 184)
	log_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	log_box.unique_name_in_owner = true
	hud.add_child(log_box)
	log_box.owner = root

	# Keeps MOUSE_FILTER_STOP deliberately: once the shift is over it SHOULD
	# block drags on the table underneath it.
	var report: Control = (load(REPORT) as PackedScene).instantiate()
	report.name = "ReportOverlay"
	report.visible = false
	report.set_anchors_preset(Control.PRESET_FULL_RECT)
	report.unique_name_in_owner = true
	hud.add_child(report)
	report.owner = root
