extends RefCounted
## Structure of the table scene, checked without putting it in a tree.
##
## instantiate() builds the whole node tree, so names, types, parenting and
## mouse filters are all assertable headlessly. Anything needing _ready() lives
## in tools/drive_shift.gd instead, because run_tests.gd works inside _init()
## where _ready() has not fired yet.
var h: Harness

const SCENE := "res://scenes/shift.tscn"

func _scene() -> Node3D:
	return (load(SCENE) as PackedScene).instantiate() as Node3D

func test_the_table_has_every_zone_the_controller_expects() -> void:
	var s := _scene()
	for path in ["Table/Chair0", "Table/Chair1", "Table/Chair2",
			"Table/Draw", "Table/Discard", "Table/Hand"]:
		var n := s.get_node_or_null(NodePath(path))
		h.check("%s exists" % path, n != null)
		h.check("%s is a CardCollection3D" % path, n is CardCollection3D)
		h.check("%s kept its DropZone, so it can receive cards" % path,
			n != null and n.get_node_or_null(^"DropZone/CollisionShape3D") != null)
	h.check("a camera to unproject through", s.get_node_or_null(^"Camera3D") is Camera3D)
	h.check("a DragController", s.get_node_or_null(^"DragController") is DragController)
	s.free()

func test_the_hand_fans_and_the_piles_stack() -> void:
	## A fan, following example_battle's staging. FanCardLayout also exports its
	## arc, so unlike LineCardLayout.max_width those values survive packing.
	var s := _scene()
	var fan := (s.get_node(^"Table/Hand") as CardCollection3D).card_layout_strategy
	h.check("hand fans", fan is FanCardLayout)
	h.check("with an arc that actually spread", (fan as FanCardLayout).arc_angle_deg > 0.0)
	h.check("and a radius", (fan as FanCardLayout).arc_radius > 0.0)
	for path in ["Table/Chair0", "Table/Draw", "Table/Discard"]:
		h.check("%s stacks" % path,
			(s.get_node(NodePath(path)) as CardCollection3D).card_layout_strategy is PileCardLayout)
	s.free()

func test_the_cards_have_something_to_sit_on_and_something_to_light_them() -> void:
	## Without these the cards float on a flat fill and read as decals. The
	## reference example stages a lit surface for exactly this reason.
	var s := _scene()
	var felt := s.get_node_or_null(^"Felt") as MeshInstance3D
	h.check("there is a table surface", felt != null)
	h.check("big enough to fill the shot", felt != null and felt.mesh is QuadMesh
		and (felt.mesh as QuadMesh).size.x >= 30.0)
	h.check("sitting behind the cards, not through them", felt.position.z < 0.0)
	var light := s.get_node_or_null(^"DirectionalLight3D") as DirectionalLight3D
	h.check("there is a key light", light != null)
	h.check("casting shadows, so cards sit ON the table", light != null and light.shadow_enabled)
	s.free()

func test_the_background_is_the_environment_not_a_control() -> void:
	## G1 painted the background with a full-rect ColorRect. Under a 3D table
	## that single node would make every card in the game unclickable, because
	## Godot resolves Control GUI input before physics picking and ColorRect
	## defaults to MOUSE_FILTER_STOP.
	var s := _scene()
	var we := s.get_node_or_null(^"WorldEnvironment") as WorldEnvironment
	h.check("there is a WorldEnvironment", we != null)
	h.check("painting a flat colour", we != null and we.environment != null
		and we.environment.background_mode == Environment.BG_COLOR)
	h.eq("in a palette role, not a hex literal", we.environment.background_color,
		Palette.color(&"neutral_1"))
	# Scoped to the HUD on purpose: card faces legitimately use ColorRects inside
	# their own SubViewport, where nothing can be in front of the table.
	h.check("and no ColorRect is left covering the HUD",
		_find_first(s.get_node(^"HUD"), "ColorRect") == null)
	s.free()

func test_no_hud_control_can_swallow_a_click_meant_for_the_table() -> void:
	## The lint that would have caught G1's floor-card bug. Every Control in the
	## HUD must be IGNORE, except real Buttons and the report overlay - which is
	## STOP on purpose, since it SHOULD block the table once the shift is over.
	var s := _scene()
	var hud := s.get_node(^"HUD/HudRoot") as Control
	h.eq("HudRoot itself ignores the mouse", hud.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	var report := hud.get_node(^"ReportOverlay")
	var offenders: Array[String] = []
	for c in _controls_under(hud):
		if c == report or report.is_ancestor_of(c) or c is Button:
			continue
		if c.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			offenders.append("%s (%s)" % [c.name, c.get_class()])
	h.check("nothing over the table blocks picking, found: %s" % ", ".join(offenders),
		offenders.is_empty())
	h.eq("the report overlay does block, deliberately",
		(report as Control).mouse_filter, Control.MOUSE_FILTER_STOP)
	h.check("and starts hidden", not (report as Control).visible)
	s.free()

func test_the_hud_carries_everything_the_controller_renders_into() -> void:
	var s := _scene()
	for path in ["HUD/HudRoot/TopBar/TickLabel", "HUD/HudRoot/TopBar/BankedLabel",
			"HUD/HudRoot/TopBar/AtRiskLabel", "HUD/HudRoot/CustomerSlot",
			"HUD/HudRoot/CustomerSlot/EmptySlotLabel", "HUD/HudRoot/EventLog",
			"HUD/HudRoot/ReportOverlay"]:
		h.check("%s exists" % path, s.get_node_or_null(NodePath(path)) != null)
	h.check("the event log parses bbcode, which the action log relies on",
		(s.get_node(^"HUD/HudRoot/EventLog") as RichTextLabel).bbcode_enabled)
	h.check("the HUD is a CanvasLayer, so it is not subject to the 3D transform",
		s.get_node_or_null(^"HUD") is CanvasLayer)
	s.free()

func test_the_floor_row_container_is_gone() -> void:
	## Floor cards are positioned by unproject_position() now. A Container would
	## overwrite position on every layout pass and fight the camera.
	var s := _scene()
	h.check("no FloorRow", s.get_node_or_null(^"HUD/HudRoot/FloorRow") == null)
	h.check("no HandRow either - the hand is on the table now",
		s.get_node_or_null(^"HUD/HudRoot/HandRow") == null)
	s.free()

func test_a_floor_card_only_blocks_the_mouse_where_its_button_is() -> void:
	## Floor cards are instantiated at runtime so the scene lint above never sees
	## them - but they float over the table, and one of them shipped the exact
	## bug this checks: HoverPanel is revealed by hovering the card it covers, so
	## as a STOP node it swallowed the very click that revealed it.
	var fc := (load("res://scenes/floor_card.tscn") as PackedScene).instantiate() as Control
	h.eq("the panel itself lets the mouse through", fc.mouse_filter,
		Control.MOUSE_FILTER_IGNORE)
	var offenders: Array[String] = []
	for c in _controls_under(fc):
		if c is Button:
			continue
		if c.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			offenders.append("%s (%s)" % [c.name, c.get_class()])
	h.check("only its button blocks, found: %s" % ", ".join(offenders), offenders.is_empty())
	h.check("and it does have a button to click", _find_first(fc, "Button") != null)
	fc.free()

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
