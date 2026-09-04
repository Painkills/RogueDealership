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
	for path in ["Table/Seat0/Chair0", "Table/Seat1/Chair1", "Table/Seat2/Chair2",
			"Camera3D/Draw", "Camera3D/Discard", "Camera3D/Hand"]:
		var n := s.get_node_or_null(NodePath(path))
		h.check("%s exists" % path, n != null)
		h.check("%s is a CardCollection3D" % path, n is CardCollection3D)
		h.check("%s kept its DropZone, so it can receive cards" % path,
			n != null and n.get_node_or_null(^"DropZone/CollisionShape3D") != null)
	h.check("a camera to unproject through", s.get_node_or_null(^"Camera3D") is Camera3D)
	h.check("a DragController", s.get_node_or_null(^"DragController") is DragController)
	s.free()

func test_a_seat_is_one_node_so_the_other_two_can_be_hidden() -> void:
	## Load-bearing. The seats sit close enough together for the floor view to be
	## readable, which means the neighbours are inside the seat framing whether
	## you like it or not - so sitting down hides them, and that has to be one
	## flag rather than a hunt through four siblings each time.
	var s := _scene()
	for i in range(3):
		var seat := s.get_node_or_null(NodePath("Table/Seat%d" % i)) as Node3D
		h.check("Seat%d is one node" % i, seat != null)
		if seat == null:
			continue
		for child in ["CustomerFlip%d/Customer%d" % [i, i],
				"CustomerFlip%d/CustomerDetail%d" % [i, i],
				"Chair%d" % i, "OfferDetail%d" % i]:
			h.check("%s hangs off it, so hiding the seat hides it too" % child,
				seat.get_node_or_null(NodePath(child)) != null)
	s.free()

func test_a_customer_and_their_sheet_turn_over_together() -> void:
	## Flipping the two cards INDIVIDUALLY cannot work: the front card is still
	## the front card afterwards, so all you would see is its own back. The pair
	## has to turn, which is what putting them under one node buys.
	var s := _scene()
	for i in range(3):
		var flip := s.get_node_or_null(
			NodePath("Table/Seat%d/CustomerFlip%d" % [i, i])) as Node3D
		h.check("CustomerFlip%d exists" % i, flip != null)
		h.check("and it is the thing that knows how to turn over",
			flip != null and flip.has_method("show_back"))
		h.check("holding both halves of the pair", flip != null
			and flip.get_node_or_null(NodePath("Customer%d" % i)) != null
			and flip.get_node_or_null(NodePath("CustomerDetail%d" % i)) != null)
		h.check("and starting face-front", flip != null
			and flip.rotation.is_equal_approx(Vector3.ZERO))
	s.free()

func test_every_slot_is_exactly_one_card_wide() -> void:
	## "There should be an equal margin between the main cards and the detail
	## cards for both product and customer." The detail comes out by one fixed
	## offset, so the margins can only differ if the two slots are different
	## widths - and the product's marker slab used to be wider than its card.
	var s := _scene()
	for i in range(3):
		var slab := s.get_node(
			NodePath("Table/Seat%d/Chair%d/ZoneSlab" % [i, i])) as MeshInstance3D
		h.eq("seat %d's slot is exactly a card, so its visible edge is where the "
			% i + "customer's is", (slab.mesh as QuadMesh).size, CARD)
	s.free()

func test_the_detail_cards_start_tucked_behind_their_partner() -> void:
	## "The detail cards are hidden behind the main card." Hidden by being flush
	## behind an opaque card of its own size, facing the other way - so it is
	## literally that card's back. No visibility flag to get wrong, and nothing to
	## pop when the framing changes.
	var s := _scene()
	for i in range(3):
		for pair in [["Seat%d/CustomerFlip%d/Customer%d" % [i, i, i],
					"Seat%d/CustomerFlip%d/CustomerDetail%d" % [i, i, i]],
				["Seat%d/Chair%d" % [i, i], "Seat%d/OfferDetail%d" % [i, i]]]:
			var front := s.get_node(NodePath("Table/" + pair[0])) as Node3D
			var detail := s.get_node(NodePath("Table/" + pair[1])) as Node3D
			h.check("%s shares its partner's x and y" % detail.name,
				is_equal_approx(front.position.x, detail.position.x)
					and is_equal_approx(front.position.y, detail.position.y))
			h.check("and sits BEHIND it (%.2f < %.2f)"
				% [detail.position.z, front.position.z],
				detail.position.z < front.position.z)
			h.check("facing the other way, so it IS the back of that card (%s)"
				% detail.rotation, is_equal_approx(absf(detail.rotation.y), PI))
	s.free()

func test_a_detail_card_slides_completely_clear_of_what_it_describes() -> void:
	## The bug this replaces: a shared HUD panel positioned by arithmetic, which
	## kept landing on top of the product it was describing. Now it is geometry -
	## and geometry can be checked.
	var s := _scene()
	var gap: float = absf(DetailCard3D.SLIDE_OUT.x) \
		- (CARD.x * 0.5 + DetailCard3D.CARD_SIZE.x * 0.5)
	h.check("slid out, the detail card clears its partner by %.2f" % gap, gap > 0.0)
	h.check("and it goes LEFT, which is the side the seat framing leaves room on",
		DetailCard3D.SLIDE_OUT.x < 0.0)
	var mesh := (s.get_node(^"%CustomerDetail0/CardMesh/CardFrontMesh")
		as MeshInstance3D).mesh as PlaneMesh
	h.eq("and the quad really is the size the slide assumes",
		mesh.size, DetailCard3D.CARD_SIZE)
	h.eq("which is the size of the card it hides behind", DetailCard3D.CARD_SIZE, CARD)
	s.free()

func test_the_customer_row_cannot_overlap_the_product_row() -> void:
	## The reported bug: "when zoomed in, the customer card gets overlapped by the
	## product card". It was caused by the customer card scaling up by a third and
	## unhiding a detail block, which drove it down into the slot below. Both are
	## gone, and this pins the clearance that made them possible.
	var s := _scene()
	for i in range(3):
		# Seat-local, summed by hand: the customer now hangs off the flip node, so
		# its own position.y is zero and comparing the two raw locals would say
		# the rows are on top of each other whatever the layout does.
		var flip := s.get_node(NodePath("Table/Seat%d/CustomerFlip%d" % [i, i])) as Node3D
		var who := s.get_node(NodePath("Table/Seat%d/CustomerFlip%d/Customer%d"
			% [i, i, i])) as Node3D
		var chair := s.get_node(NodePath("Table/Seat%d/Chair%d" % [i, i])) as Node3D
		var apart: float = absf(flip.position.y + who.position.y - chair.position.y)
		h.check("seat %d keeps the two rows %.2f apart, clear of a %.2f card"
			% [i, apart, CARD.y], apart > CARD.y)
		h.check("and the customer card is unscaled, so it stays that way",
			who.scale.is_equal_approx(Vector3.ONE))
	s.free()

func test_your_things_are_parented_to_the_camera_and_theirs_are_not() -> void:
	## The load-bearing structural idea: the camera IS the player. Hand, draw and
	## discard ride with it, so moving to a seat carries them for free.
	var s := _scene()
	var cam := s.get_node(^"Camera3D")
	for mine in ["Hand", "Draw", "Discard"]:
		h.check("%s belongs to the player, so it hangs off the camera" % mine,
			s.get_node(NodePath("Camera3D/" + mine)).get_parent() == cam)
	for i in range(3):
		for theirs in ["Chair%d" % i, "OfferDetail%d" % i,
				"CustomerFlip%d/Customer%d" % [i, i],
				"CustomerFlip%d/CustomerDetail%d" % [i, i]]:
			h.check("%s belongs to the world, not to you" % theirs,
				s.get_node(NodePath("Table/Seat%d/%s" % [i, theirs])).get_parent() != cam)
	s.free()

func test_your_things_start_stowed_below_the_frame() -> void:
	## The floor view shows customers and nothing of yours. These sit below the
	## bottom of frame at their own depth and tween up only once you sit down.
	## Read from the scene, not from a literal: a depth change must move this.
	var s := _scene()
	var fov: float = (s.get_node(^"Camera3D") as Camera3D).fov
	for mine in ["Hand", "Draw", "Discard"]:
		var z := s.get_node(NodePath("Camera3D/" + mine)) as Node3D
		var half_height: float = absf(z.position.z) * tan(deg_to_rad(fov * 0.5))
		h.check("%s sits in front of the camera" % mine, z.position.z < 0.0)
		# The card TOP has to clear the frame, not the card's origin, or a stowed
		# pile still shows its top edge along the bottom of the screen.
		h.check("%s starts fully out of shot (top %.1f, frame bottom %.1f)"
			% [mine, z.position.y + CARD.y * 0.5, -half_height],
			z.position.y + CARD.y * 0.5 < -half_height)
	s.free()

func test_your_hand_is_never_behind_the_table() -> void:
	## The bug this catches: the hand rides at a fixed depth IN FRONT of the
	## camera, so its world Z is camera_z + depth. With the felt at z=-1.2 and the
	## seat camera at z=9 that put the hand at -2 - BEHIND the table. It rose into
	## view during the camera's approach and then slid behind the felt and
	## vanished, which read as "the hand pops up for an instant".
	var s := _scene()
	var felt_z: float = (s.get_node(^"Felt") as Node3D).position.z
	var depth: float = (s.get_node(^"Camera3D/Hand") as Node3D).position.z   # negative
	for name in ["CameraFloor", "SeatCam0", "SeatCam1", "SeatCam2"]:
		var cam_z: float = (s.get_node(NodePath(name)) as Node3D).position.z
		var hand_world_z: float = cam_z + depth
		h.check("from %s the hand sits in front of the felt (%.1f > %.1f)"
			% [name, hand_world_z, felt_z], hand_world_z > felt_z)
	s.free()

func test_the_cameras_are_flat_on() -> void:
	## These cards are flat quads with 500x700 of text rendered into them. Any
	## tilt foreshortens the exact thing the whole view exists to make legible,
	## and legibility is what three rounds of this have been about.
	var s := _scene()
	for name in ["CameraFloor", "SeatCam0", "SeatCam1", "SeatCam2", "Camera3D"]:
		var r: Vector3 = (s.get_node(NodePath(name)) as Node3D).rotation
		h.check("%s looks straight at the cards (%s)" % [name, r],
			r.is_equal_approx(Vector3.ZERO))
	s.free()

func test_each_seat_has_a_customer_card_and_a_framing() -> void:
	var s := _scene()
	for i in range(3):
		var who := s.get_node_or_null(NodePath("Table/Seat%d/CustomerFlip%d/Customer%d" % [i, i, i]))
		h.check("Customer%d exists" % i, who != null)
		h.check("Customer%d is a customer card" % i, who is CustomerCard3D)
		h.check("CustomerDetail%d is a detail card" % i,
			s.get_node_or_null(NodePath("Table/Seat%d/CustomerFlip%d/CustomerDetail%d" % [i, i, i]))
				is DetailCard3D)
		h.check("OfferDetail%d is a detail card" % i,
			s.get_node_or_null(NodePath("Table/Seat%d/OfferDetail%d" % [i, i]))
				is DetailCard3D)
		h.check("SeatCam%d exists to frame them" % i,
			s.get_node_or_null(NodePath("SeatCam%d" % i)) is Marker3D)
	h.check("and a floor framing to return to", s.get_node_or_null(^"CameraFloor") is Marker3D)
	s.free()

func test_the_log_stops_short_of_the_bottom_strip() -> void:
	## The discard rises into the bottom of the screen when you sit down. A log
	## that reached the bottom would sit on top of it.
	var s := _scene()
	var log_panel := s.get_node(^"%SidePanel") as Control
	h.check("the log ends well above the bottom (%d of 1080)"
		% int(log_panel.position.y + log_panel.size.y),
		log_panel.position.y + log_panel.size.y <= 760.0)
	s.free()

func test_the_hand_fans_and_the_piles_stack() -> void:
	## A fan, following example_battle's staging. FanCardLayout also exports its
	## arc, so unlike LineCardLayout.max_width those values survive packing.
	var s := _scene()
	var fan := (s.get_node(^"Camera3D/Hand") as CardCollection3D).card_layout_strategy
	h.check("hand fans", fan is FanCardLayout)
	h.check("with an arc that actually spread", (fan as FanCardLayout).arc_angle_deg > 0.0)
	h.check("and a radius", (fan as FanCardLayout).arc_radius > 0.0)
	for path in ["Table/Seat0/Chair0", "Camera3D/Draw", "Camera3D/Discard"]:
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
	# Addressed by unique name, not by path: the panel layout is expected to keep
	# moving, and the controller looks these up the same way.
	for uname in ["%TickLabel", "%BankedLabel", "%AtRiskLabel", "%EventLog",
			"%ReportOverlay", "%SidePanel", "%ModeButton", "%ActionBar",
			"%Seat0", "%CustomerFlip0", "%CustomerDetail0", "%OfferDetail0"]:
		h.check("%s exists" % uname, s.get_node_or_null(NodePath(uname)) != null)
	h.check("the event log parses bbcode, which the action log relies on",
		(s.get_node(^"%EventLog") as RichTextLabel).bbcode_enabled)
	h.check("the HUD is a CanvasLayer, so it is not subject to the 3D transform",
		s.get_node_or_null(^"HUD") is CanvasLayer)
	s.free()

func test_the_hud_no_longer_owns_any_of_the_table() -> void:
	## Everything the HUD used to say about a customer or a product is on a card
	## now. Two surfaces describing one customer is how the data went missing in
	## the first place, and a panel over the table is how the clicks went missing.
	var s := _scene()
	for gone in ["HUD/HudRoot/FloorRow", "HUD/HudRoot/HandRow",
			"HUD/HudRoot/OfferPanel0", "HUD/HudRoot/CustomerPanel"]:
		h.check("no %s" % gone, s.get_node_or_null(NodePath(gone)) == null)
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
