extends SceneTree
## Why is nothing clickable? Asks the two systems that decide, instead of
## guessing between them - they have identical symptoms and the project has
## already shipped this bug class twice.
##
##   1. PHYSICS. Fire the real camera ray at each card's screen centre and
##      report what the space actually returns.
##   2. CONTROLS. Walk the HUD for any visible Control that contains that same
##      point and does not have MOUSE_FILTER_IGNORE, because Godot resolves
##      Control GUI input BEFORE physics picking.
##
##   godot --headless --path game --script res://tools/probe_input.gd

var _root: Node3D
var _done := false

func _init() -> void:
	seed(20260903)
	_root = (load("res://scenes/shift.tscn") as PackedScene).instantiate()
	get_root().add_child(_root)

func _physics_process(_delta: float) -> bool:
	if _done:
		return true
	_done = true

	var cam: Camera3D = _root.get_node(^"Camera3D")
	print("viewport physics_object_picking = %s" % get_root().physics_object_picking)
	print("viewport gui_disable_input        = %s" % get_root().gui_disable_input)
	print("camera current                    = %s" % cam.current)
	print("world_3d space                    = %s" % get_root().world_3d.space)

	for i in range(3):
		var card := _root.get_node(NodePath("%%Customer%d" % i)) as Node3D
		_report("Customer%d" % i, cam, card)
	_report("Chair0 zone", cam, _root.get_node(^"%Chair0") as Node3D)

	var hand: CardCollection3D = _root.get_node(^"%Hand")
	print("\nhand holds %d cards" % hand.cards.size())
	if not hand.cards.is_empty():
		_report("hand card 0 (floor, stowed)", cam, hand.cards[0])

	print("\n################ sitting down ################")
	var ev := InputEventKey.new()
	ev.keycode = KEY_A
	ev.pressed = true
	_root._unhandled_input(ev)
	var t = _root._framing_tween
	if t != null and t.is_valid() and t.is_running():
		t.custom_step(2.0)
	cam.force_update_transform()
	hand.force_update_transform()
	# A tween writes to the node; the physics server only learns about it when the
	# transform is flushed between frames. Everything here happens inside ONE
	# frame, so flush by hand - otherwise every ray reports "hit nothing" against
	# colliders still sitting where they were, which reads exactly like the bug
	# this tool exists to find.
	for card in hand.cards:
		var pt = (card as Card3D).position_tween
		if pt != null and pt.is_valid() and pt.is_running():
			pt.custom_step(2.0)
		(card as Node3D).force_update_transform()
		(card.get_node(^"StaticBody3D") as Node3D).force_update_transform()

	print("every chair drop zone, which is a StaticBody3D 3.2 units IN FRONT:")
	for i in range(3):
		var dz := _root.get_node(NodePath("%%Chair%d/DropZone/CollisionShape3D" % i)) as CollisionShape3D
		var body := _root.get_node(NodePath("%%Chair%d/DropZone" % i)) as StaticBody3D
		print("  Chair%d zone disabled=%s at world z %.2f (cards sit at 0)"
			% [i, dz.disabled, body.global_position.z])

	if not hand.cards.is_empty():
		_report("hand card 0 (seated, raised)", cam, hand.cards[0])
	for i in range(3):
		_report("Customer%d (seated)" % i, cam,
			_root.get_node(NodePath("%%Customer%d" % i)) as Node3D)

	quit(0)
	return true

func _report(label: String, cam: Camera3D, node: Node3D) -> void:
	print("\n--- %s at %s ---" % [label, node.global_position])
	if cam.is_position_behind(node.global_position):
		print("  BEHIND THE CAMERA - nothing to click")
		return
	var p := cam.unproject_position(node.global_position)
	print("  screen point %s" % p)
	print("  visible in tree: %s" % node.is_visible_in_tree())

	var shape := node.get_node_or_null(^"StaticBody3D/CollisionShape3D") as CollisionShape3D
	if shape == null:
		print("  NO CollisionShape3D")
	else:
		var body := node.get_node(^"StaticBody3D") as StaticBody3D
		print("  collider disabled=%s  ray_pickable=%s  layer=%d  shape=%s"
			% [shape.disabled, body.input_ray_pickable, body.collision_layer, shape.shape])

	var space := get_root().world_3d.direct_space_state
	var from := cam.project_ray_origin(p)
	var q := PhysicsRayQueryParameters3D.create(from, from + cam.project_ray_normal(p) * 200.0)
	q.collide_with_areas = true
	q.collide_with_bodies = true
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		print("  RAY HIT NOTHING")
	else:
		print("  ray hit: %s" % (hit["collider"] as Node).get_path())

	var blockers: Array[String] = []
	_walk_controls(_root.get_node(^"%HudRoot") as Control, p, blockers)
	print("  controls swallowing this point: %s"
		% ("none" if blockers.is_empty() else ", ".join(blockers)))

func _walk_controls(node: Control, p: Vector2, out: Array[String]) -> void:
	for child in node.get_children():
		if child is not Control:
			continue
		var c := child as Control
		if not c.is_visible_in_tree():
			continue
		if c.mouse_filter != Control.MOUSE_FILTER_IGNORE and c.get_global_rect().has_point(p):
			out.append("%s (%s, filter=%d)" % [c.name, c.get_class(), c.mouse_filter])
		_walk_controls(c, p, out)
