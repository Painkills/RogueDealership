extends RefCounted
## Structure of the table scene, checked without putting it in a tree.
##
## instantiate() builds the whole node tree, so names, types, parenting, mouse
## filters and world positions are all assertable headlessly. Anything needing
## _ready() lives in tools/drive_shift.gd instead, because run_tests.gd works
## inside _init() where _ready() has not fired yet.
var h: Harness

const SCENE := "res://scenes/shift.tscn"
const CARD := Vector2(2.5, 3.5)          ## the Card3D plane, from card_3d.tscn

func _scene() -> Node3D:
	return (load(SCENE) as PackedScene).instantiate() as Node3D

func test_the_table_has_every_zone_the_controller_expects() -> void:
	var s := _scene()
	for path in ["Table/Carousel/Seat0/Chair0", "Table/Carousel/Seat1/Chair1", "Table/Carousel/Seat2/Chair2",
			"Camera3D/Draw", "Camera3D/Discard", "Camera3D/Hand"]:
		var n := s.get_node_or_null(NodePath(path))
		h.check("%s exists" % path, n != null)
		h.check("%s is a CardCollection3D" % path, n is CardCollection3D)
		h.check("%s kept its DropZone, so it can receive cards" % path,
			n != null and n.get_node_or_null(^"DropZone/CollisionShape3D") != null)
	h.check("a camera to unproject through", s.get_node_or_null(^"Camera3D") is Camera3D)
	h.check("a DragController", s.get_node_or_null(^"DragController") is DragController)
	s.free()

func test_no_hud_control_can_swallow_a_click_meant_for_the_table() -> void:
	## The lint that would have caught G1's floor-card bug. Every Control in the
	## HUD must be IGNORE, except real Buttons and the two overlays that are
	## STOP on purpose because they SHOULD block the table while showing: the
	## report, once the shift is over, and the pull picker, while a reveal is
	## pending (see shift_controller.gd's own drag-lock comment on why nothing
	## else may reach the table then either).
	var s := _scene()
	var hud := s.get_node(^"HUD/HudRoot") as Control
	h.eq("HudRoot itself ignores the mouse", hud.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	var report := hud.get_node(^"ReportOverlay")
	var pull_picker := hud.get_node(^"PullPicker")
	var offenders: Array[String] = []
	for c in _controls_under(hud):
		if c == report or report.is_ancestor_of(c) \
				or c == pull_picker or pull_picker.is_ancestor_of(c) or c is Button:
			continue
		if c.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			offenders.append("%s (%s)" % [c.name, c.get_class()])
	h.check("nothing over the table blocks picking, found: %s" % ", ".join(offenders),
		offenders.is_empty())
	# The Web build showed the report as a box in the corner: saved in POSITION
	# layout mode, the export's binary scene lost its full-rect anchors (see
	# build_shift_scene.gd's _cover_the_hud()). Headless runs load the text
	# scene and never saw it, so this checks the mode itself, not the rect.
	for overlay in [report, pull_picker]:
		h.check("%s is saved in anchors layout mode, so the Web build keeps it full screen (%s)"
			% [overlay.name, overlay.get(&"layout_mode")], overlay.get(&"layout_mode") == 1)
	h.eq("the report overlay does block, deliberately",
		(report as Control).mouse_filter, Control.MOUSE_FILTER_STOP)
	h.check("and starts hidden", not (report as Control).visible)
	h.eq("the pull picker does too, deliberately",
		(pull_picker as Control).mouse_filter, Control.MOUSE_FILTER_STOP)
	h.check("and it also starts hidden", not (pull_picker as Control).visible)
	s.free()

func test_the_hud_carries_everything_the_controller_renders_into() -> void:
	var s := _scene()
	# Addressed by unique name, not by path: the panel layout is expected to keep
	# moving, and the controller looks these up the same way.
	for uname in ["%TickLabel", "%BankedLabel", "%AtRiskLabel", "%EventLog",
			"%ReportOverlay", "%SidePanel", "%PullPicker",
			"%Seat0", "%CustomerFlip0", "%CustomerDetail0", "%Tablet0",
			"%CloseSoonTag0"]:
		h.check("%s exists" % uname, s.get_node_or_null(NodePath(uname)) != null)
	h.check("the event log parses bbcode, which the action log relies on",
		(s.get_node(^"%EventLog") as RichTextLabel).bbcode_enabled)
	h.check("the HUD is a CanvasLayer, so it is not subject to the 3D transform",
		s.get_node_or_null(^"HUD") is CanvasLayer)
	s.free()

func _controls_under(node: Node) -> Array[Control]:
	var out: Array[Control] = []
	for child in node.get_children():
		if child is Control:
			out.append(child)
		out.append_array(_controls_under(child))
	return out

func _find_first(node: Node, cls: String) -> Node:
	for child in node.get_children():
		if child.is_class(cls):
			return child
		var found := _find_first(child, cls)
		if found != null:
			return found
	return null
