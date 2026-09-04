extends SceneTree
## Prints where everything lands ON SCREEN in each framing, in pixels.
##
## Tuning camera constants by reasoning about field of view is how the last three
## layouts went wrong. This just asks the camera. Not a test - it asserts
## nothing; drive_shift.gd is where the answers get pinned.
##
##   godot --headless --path game --script res://tools/probe_framing.gd

const SCREEN := Vector2(1920, 1080)

var _root: Node3D
var _done := false

func _init() -> void:
	seed(20260903)
	_root = (load("res://scenes/shift.tscn") as PackedScene).instantiate()
	get_root().add_child(_root)

func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true

	var cam: Camera3D = _root.get_node(^"Camera3D")
	print("screen %s, fov %.1f" % [SCREEN, cam.fov])

	var detail := _root.get_node(^"%CustomerDetail0") as Node3D
	var mesh := (detail.get_node(^"CardMesh/CardFrontMesh") as MeshInstance3D).mesh as PlaneMesh
	print("detail card mesh: %s   (want 4 x 3.5)" % mesh.size)

	_frame(cam, "FLOOR", _root.get_node(^"%CameraFloor") as Node3D, -1)
	for i in range(3):
		_frame(cam, "SEAT %d" % i, _root.get_node(NodePath("%%SeatCam%d" % i)) as Node3D, i)

	quit(0)
	return true

func _frame(cam: Camera3D, label: String, mark: Node3D, seat: int) -> void:
	cam.global_position = mark.global_position
	cam.global_rotation = mark.global_rotation
	cam.force_update_transform()
	print("\n=== %s   camera %s ===" % [label, _v(cam.global_position)])

	for i in range(3):
		var who := _root.get_node(NodePath("%%Customer%d" % i)) as Node3D
		_rect(cam, "customer%d" % i, who.global_position, Vector2(2.5, 3.5))

	if seat >= 0:
		var out: Vector3 = DetailCard3D.SLIDE_OUT
		var wd := _root.get_node(NodePath("%%CustomerDetail%d" % seat)) as Node3D
		_rect(cam, "customer detail", wd.global_position + out, DetailCard3D.CARD_SIZE)
		var chair := _root.get_node(NodePath("%%Chair%d" % seat)) as Node3D
		_rect(cam, "product slot", chair.global_position, Vector2(2.5, 3.5))
		var od := _root.get_node(NodePath("%%OfferDetail%d" % seat)) as Node3D
		_rect(cam, "offer detail", od.global_position + out, DetailCard3D.CARD_SIZE)

	# Yours ride with the camera, so they are placed in camera-local space and
	# only their raised positions are worth looking at.
	var raised := {
		"hand": _root.HAND_UP, "draw": _root.DRAW_UP, "discard": _root.DISCARD_UP}
	for name in raised:
		var local: Vector3 = raised[name]
		_rect(cam, name, cam.global_transform * local, Vector2(2.5, 3.5))

	for pair in [["mode button", "%ModeButton"], ["action column", "%ActionBar"],
			["log", "%SidePanel"]]:
		var c := _root.get_node(NodePath(pair[1])) as Control
		print("  %-16s x %4d..%4d   y %4d..%4d" % [pair[0], int(c.position.x),
			int(c.position.x + c.size.x), int(c.position.y),
			int(c.position.y + c.size.y)])

func _rect(cam: Camera3D, label: String, centre: Vector3, size: Vector2) -> void:
	if cam.is_position_behind(centre):
		print("  %-16s BEHIND THE CAMERA" % label)
		return
	var tl := cam.unproject_position(centre + Vector3(-size.x * 0.5, size.y * 0.5, 0))
	var br := cam.unproject_position(centre + Vector3(size.x * 0.5, -size.y * 0.5, 0))
	print("  %-16s x %4d..%4d   y %4d..%4d   (%d x %d px)"
		% [label, int(tl.x), int(br.x), int(tl.y), int(br.y),
			int(br.x - tl.x), int(br.y - tl.y)])

func _v(v: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [v.x, v.y, v.z]
