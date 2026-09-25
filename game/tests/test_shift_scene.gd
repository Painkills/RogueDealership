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

func test_a_seat_is_one_node_so_the_other_two_can_be_hidden() -> void:
	## Load-bearing. The seats sit close enough together for the floor view to be
	## readable. That used to mean sitting down HID the neighbours; since the
	## carousel it means turning them out to the sides instead. Either way a seat
	## has to be one node rather than four siblings to chase.
	var s := _scene()
	for i in range(3):
		var seat := s.get_node_or_null(NodePath("Table/Carousel/Seat%d" % i)) as Node3D
		h.check("Seat%d is one node" % i, seat != null)
		if seat == null:
			continue
		for child in ["CustomerFlip%d/Customer%d" % [i, i],
				"CustomerFlip%d/CustomerDetail%d" % [i, i],
				"Chair%d" % i, "Tablet%d" % i]:
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
			NodePath("Table/Carousel/Seat%d/CustomerFlip%d" % [i, i])) as Node3D
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
	## The slot's outline sits over the tablet's well, and a slab wider than
	## the card it marks would draw an edge the card does not have.
	var s := _scene()
	for i in range(3):
		var slab := s.get_node(
			NodePath("Table/Carousel/Seat%d/Chair%d/ZoneSlab" % [i, i])) as MeshInstance3D
		h.eq("seat %d's slot is exactly a card, so its visible edge is where the "
			% i + "customer's is", (slab.mesh as QuadMesh).size, CARD)
	s.free()

func test_the_back_of_a_folder_starts_tucked_behind_it() -> void:
	## Hidden by being flush behind an opaque card of its own size, facing the
	## other way - so it is literally that folder's back. No visibility flag to
	## get wrong, and nothing to pop when the framing changes.
	var s := _scene()
	for i in range(3):
		for pair in [["Seat%d/CustomerFlip%d/Customer%d" % [i, i, i],
					"Seat%d/CustomerFlip%d/CustomerDetail%d" % [i, i, i]]]:
			var front := s.get_node(NodePath("Table/Carousel/" + pair[0])) as Node3D
			var detail := s.get_node(NodePath("Table/Carousel/" + pair[1])) as Node3D
			h.check("%s shares its partner's x and y" % detail.name,
				is_equal_approx(front.position.x, detail.position.x)
					and is_equal_approx(front.position.y, detail.position.y))
			h.check("and sits BEHIND it (%.2f < %.2f)"
				% [detail.position.z, front.position.z],
				detail.position.z < front.position.z)
			h.check("facing the other way, so it IS the back of that card (%s)"
				% detail.rotation, is_equal_approx(absf(detail.rotation.y), PI))
	s.free()

func test_the_product_stands_in_the_middle_of_its_tablet() -> void:
	## "The product card shows up in the center" of a tablet, with how it is
	## landing either side of it - the second card that used to slide out
	## beside the product is gone.
	var s := _scene()
	for i in range(3):
		var tablet := s.get_node(NodePath("%%Tablet%d" % i)) as Node3D
		var slot := s.get_node(NodePath("%%Chair%d" % i)) as Node3D
		h.check("seat %d's tablet is a tablet" % i, tablet is OfferTablet)
		h.check("with the slot in the middle of its screen (%s vs %s)"
			% [slot.position, tablet.position],
			is_equal_approx(slot.position.x, tablet.position.x)
				and is_equal_approx(slot.position.y, tablet.position.y))
		h.check("and the tablet just behind the card standing on it (%.2f < %.2f)"
			% [tablet.position.z, slot.position.z], tablet.position.z < slot.position.z)
		# Behind the slot's own outline and highlight too, or they would draw
		# under the screen rather than on it.
		var outline := slot.get_node(^"ZoneSlab") as Node3D
		var highlight := slot.get_node(NodePath("CloseHint%d/Slab" % i)) as Node3D
		for pair in [["outline", slot.position.z + outline.position.z],
				["highlight", slot.position.z + (highlight.get_parent() as Node3D).position.z
					+ highlight.position.z]]:
			h.check("and behind the slot's %s (%.2f < %.2f)"
				% [pair[0], tablet.position.z, pair[1]], tablet.position.z < pair[1])
		h.check("starting switched off - it only comes on at the desk you sit at",
			not tablet.visible)
		h.check("and no second card behind the product any more",
			s.get_node_or_null(NodePath("%%OfferDetail%d" % i)) == null)
	s.free()

func test_the_tablet_stands_on_the_desk() -> void:
	## Level in the world, the desk; leaning back to face the lens, the tablet -
	## so its bottom edge is measured in the DESK's frame, the way a stand
	## would rest it on the desk top.
	var s := _scene()
	for i in range(3):
		var seat := s.get_node(NodePath("%%Seat%d" % i)) as Node3D
		var desk := seat.get_node(NodePath("Desk%d" % i)) as Node3D
		var top := desk.get_node(^"Top") as MeshInstance3D
		var top_size: Vector3 = (top.mesh as BoxMesh).size
		var desk_top: float = top.position.y + top_size.y * 0.5
		var tablet := seat.get_node(NodePath("Tablet%d" % i)) as Node3D
		var lowest := INF
		for x in [-0.5, 0.5]:
			var corner: Vector3 = tablet.position \
				+ Vector3(OfferTablet.SIZE.x * x, -OfferTablet.SIZE.y * 0.5, 0.0)
			lowest = minf(lowest, (desk.transform.affine_inverse() * corner).y)
		h.check("seat %d's tablet rests on the desk top, not through it (%.3f vs %.3f)"
			% [i, lowest, desk_top], lowest >= desk_top - 0.001)
		h.check("nor floating above it (%.3f vs %.3f)" % [lowest, desk_top],
			lowest <= desk_top + 0.06)
		h.check("and the desk is wider than the tablet on it (%.2f > %.2f)"
			% [top_size.x, OfferTablet.SIZE.x], top_size.x > OfferTablet.SIZE.x + 0.2)
		# The customer's folder floats above the desk; the tablet must stop
		# short of it.
		var flip := seat.get_node(NodePath("CustomerFlip%d" % i)) as Node3D
		var folder_bottom: float = flip.position.y - CustomerCard3D.CARD_SIZE.y * 0.5
		var tablet_top: float = tablet.position.y + OfferTablet.SIZE.y * 0.5
		h.check("and it stops short of their folder (%.2f < %.2f)"
			% [tablet_top, folder_bottom], tablet_top < folder_bottom - 0.1)
	s.free()

func test_the_chair_is_a_chair_at_the_desks_scale() -> void:
	## "The chair needs to be much smaller. The seat of the chair should not be
	## above the tabletop." It was a slab as wide as their folder, and then an
	## office chair whose seat stood higher than the desk.
	var s := _scene()
	for i in range(3):
		var desk := s.get_node(NodePath("Table/Carousel/Seat%d/Desk%d" % [i, i])) as Node3D
		var top := desk.get_node(^"Top") as MeshInstance3D
		var desk_top: float = top.position.y + (top.mesh as BoxMesh).size.y * 0.5
		var seat := desk.get_node(^"ChairSeat") as MeshInstance3D
		var seat_top: float = seat.position.y + (seat.mesh as BoxMesh).size.y * 0.5
		h.check("seat %d's chair seat is below the desk top (%.2f < %.2f)"
			% [i, seat_top, desk_top], seat_top < desk_top - 0.5)
		var back := desk.get_node(^"ChairBack") as MeshInstance3D
		var capsule := back.mesh as CapsuleMesh
		var back_top: float = back.position.y + capsule.height * 0.5
		h.check("its back tops out a little above the desk, not over the room (%.2f)"
			% (back_top - desk_top), back_top > desk_top and back_top < desk_top + 1.0)
		var width: float = capsule.radius * 2.0 * back.scale.x
		h.check("and it is narrower than half their folder (%.2f)" % width,
			width < CustomerCard3D.CARD_SIZE.x * 0.5)
		# A back taller than it is wide reads as a chair back; one as wide as it
		# is tall read as a ball peering over the desk.
		h.check("and taller than it is wide (%.2f x %.2f)" % [width, capsule.height],
			capsule.height > width)
	s.free()

func test_close_soon_hangs_from_the_seat_so_the_folder_can_turn_under_it() -> void:
	## A CLOSE SOON riding the folder turned over with it and vanished every
	## time you flipped it to read the back. The seat never turns.
	var s := _scene()
	for i in range(3):
		var seat := s.get_node(NodePath("%%Seat%d" % i)) as Node3D
		var corner := seat.get_node_or_null(NodePath("CloseSoonAnchor%d" % i)) as Node3D
		h.check("seat %d has a CLOSE SOON corner" % i, corner != null)
		if corner == null:
			continue
		var flip := seat.get_node(NodePath("CustomerFlip%d" % i)) as Node3D
		h.check("on the seat, not on the folder that turns over",
			corner.get_parent() == seat and not flip.is_ancestor_of(corner))
		var half := CustomerCard3D.CARD_SIZE * 0.5
		h.check("in the folder's top-right corner (%s)" % corner.position,
			is_equal_approx(corner.position.y, flip.position.y + half.y)
				and corner.position.x > 0.0 and corner.position.x < half.x)
		var tag := s.get_node(NodePath("%%CloseSoonTag%d" % i)) as Control
		h.check("with its tag on the HUD", tag is ScreenTag
			and s.get_node(^"HUD").is_ancestor_of(tag))
		h.eq("following that corner", tag.get(&"anchor_path"),
			NodePath("Table/Carousel/Seat%d/CloseSoonAnchor%d" % [i, i]))
		h.eq("and hanging from its right-hand edge", tag.get(&"hang"), 1.0)
		h.check("and nothing of the old sticky notes is left",
			s.get_node_or_null(NodePath("%%CloseSoonFlag%d" % i)) == null
				and s.get_node_or_null(NodePath("%%OfferFlag%d" % i)) == null)
	s.free()

func test_a_customer_is_a_folder_and_its_back_is_the_same_folder() -> void:
	## A customer's card is a landscape file folder, wider than a product card
	## so its interest grid has room to be read. Its back has to be the same
	## shape - a back that is not the same shape as its front is not a back -
	## and so does the pad that answers the pointer over it.
	var s := _scene()
	h.check("a customer's folder is wider than tall",
		CustomerCard3D.CARD_SIZE.x > CustomerCard3D.CARD_SIZE.y)
	h.eq("and the same height as every other card, so the rows still line up",
		CustomerCard3D.CARD_SIZE.y, CARD.y)
	for i in range(3):
		var back := s.get_node(NodePath("%%CustomerDetail%d" % i))
		h.eq("seat %d's back is folder-sized" % i, back.get(&"card_size"),
			CustomerCard3D.CARD_SIZE)
		h.eq("with a face as wide as the folder's", back.get(&"face_size"),
			CustomerCard3D.FRONT_SIZE)
		var pad := s.get_node(NodePath("%%HoverPad%d/CollisionShape3D" % i)) as CollisionShape3D
		var box := pad.shape as BoxShape3D
		h.eq("and the pad over it covers the whole folder",
			Vector2(box.size.x, box.size.y), CustomerCard3D.CARD_SIZE)
	h.check("the face is laid out at the folder's own aspect",
		is_equal_approx(float(CustomerCard3D.FRONT_SIZE.x) / CustomerCard3D.FRONT_SIZE.y,
			CustomerCard3D.CARD_SIZE.x / CustomerCard3D.CARD_SIZE.y))
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
		var flip := s.get_node(NodePath("Table/Carousel/Seat%d/CustomerFlip%d" % [i, i])) as Node3D
		var who := s.get_node(NodePath("Table/Carousel/Seat%d/CustomerFlip%d/Customer%d"
			% [i, i, i])) as Node3D
		var chair := s.get_node(NodePath("Table/Carousel/Seat%d/Chair%d" % [i, i])) as Node3D
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
		for theirs in ["Chair%d" % i, "Tablet%d" % i,
				"CustomerFlip%d/Customer%d" % [i, i],
				"CustomerFlip%d/CustomerDetail%d" % [i, i]]:
			h.check("%s belongs to the world, not to you" % theirs,
				s.get_node(NodePath("Table/Carousel/Seat%d/%s" % [i, theirs])).get_parent() != cam)
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
	## camera. With the felt at z=-1.2 and the seat camera at z=9 that put the
	## hand at -2 - BEHIND the table. It rose into view during the camera's
	## approach and then slid behind the felt and vanished, which read as "the
	## hand pops up for an instant". The felt is the office's back wall now.
	var s := _scene()
	var wall_z: float = (s.get_node(^"Wall") as Node3D).position.z
	var hand_local: Vector3 = (s.get_node(^"Camera3D/Hand") as Node3D).position
	for name in ["CameraFloor", "SeatCam"]:
		# Through the framing's whole transform, since the camera looks down.
		var hand_world: Vector3 = (s.get_node(NodePath(name)) as Node3D).transform \
			* hand_local
		h.check("from %s the hand sits in front of the wall (%.1f > %.1f)"
			% [name, hand_world.z, wall_z], hand_world.z > wall_z)
	s.free()

func test_the_cards_still_face_the_lens_square_on() -> void:
	## These cards are flat quads with 500x700 of text rendered into them, and a
	## card tilted against the lens foreshortens the exact thing the whole view
	## exists to make legible. The cameras used to be dead level for that
	## reason. They look down now, so the desks read as desks - and every seat
	## leans back by EXACTLY the same angle, which keeps each card square to the
	## lens. Either half without the other puts the text at an angle.
	var s := _scene()
	var pitch: Vector3 = (s.get_node(^"Camera3D") as Node3D).rotation
	h.check("the camera looks down at the desks (%.1f degrees)" % rad_to_deg(pitch.x),
		pitch.x < -deg_to_rad(2.0))
	h.check("without turning or rolling (%s)" % pitch,
		is_zero_approx(pitch.y) and is_zero_approx(pitch.z))
	for name in ["CameraFloor", "SeatCam"]:
		var r: Vector3 = (s.get_node(NodePath(name)) as Node3D).rotation
		h.check("%s looks down at the same angle (%s)" % [name, r], r.is_equal_approx(pitch))
	for i in range(3):
		var seat := s.get_node(NodePath("Table/Carousel/Seat%d" % i)) as Node3D
		h.check("seat %d leans back by exactly the camera's pitch (%s)" % [i, seat.rotation],
			seat.rotation.is_equal_approx(pitch))
		# The desk cancels the lean, or its top would slope away from you.
		var desk := seat.get_node_or_null(NodePath("Desk%d" % i)) as Node3D
		h.check("seat %d has a desk" % i, desk != null)
		if desk != null:
			var level: Basis = seat.transform.basis * desk.transform.basis
			h.check("and the desk stands level in the world (%s)" % level.get_euler(),
				level.get_euler().is_zero_approx())
	s.free()

func test_each_seat_has_a_customer_card_under_the_carousel() -> void:
	var s := _scene()
	var root := "Table/Carousel"
	h.check("the seats hang off something that turns",
		s.get_node_or_null(NodePath(root)) is Node3D)
	for i in range(3):
		var seat := "%s/Seat%d" % [root, i]
		var who := s.get_node_or_null(NodePath("%s/CustomerFlip%d/Customer%d" % [seat, i, i]))
		h.check("Customer%d exists" % i, who != null)
		h.check("Customer%d is a customer card" % i, who is CustomerCard3D)
		h.check("CustomerDetail%d is a detail card" % i,
			s.get_node_or_null(NodePath("%s/CustomerFlip%d/CustomerDetail%d" % [seat, i, i]))
				is DetailCard3D)
		h.check("Tablet%d is a tablet" % i,
			s.get_node_or_null(NodePath("%s/Tablet%d" % [seat, i])) is OfferTablet)
	h.check("one seat framing, because the table turns and the camera does not",
		s.get_node_or_null(^"SeatCam") is Marker3D)
	h.check("and a floor framing to return to", s.get_node_or_null(^"CameraFloor") is Marker3D)
	s.free()

func test_the_seats_sit_on_a_circle_at_120_degrees_to_each_other() -> void:
	## The whole composition rests on this: an equal-sided triangle is what puts
	## the two you are not with symmetrically left and right of the one you are.
	var s := _scene()
	var seats: Array[Vector3] = []
	for i in range(3):
		seats.append((s.get_node(NodePath("Table/Carousel/Seat%d" % i)) as Node3D).position)
	var r: float = seats[0].length()
	h.check("the circle has a real radius (%.2f)" % r, r > 1.0)
	for i in range(3):
		h.check("seat %d is on it (%.2f)" % [i, seats[i].length()],
			absf(seats[i].length() - r) < 0.01)
		var next: Vector3 = seats[(i + 1) % 3]
		var angle := rad_to_deg(seats[i].signed_angle_to(next, Vector3.UP))
		h.check("and 120 degrees from the next (%.1f)" % angle,
			absf(absf(angle) - 120.0) < 0.5)
	h.check("seat 0 starts fronted, so an unturned carousel is a valid view",
		seats[0].x == 0.0 and seats[0].z > 0.0)
	s.free()

func test_fronting_a_seat_puts_the_other_two_either_side_of_it() -> void:
	## Not a claim about pixels - a claim about the arrangement. At every station
	## the flankers straddle the front seat, and they never both land on one side.
	var s := _scene()
	var seats: Array[Vector3] = []
	for i in range(3):
		seats.append((s.get_node(NodePath("Table/Carousel/Seat%d" % i)) as Node3D).position)
	for at in range(3):
		# The scene root IS the controller, so its static station_for is right here.
		var turn: float = s.station_for(at)
		var spun: Array[Vector3] = []
		for p in seats:
			spun.append(p.rotated(Vector3.UP, turn))
		h.check("at station %d the front seat is centred (%.2f)" % [at, spun[at].x],
			absf(spun[at].x) < 0.01)
		h.check("at station %d it is also the nearest" % at,
			spun[at].z > spun[(at + 1) % 3].z and spun[at].z > spun[(at + 2) % 3].z)
		h.check("at station %d one flanker is right" % at, spun[(at + 1) % 3].x > 1.0)
		h.check("at station %d the other is left" % at, spun[(at + 2) % 3].x < -1.0)
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
	for path in ["Table/Carousel/Seat0/Chair0", "Camera3D/Draw", "Camera3D/Discard"]:
		h.check("%s stacks" % path,
			(s.get_node(NodePath(path)) as CardCollection3D).card_layout_strategy is PileCardLayout)
	s.free()

func test_the_cards_have_something_to_sit_on_and_something_to_light_them() -> void:
	## Without these the cards float on a flat fill and read as decals. The
	## reference example stages a lit surface for exactly this reason. It is an
	## office now: a back wall, a floor, and a desk at every seat.
	var s := _scene()
	var wall := s.get_node_or_null(^"Wall") as MeshInstance3D
	h.check("there is a back wall", wall != null)
	h.check("big enough to fill the shot", wall != null and wall.mesh is QuadMesh
		and (wall.mesh as QuadMesh).size.x >= 30.0)
	h.check("sitting behind the cards, not through them", wall.position.z < 0.0)
	var ground := s.get_node_or_null(^"Floor") as MeshInstance3D
	h.check("and a floor, below every desk", ground != null)
	for i in range(3):
		var desk := s.get_node_or_null(NodePath("Table/Carousel/Seat%d/Desk%d" % [i, i]))
		h.check("seat %d has a desk to sit at" % i, desk != null)
		h.check("and it collides with nothing, so it can never take a click",
			desk != null and _find_first(desk, "CollisionObject3D") == null)
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
			"%ReportOverlay", "%SidePanel", "%ActionBar", "%PullPicker",
			"%Seat0", "%CustomerFlip0", "%CustomerDetail0", "%Tablet0",
			"%CloseSoonTag0"]:
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
