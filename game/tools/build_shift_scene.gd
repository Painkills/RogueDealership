extends SceneTree
## Builds res://scenes/shift.tscn - a 3D card table with a 2D HUD over it.
##
## Why a builder script and not the editor: every scene in this project is
## generated this way, it diffs readably, and it is the only option in a session
## with no display. The one thing it CANNOT produce is scene inheritance
## (load-instantiate-repack bakes a copy and severs the link), which is why
## card_face_3d.tscn is hand-authored .tscn text instead. Instancing is fine -
## pack() preserves it - so the card collections below are real instances of the
## vendored card_collection_3d.tscn.
##
## Collections MUST be instanced from that scene, never CardCollection3D.new():
## the class's @export setters reach into $DropZone/CollisionShape3D, which only
## the scene provides.

const COLLECTION := "res://addons/card_3d/scenes/card_collection_3d.tscn"
const REPORT := "res://scenes/report.tscn"

# Table geometry, in world units. The camera sits head-on at CAM_Z with no tilt:
# legibility is this port's stated risk (GODOT_SPEC.md 11), and foreshortened
# Label3D text is the thing most likely to make it fail, so the cards face the
# viewer squarely. Tilt is the first knob to turn once someone can actually see
# it - Card3D still gives hover-lift and drag-tilt in 3D either way.
const CAM_Z := 13.0
const CAM_Y := -1.0
const CAM_FOV := 60.0

const CHAIR_Y := 2.2
const CHAIR_X := [-4.6, 0.0, 4.6]
const PILE_Y := 2.2
const DRAW_X := -10.5
const DISCARD_X := 10.5
const HAND_Y := -5.8

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

	# Replaces G1's full-rect ColorRect background. That ColorRect would have
	# made every card in the game unclickable: Godot resolves Control GUI input
	# before physics picking, and ColorRect defaults to MOUSE_FILTER_STOP.
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Palette.color(&"bg")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 1.0
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	root.add_child(we)
	we.owner = root

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
	# Only the strategy's TYPE survives packing. LineCardLayout.max_width is a
	# plain var, not @export, so it serializes as nothing and reverts to the
	# library default of 20 units on load - wide enough to run off screen.
	# shift_controller.gd sets it at runtime instead; see HAND_MAX_WIDTH there.
	hand.card_layout_strategy = LineCardLayout.new()
	zones.append(hand)

	var drag := DragController.new()
	drag.name = "DragController"
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
	# pack() has copied everything; free the scratch tree so real errors are not
	# buried under leak warnings on the next build.
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
	# every card inert; see test_hud_input.gd.
	var hud := Control.new()
	hud.name = "HudRoot"
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.unique_name_in_owner = true
	layer.add_child(hud)
	hud.owner = root

	var top := HBoxContainer.new()
	top.name = "TopBar"
	top.position = Vector2(8, 4)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 24)
	hud.add_child(top)
	top.owner = root

	for label_name in ["TickLabel", "BankedLabel", "AtRiskLabel"]:
		var l := Label.new()
		l.name = label_name
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.unique_name_in_owner = true
		top.add_child(l)
		l.owner = root

	# Free-floating, NOT in a container: _render() drives their positions from
	# the 3D chair zones via unproject_position(), and a Container would
	# overwrite position on every layout pass.
	var slot := Control.new()
	slot.name = "CustomerSlot"
	slot.position = Vector2(8, 300)
	slot.size = Vector2(292, 232)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.unique_name_in_owner = true
	hud.add_child(slot)
	slot.owner = root

	var empty := Label.new()
	empty.name = "EmptySlotLabel"
	empty.text = "Stand with a customer to negotiate."
	empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
	empty.unique_name_in_owner = true
	slot.add_child(empty)
	empty.owner = root

	var log_box := RichTextLabel.new()
	log_box.name = "EventLog"
	log_box.bbcode_enabled = true
	log_box.scroll_following = true
	log_box.position = Vector2(660, 300)
	log_box.size = Vector2(292, 232)
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
