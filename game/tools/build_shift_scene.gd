extends SceneTree
## Builds res://scenes/shift.tscn.
##
## THE CAMERA IS THE PLAYER. Your hand, your draw pile and your discard are
## children of Camera3D, parked below the bottom of frame. They travel with you
## for free, and arriving at a seat only has to tween them up in camera-local
## space.
##
## EVERYTHING IS A CARD, AND EVERY CARD HAS A BACK. A seat is four of them: the
## customer, a detail card tucked behind the customer facing the other way, the
## product slot, and a detail card tucked behind that. Hovering a customer on
## the floor turns the PAIR over, so the detail really is the back of the card.
## Sitting down slides both detail cards out to the LEFT and turns them
## face-front, so you have both halves side by side.
##
## Both cards of a pair are the same size, which is not decoration: a back that
## is not the same shape as its front is not a back, and equal widths are what
## make the customer's margin and the product's margin equal BY CONSTRUCTION
## rather than by two numbers happening to agree.
##
## THE TABLE IS A CAROUSEL AND THE CAMERA BARELY MOVES. The three seats sit on
## a circle; approaching someone spins the circle until they are at the front,
## and the other two fall away to either side, smaller by honest perspective
## rather than by being scaled. Nobody is ever hidden.
##
## THE LENS IS WHAT MAKES THAT POSSIBLE, and it is worth knowing why before
## touching CAM_FOV. With seats on a circle of radius R and the camera at
## radius D, near depth N = D-R and far depth F = D+R/2:
##
##     flanker_offset_px = 0.866 x R x K / F      where K = 540 / tan(fov/2)
##     flanker_height / active_height = N / F
##
## Eliminate R and D and one identity falls out:
##
##     K = 1.7324 x offset_px / (1 - h_far/h_near)
##
## The flankers' distance from the centre of screen DOES NOT DEPEND ON R OR D
## AT ALL - only on focal length. Widening the circle pushes them outward and
## shrinks them by exactly the amount that cancels it. At fov 60, flankers at
## 60% size land around x 744/1176: clustered in the middle, overlapping the
## negotiation, and no radius fixes it. A longer lens compresses depth so they
## stay big while still subtending a wide angle. Hence 28.
##
## THE CAMERAS LOOK DOWN, AND EVERY SEAT LEANS BACK TO MEET THEM. These cards are
## flat quads with text rendered into them, and a card tilted against the lens
## foreshortens the one thing the whole view exists to make legible - which is
## why the cameras used to be dead level. They are pitched CAM_PITCH_DEG now, so
## the desks read as desks and the two customers you are not with sit back in
## the room rather than beside you. Every seat leans back by exactly the same
## angle, so each card is still square to the lens. Both framings are placed
## relative to the FRONT seat in its own leaned frame, which makes the view of
## the negotiation a rigid rotation of what it was when the camera was level:
## the same pixels, the same sizes, and every readability floor still holds.
## What the pitch changes is everything ELSE - the flankers rise and recede,
## and the desks, floor and wall come into view.
##
## The desks do NOT lean. Each one cancels its seat's lean, so the desk top is
## level in the world and the camera, above it, looks down onto it.

const COLLECTION := "res://addons/card_3d/scenes/card_collection_3d.tscn"
const CUSTOMER_CARD := "res://scenes/cards/customer_card_3d.tscn"
const DETAIL_CARD := "res://scenes/cards/detail_card_3d.tscn"
const REPORT := "res://scenes/report.tscn"
const PULL_PICKER := "res://scenes/pull_picker.tscn"

## Overrides card_3d's own default shape (VENDORED.md: "Do not edit these
## files") through the sanctioned extension point - CardCollection3D's own
## @export var dropzone_collision_shape - rather than editing the vendored
## .tres in place. This override only actually reached the packed scene once
## VENDORED.md's patch fixed the addon's setter to self-assign; before that,
## every collection silently fell back to the vendored default regardless of
## this. 8 wide x 4.2 tall, asymmetric (top +2.2, bottom -2): a bigger,
## easier target than the old symmetric slab, biased toward where a dragged
## card's cursor typically sits.
const DROPZONE_SHAPE := "res://scenes/dropzone_shape_3d.tres"

# --- table geometry, world units -------------------------------------------
## Seats sit on this circle at 0, 120 and 240 degrees. Seat i is at carousel
## angle 120*i, so fronting it means turning the carousel to -120*i - which
## puts seat (i+1)%3 on the RIGHT and seat (i+2)%3 on the LEFT, always.
const CAROUSEL_R := 6.0
const CUSTOMER_Y := 4.0      ## their card, seat-local
const CHAIR_Y := 0.0         ## the offer slot in front of them, seat-local
## The two halves of a pair, a hair either side of the pair's own plane, so
## rotating the pair swaps which one you are looking at.
const FACE_Z := 0.03
const BACK_Z := -0.03
## Every slot is exactly one card. A slot wider than the card it holds would put
## the product's visible edge somewhere other than the customer's, and the two
## margins would no longer match.
const SLOT_SIZE := Vector2(2.5, 3.5)

## The back wall of the office. Well behind everything, and behind the BACK of
## the circle (z -3) as well. Your hand rides at PILE_DEPTH in FRONT of the
## camera; if the wall sat closer than that the hand would slide behind it as
## the camera pushed in and simply vanish. It did, back when this was a felt.
## test_shift_scene.gd pins the clearance now.
const WALL_Z := -14.0
## The office floor. Low enough that nothing of yours that is ever on screen
## reaches it: the lowest visible point of your hand is about y -3.3, and the
## piles only dip below this off the bottom of the frame.
const FLOOR_Y := -4.0

## One per seat, and level in the world (see the header). Its front face sits
## just behind the product card, and its top just under the customer's card,
## so a customer reads as sitting at their desk and a product as being laid in
## front of them. Seat-local, in the desk's own un-leaned frame.
const DESK_SIZE := Vector3(4.4, 0.22, 2.6)  ## the top: width, thickness, depth
const DESK_TOP_Y := 2.05
const DESK_FRONT_Z := -0.45

## See the header. K = 540 / tan(14deg) = 2165.85.
const CAM_FOV := 28.0
## How far both cameras look down, and how far every seat leans back to match.
const CAM_PITCH_DEG := 10.0
## ONE seat camera, not three: the carousel does the moving, so the camera only
## ever travels between these two framings. Each is where the camera sits
## relative to the FRONT seat's origin, in that seat's own leaned frame - see
## framed() for the world position.
##
## Near card plane 0.03, so N = 18.90 and a card is 2.5x3.5 x (K/N) = 286x402 px
## - pixel-identical to the pre-carousel floor card, which is why the >= 360 px
## readability floor survives untouched for whoever is at the front.
const FLOOR_VIEW := Vector3(0.0, 4.00, 18.93)
## N = 21.17 here, and K/N = 102.31 against the old framing's 102.33: the
## negotiation lands on the pixels it already landed on, and the flankers are
## pure addition on either side of it.
const SEAT_VIEW := Vector3(0.0, 1.40, 21.20)
## A dragged card rides this far in front of the seat camera, on a plane
## square to the lens, so it stays the same size wherever the pointer takes it.
const DRAG_DEPTH := 16.60
const FRONT_SEAT := Vector3(0.0, 0.0, CAROUSEL_R)

# --- yours, in CAMERA-LOCAL space ------------------------------------------
# -Z is forward. Stowed positions sit below the bottom of frame at that depth.
##
## The ONLY one of these that changed for the 28mm lens. Screen offset is
## y x K / depth, so scaling the depth by the same 2.3157 that K grew by leaves
## the hand, the draw pile and the discard on exactly the pixels they were on
## before - every constant below is untouched, and so is the fan.
const PILE_DEPTH := -19.91
## The hand deliberately runs off the bottom of the screen. A hand small enough
## to fit entirely inside the strip below the table is a hand you cannot read.
const HAND_UP := Vector3(0.0, -4.77, PILE_DEPTH)
const HAND_STOWED := Vector3(0.0, -12.6, PILE_DEPTH)
const DISCARD_UP := Vector3(7.2, -3.68, PILE_DEPTH)
const DISCARD_STOWED := Vector3(7.2, -12.6, PILE_DEPTH)
const DRAW_UP := Vector3(-7.27, -3.68, PILE_DEPTH)
const DRAW_STOWED := Vector3(-7.27, -12.6, PILE_DEPTH)
## A LONG, SHALLOW arc. What matters is the gap between adjacent cards, which is
## radius x sin(angle / (cards + 1)) - so a big radius with a small angle spreads
## the hand out while keeping it nearly level. The previous 9 / 34 left each card
## showing only 0.9 of its 2.5 width, so the cards on the left were four fifths
## covered, and drooped 79 px at the ends into the bargain.
const FAN_ANGLE := 24.0
const FAN_RADIUS := 24.0

# --- HUD, in 1920x1080 -----------------------------------------------------
## LEFT rail. It used to be on the right, until each customer grew a CLOSE SOON
## tag that slides out to the RIGHT of their card: the right-hand flanker's tag
## ran straight into the log. A tag only ever slides right, so the left rail is
## the one side nothing on the table ever reaches toward. Stops well above the
## bottom strip, which is where the draw pile rises into.
const LOG_RECT := Rect2(18, 79, 422, 651)
## A column, not a row. The bottom of the screen belongs to the hand and the two
## piles, and a Button laid over a card steals the click meant for the card.
##
## RIGHT rail, mirroring the log. It starts past the furthest the right-hand
## flanker's CLOSE SOON tag reaches while you are seated. On the floor that tag
## reaches further, but the buttons are hidden there because there is nobody to
## act on. drive_shift.gd pins both edges.
const ACTION_RECT := Rect2(1560, 300, 330, 340)
const ACTION_BUTTON := Vector2(330, 100)

func _init() -> void:
	var root := Node3D.new()
	root.name = "ShiftRoot"
	root.set_script(load("res://scripts/view/shift_controller.gd"))

	var cam := Camera3D.new()
	cam.name = "Camera3D"
	cam.fov = CAM_FOV
	cam.current = true
	cam.position = framed(FLOOR_VIEW)
	cam.rotation = lean().get_euler()
	root.add_child(cam)
	cam.owner = root

	var floor_mark := Marker3D.new()
	floor_mark.name = "CameraFloor"
	floor_mark.position = framed(FLOOR_VIEW)
	floor_mark.rotation = lean().get_euler()
	floor_mark.unique_name_in_owner = true
	root.add_child(floor_mark)
	floor_mark.owner = root

	# A warm overhead key, and a warm fill rather than the old navy one: the
	# cards are cream paper now, and a blue ambient turned their shadowed side
	# the colour of a bruise.
	var light := DirectionalLight3D.new()
	light.name = "DirectionalLight3D"
	light.position = Vector3(0, 12, 18)
	light.rotation_degrees = Vector3(-38, -22, 0)
	light.light_color = Color("fff1dc")
	light.light_energy = 1.0
	light.shadow_enabled = true
	light.shadow_opacity = 0.55
	light.shadow_blur = 3.0
	root.add_child(light)
	light.owner = root

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Palette.color(&"neutral_1")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b9ad98")
	env.ambient_light_energy = 0.55
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	root.add_child(we)
	we.owner = root

	# The office itself: a back wall, and a floor for the desks to stand on.
	var wall := QuadMesh.new()
	wall.size = Vector2(220, 130)
	var wall_mesh := MeshInstance3D.new()
	wall_mesh.name = "Wall"
	wall_mesh.mesh = wall
	wall_mesh.material_override = _matte(Palette.color(&"wall"))
	wall_mesh.position = Vector3(0, 0, WALL_Z)
	root.add_child(wall_mesh)
	wall_mesh.owner = root

	var ground := PlaneMesh.new()
	ground.size = Vector2(220, 64)
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.name = "Floor"
	floor_mesh.mesh = ground
	floor_mesh.material_override = _matte(Palette.color(&"carpet"))
	floor_mesh.position = Vector3(0, FLOOR_Y, WALL_Z + 32.0)
	root.add_child(floor_mesh)
	floor_mesh.owner = root

	# --- theirs: on a turntable ------------------------------------------
	var table := Node3D.new()
	table.name = "Table"
	root.add_child(table)
	table.owner = root

	# What actually turns. Everything below it rides around; the camera does
	# not chase anybody.
	var carousel := Node3D.new()
	carousel.name = "Carousel"
	carousel.unique_name_in_owner = true
	table.add_child(carousel)
	carousel.owner = root

	var collection_scene: PackedScene = load(COLLECTION)
	var customer_scene: PackedScene = load(CUSTOMER_CARD)
	var detail_scene: PackedScene = load(DETAIL_CARD)

	for i in range(3):
		# One node per seat, carrying its own counter-rotation. A flat quad at
		# 120 degrees off-axis would render edge-on, so every seat holds its
		# card pivot at WORLD yaw 0 by cancelling the carousel's rotation. The
		# camera sits at z 27 against a table spanning +-6, so the worst bearing
		# to a flanker is atan(5.196/30.2) = 9.8 degrees and a card viewed from
		# there foreshortens by cos(9.8) = 0.985. A 1.5% squeeze, and no
		# billboard material, no per-frame look_at, and FlipPair - which turns a
		# node BELOW this one - carries on working untouched.
		#
		# It also LEANS BACK by the cameras' pitch (see the header). Leaning
		# is about X and the counter-rotation about Y, and Node3D composes
		# them Y-then-X, so the carousel's turn and the seat's cancel of it
		# meet first and the lean survives the whole spin untouched.
		var theta := deg_to_rad(120.0 * i)
		var seat := Node3D.new()
		seat.name = "Seat%d" % i
		seat.position = Vector3(CAROUSEL_R * sin(theta), 0.0, CAROUSEL_R * cos(theta))
		seat.rotation = lean().get_euler()
		seat.unique_name_in_owner = true
		carousel.add_child(seat)
		seat.owner = root

		_desk(seat, root, i)

		# The customer and their sheet turn over TOGETHER, so they hang off one
		# node that does the turning. Flipping them individually would leave the
		# front card still in front, showing you nothing but its own back.
		var flip := Node3D.new()
		flip.name = "CustomerFlip%d" % i
		flip.position = Vector3(0.0, CUSTOMER_Y, 0.0)
		flip.set_script(load("res://scripts/view/flip_pair.gd"))
		flip.unique_name_in_owner = true
		seat.add_child(flip)
		flip.owner = root

		var who := customer_scene.instantiate()
		who.name = "Customer%d" % i
		who.position = Vector3(0.0, 0.0, FACE_Z)
		who.unique_name_in_owner = true
		flip.add_child(who)
		who.owner = root

		# On the CUSTOMER now, not the product slot - a customer you are not
		# currently seated with can still have something unsigned at risk, and
		# the old spot (behind the product) was never visible for them at all.
		# Near the bottom, clear of the name/archetype/patience row up top.
		_slide_flag(who, root, "CloseSoonFlag%d" % i, "CLOSE SOON!",
			Palette.color(&"alert"), -1.3)

		_detail(detail_scene, "CustomerDetail%d" % i,
			Vector3(0.0, 0.0, BACK_Z), flip, root)

		# The hover target CANNOT be the card, because the card is what the hover
		# moves. A rotating quad has no thickness: past about 75 degrees the ray
		# stops finding it, the mouse "leaves", the flip reverses, the mouse
		# "enters" again - and the card stutters. This pad sits in front of the
		# pair and never moves, so what is under the cursor never depends on what
		# the cursor started.
		_hover_pad(i, Vector3(0.0, CUSTOMER_Y, FACE_Z + 0.1), seat, root)

		var chair := _collection(collection_scene, "Chair%d" % i,
			Vector3(0.0, CHAIR_Y, FACE_Z), seat, root)
		chair.card_layout_strategy = PileCardLayout.new()
		# A placed product's collision was OFF entirely until the offer-drag
		# feature needed it draggable again (see shift_controller.gd's
		# _dress()) - turning that back on also turned the addon's own
		# hover-to-lift cosmetic back on for free, which it never had before
		# and which reads as stuck/broken on touch (nothing here clears a
		# touch "hover" the way the hand's own explicit press/release wiring
		# does). Selecting and dragging the card are unaffected - only the
		# lift-on-hover/press cosmetic is off.
		chair.highlight_on_hover = false
		# The slot's own outline - a pale sheet on the desk front, where the
		# old faint blue vanished into the walnut - plus the anchor the HUD's
		# TableNote%d hangs from. The note says "nothing on the table", and "or
		# double-click to close the deal" underneath it when there is
		# something to close.
		_mark(chair, root, Palette.color(&"paper"), 0.28)

		# Double-tap-to-close, only when the table is actually empty - see
		# shift_controller.gd's _on_chair_pad_input(). Starts disabled: a
		# placed product's own collision already owns this spot the moment
		# there IS something to pick up, and shift_controller.gd's own
		# _render_details() is what turns this back on, exactly when there is
		# nothing on the table AND something unsigned still to close.
		_chair_pad(i, seat, root)
		# Just the highlight now. The words live on the HUD's TableNote%d, as
		# the second half of the empty-table note, so the two options read as
		# one card offering both.
		_drag_hint(chair, root, "CloseHint%d" % i, Palette.color(&"margin"), false)

		# A sticky-note-style tag, tucked invisibly behind the product slot
		# until shift_controller.gd's own _slide_flag() tweens it clear to the
		# right - the same slide DetailCard3D's own reveal() does, mirrored in
		# direction. CLOSE SOON used to live here too, but it needs to be
		# readable for a customer you are not currently seated with - see the
		# Customer%d loop below instead.
		_slide_flag(chair, root, "OfferFlag%d" % i, "DROP ON CUSTOMER\nTO OFFER",
			Palette.color(&"appeal"), 0.0)

		# A drop target that never actually holds a card - CardHomes never
		# assigns anything here, so a dropped offer always snaps back to
		# Chair%d once reconciliation runs. It exists only so dragging what's
		# already on the table back onto the customer reads as "offer them
		# this", distinct from Chair%d's own "place a card from your hand"
		# meaning - see shift_controller.gd's _on_drag_card_moved.
		var customer_zone := _collection(collection_scene, "CustomerZone%d" % i,
			Vector3(0.0, CUSTOMER_Y, FACE_Z + 0.1), seat, root)
		customer_zone.card_layout_strategy = PileCardLayout.new()
		_drag_hint(customer_zone, root, "OfferDragHint%d" % i, Palette.color(&"appeal"))

		_detail(detail_scene, "OfferDetail%d" % i,
			Vector3(0.0, CHAIR_Y, BACK_Z), seat, root)


	var seat_cam := Marker3D.new()
	seat_cam.name = "SeatCam"
	seat_cam.position = framed(SEAT_VIEW)
	seat_cam.rotation = lean().get_euler()
	seat_cam.unique_name_in_owner = true
	root.add_child(seat_cam)
	seat_cam.owner = root

	# --- yours: parented to the camera, stowed below frame ----------------
	var hand := _collection(collection_scene, "Hand", HAND_STOWED, cam, root)
	var fan := FanCardLayout.new()
	fan.arc_angle_deg = FAN_ANGLE
	fan.arc_radius = FAN_RADIUS
	hand.card_layout_strategy = fan
	_mark(hand, root, Palette.color(&"margin"))

	# Both piles are named by HUD tags hanging from their TagAnchor (see
	# _build_hud). DropDragHint's anchor sits at the same top edge as the
	# discard's own, so DROP PRODUCT replaces DISCARD in place rather than
	# appearing at some other height.
	var discard := _collection(collection_scene, "Discard", DISCARD_STOWED, cam, root)
	discard.card_layout_strategy = PileCardLayout.new()
	_mark(discard, root, Palette.color(&"action"))
	_drag_hint(discard, root, "DropDragHint", Palette.color(&"action"))

	var draw := _collection(collection_scene, "Draw", DRAW_STOWED, cam, root)
	draw.card_layout_strategy = PileCardLayout.new()
	_mark(draw, root, Palette.color(&"neutral_3"))

	var drag := DragController.new()
	drag.name = "DragController"
	# DRAG_DEPTH in front of the seat camera, the same fraction of the way to
	# the table that 7.17 was before the lens changed - and square to the lens
	# rather than to the world, so a card dragged to the bottom of the screen is
	# as big as one dragged across the middle.
	var toward_you := lean() * Vector3.BACK
	drag.card_drag_plane = Plane(toward_you,
		toward_you.dot(framed(SEAT_VIEW)) - DRAG_DEPTH)
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

## The lean every seat and camera shares: a turn about X that tips a seat's
## top away from you and points a camera down at it by the same angle.
static func lean() -> Basis:
	return Basis(Vector3.RIGHT, -deg_to_rad(CAM_PITCH_DEG))

## Where a framing puts the camera in the world. `view` is measured from the
## front seat's origin in that seat's own leaned frame, which is what keeps the
## negotiation on the same pixels however steep the pitch.
static func framed(view: Vector3) -> Vector3:
	return FRONT_SEAT + lean() * view

## A desk for the seat to sit at: a walnut top with a brass edge, and a
## panelled front down to the floor. It cancels the seat's lean, so it stands
## level in the world while the cards above it lean back to face the lens.
## Never collides with anything - it is scenery, and the table's picking is
## already delicate enough (see shift_controller.gd's drop-zone notes).
func _desk(seat: Node3D, owner_root: Node, index: int) -> void:
	var desk := Node3D.new()
	desk.name = "Desk%d" % index
	desk.rotation = lean().inverse().get_euler()
	seat.add_child(desk)
	desk.owner = owner_root

	var walnut := _matte(Palette.color(&"walnut"), 0.55)
	var panel := _matte(Palette.color(&"walnut_dark"), 0.7)
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Palette.color(&"brass")
	brass.metallic = 0.6
	brass.roughness = 0.35

	var top_z := DESK_FRONT_Z - DESK_SIZE.z * 0.5
	_box(desk, owner_root, "Top", DESK_SIZE,
		Vector3(0.0, DESK_TOP_Y - DESK_SIZE.y * 0.5, top_z), walnut)
	# A thin brass strip along the top's front edge, where the light catches it.
	_box(desk, owner_root, "Trim", Vector3(DESK_SIZE.x, 0.06, 0.06),
		Vector3(0.0, DESK_TOP_Y - 0.03, DESK_FRONT_Z + 0.03), brass)

	var front_h := DESK_TOP_Y - DESK_SIZE.y - FLOOR_Y
	var front_y := FLOOR_Y + front_h * 0.5
	_box(desk, owner_root, "Front", Vector3(DESK_SIZE.x - 0.2, front_h, 0.12),
		Vector3(0.0, front_y, DESK_FRONT_Z - 0.1), walnut)
	# A raised panel on the front, darker, so it reads as joinery rather
	# than a slab of brown.
	_box(desk, owner_root, "Panel", Vector3(DESK_SIZE.x - 1.2, front_h - 1.2, 0.02),
		Vector3(0.0, front_y, DESK_FRONT_Z - 0.03), panel)

func _box(parent: Node3D, owner_root: Node, node_name: String, size: Vector3,
		pos: Vector3, mat: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var inst := MeshInstance3D.new()
	inst.name = node_name
	inst.mesh = mesh
	inst.material_override = mat
	inst.position = pos
	parent.add_child(inst)
	inst.owner = owner_root

func _matte(color: Color, roughness: float = 0.95) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	return m

func _collection(scene: PackedScene, node_name: String, pos: Vector3,
		parent: Node, owner_root: Node) -> Node3D:
	var c := scene.instantiate()
	c.name = node_name
	c.position = pos
	c.unique_name_in_owner = true
	c.dropzone_collision_shape = load(DROPZONE_SHAPE)
	parent.add_child(c)
	c.owner = owner_root
	return c

## An invisible, immovable slab in front of a seat's customer pair. It owns the
## hover and the click for that seat; the customer card's own collider is
## disabled so the two can never disagree about whether the mouse is here.
## A box, not a quad, so there is no angle at which it has no area.
func _hover_pad(index: int, pos: Vector3, parent: Node, owner_root: Node) -> void:
	var body := StaticBody3D.new()
	body.name = "HoverPad%d" % index
	body.position = pos
	body.unique_name_in_owner = true
	parent.add_child(body)
	body.owner = owner_root

	var box := BoxShape3D.new()
	box.size = Vector3(SLOT_SIZE.x, SLOT_SIZE.y, 0.1)
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	shape.shape = box
	body.add_child(shape)
	shape.owner = owner_root

## Same shape as _hover_pad(), over the PRODUCT slot instead of the customer -
## disabled by default, since a placed product's own collision already owns
## this spot the moment there is something to pick up. shift_controller.gd's
## _render_details() is what enables it, exactly when the table is empty AND
## there is something unsigned still to close.
func _chair_pad(index: int, parent: Node, owner_root: Node) -> void:
	var body := StaticBody3D.new()
	body.name = "ChairPad%d" % index
	body.position = Vector3(0.0, CHAIR_Y, FACE_Z + 0.1)
	body.unique_name_in_owner = true
	parent.add_child(body)
	body.owner = owner_root

	var box := BoxShape3D.new()
	box.size = Vector3(SLOT_SIZE.x, SLOT_SIZE.y, 0.1)
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	shape.shape = box
	shape.disabled = true
	body.add_child(shape)
	shape.owner = owner_root

## The back half of a pair: authored FACING AWAY, so at rest it is simply the
## back of the card in front of it and costs nothing to hide.
func _detail(scene: PackedScene, node_name: String, pos: Vector3,
		parent: Node, owner_root: Node) -> Node3D:
	var d := scene.instantiate()
	d.name = node_name
	d.position = pos
	d.rotation = Vector3(0.0, PI, 0.0)
	d.unique_name_in_owner = true
	parent.add_child(d)
	d.owner = owner_root
	return d

## A translucent slab behind a zone - the only thing that makes a
## CardCollection3D visible in the editor, and a useful "drop here" at runtime -
## plus the TagAnchor its HUD label hangs from.
##
## The words used to be a Label3D here, and that is exactly what made them hard
## to read: drawn into the scene, shrunk by distance, and buried by a growing
## pile. The label is a flat HUD tag now (see _build_hud()), which only needs to
## know WHERE the card's top edge is.
func _mark(zone: Node3D, owner_root: Node, tint: Color, alpha: float = 0.16) -> void:
	var slab := QuadMesh.new()
	slab.size = SLOT_SIZE
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(tint.r, tint.g, tint.b, alpha)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var mesh := MeshInstance3D.new()
	mesh.name = "ZoneSlab"
	mesh.mesh = slab
	mesh.material_override = mat
	mesh.position = Vector3(0, 0, -0.05)
	zone.add_child(mesh)
	mesh.owner = owner_root
	_tag_anchor(zone, owner_root)

## The top-centre of the card a zone holds, in the card's own plane. A HUD tag
## hangs from this point, so every hint sits the same distance inside the top
## edge of its card, whatever size perspective draws that card at. It is in the
## card's plane rather than floating in front of it, because a point nearer the
## camera unprojects a few pixels away from the edge it is meant to mark.
func _tag_anchor(zone: Node3D, owner_root: Node) -> void:
	var anchor := Marker3D.new()
	anchor.name = "TagAnchor"
	anchor.position = Vector3(0.0, SLOT_SIZE.y * 0.5, 0.0)
	zone.add_child(anchor)
	anchor.owner = owner_root

## Unlike _mark()'s permanent outline, this says nothing until a drag actually
## makes it relevant: a highlighted slab over the zone itself. One container
## node, so shift_controller.gd's _on_drag_started/_on_drag_stopped can show or
## hide it with a single .visible toggle. The HUD tag hanging from its
## TagAnchor follows that toggle for free.
##
## CLOSE passes anchored = false: its words are the second half of the empty
## table's own note, which hangs from the chair's anchor rather than this one.
func _drag_hint(zone: Node3D, owner_root: Node, node_name: String, tint: Color,
		anchored: bool = true) -> void:
	var hint := Node3D.new()
	hint.name = node_name
	hint.visible = false
	hint.unique_name_in_owner = true
	zone.add_child(hint)
	hint.owner = owner_root

	var slab := QuadMesh.new()
	slab.size = SLOT_SIZE
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(tint.r, tint.g, tint.b, 0.35)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var mesh := MeshInstance3D.new()
	mesh.name = "Slab"
	mesh.mesh = slab
	mesh.material_override = mat
	mesh.position = Vector3(0, 0, -0.04)
	hint.add_child(mesh)
	mesh.owner = owner_root
	if anchored:
		_tag_anchor(hint, owner_root)

## A sticky-note tag tucked at the zone's own X (hidden - start invisible,
## since CLOSE SOON must be able to appear over an EMPTY table with no card
## there to hide it behind, unlike _drag_hint's slab). shift_controller.gd's
## _slide_flag() makes it visible and tweens it clear to the right when
## shown, mirroring DetailCard3D's own reveal() - just the opposite
## direction, and a plain position tween rather than a card turning over.
func _slide_flag(zone: Node3D, owner_root: Node, node_name: String, text: String,
		tint: Color, y: float) -> void:
	var flag := Node3D.new()
	flag.name = node_name
	flag.position = Vector3(0, y, 0.05)
	flag.visible = false
	flag.unique_name_in_owner = true
	zone.add_child(flag)
	flag.owner = owner_root

	# A solid, opaque tag - the translucent slab + tinted text _drag_hint's
	# OFFER/DROP hints use read as too faint here, on something meant to
	# read at a glance rather than while your attention is already on a drag.
	# White text on the solid tint reads far better than the tint on itself.
	var slab := QuadMesh.new()
	slab.size = Vector2(1.8, 0.7)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var mesh := MeshInstance3D.new()
	mesh.name = "Slab"
	mesh.mesh = slab
	mesh.material_override = mat
	flag.add_child(mesh)
	mesh.owner = owner_root

	var label := Label3D.new()
	label.name = "Label"
	label.text = text
	label.font_size = 24
	label.pixel_size = 0.005
	label.modulate = Palette.color(&"text")
	label.outline_size = 8
	label.outline_modulate = Palette.color(&"neutral_1")
	label.shaded = false
	label.double_sided = false
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector3(0, 0, 0.01)
	flag.add_child(label)
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

	# --- the table's own hints: flat, full size, and over the table -------
	# FIRST of HudRoot's children, so every panel after it (the log, the
	# buttons, the report, the pull picker) draws over a hint rather than
	# under one. Each tag follows a TagAnchor on the table; see screen_tag.gd.
	var hints := Control.new()
	hints.name = "HintLayer"
	hints.set_anchors_preset(Control.PRESET_FULL_RECT)
	hints.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hints.unique_name_in_owner = true
	hud.add_child(hints)
	hints.owner = root

	_tag(hints, root, "DrawTag", ^"Camera3D/Draw/TagAnchor", &"manila", &"ink_dim",
		[["Label", "DRAW", 22, &"ink"]])
	_tag(hints, root, "DiscardTag", ^"Camera3D/Discard/TagAnchor", &"manila", &"ink_dim",
		[["Label", "DISCARD", 22, &"ink"], ["Sub", "drag a card here to dig", 16, &"ink_dim"]])
	# Same top edge as DiscardTag, and only ever shown in its place.
	_tag(hints, root, "DropTag", ^"Camera3D/Discard/DropDragHint/TagAnchor", &"paper", &"stamp",
		[["Label", "DROP PRODUCT", 24, &"stamp"]])
	for i in range(3):
		_tag(hints, root, "OfferTag%d" % i,
			NodePath("Table/Carousel/Seat%d/CustomerZone%d/OfferDragHint%d/TagAnchor" % [i, i, i]),
			&"paper", &"ink", [["Label", "OFFER PRODUCT", 24, &"ink"]])
		_table_note(hints, root, i)

	# --- the shift bar, always ------------------------------------------
	var top := HBoxContainer.new()
	top.name = "TopBar"
	top.position = Vector2(28, 18)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 48)
	hud.add_child(top)
	top.owner = root

	# The tick counter doubles as a mobile stand-in for Ctrl+E (skip to the
	# end of the shift) - it is the one thing on this HUD you look at every
	# single tick, always in the same place, which is exactly what a tap
	# target needs and a keyboard-only shortcut cannot give a touch player
	# at all. PanelContainer stacks every child at the SAME rect rather than
	# laying them out side by side - the label sizes the wrapper, and the
	# invisible button (added after, so it is on top for input) inherits
	# that identical rect for free, with no coordinates to keep in sync by
	# hand.
	var tick_wrap := PanelContainer.new()
	tick_wrap.name = "TickWrap"
	tick_wrap.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	# IGNORE, same as every plain label already on this HUD - the wrapper
	# itself must never be the thing that blocks a click meant for the
	# table; only the Button inside it (exempt from that same guard) should
	# ever consume one. test_no_hud_control_can_swallow_a_click_meant_for_
	# the_table() caught this the first time it was missed.
	tick_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(tick_wrap)
	tick_wrap.owner = root

	var tick_label := Label.new()
	tick_label.name = "TickLabel"
	tick_label.text = "tick 0/24"
	tick_label.add_theme_font_size_override("font_size", 30)
	tick_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tick_label.unique_name_in_owner = true
	tick_wrap.add_child(tick_label)
	tick_label.owner = root

	var tick_tap := Button.new()
	tick_tap.name = "TickTapTarget"
	tick_tap.flat = true   # no visible chrome at all - the ask was invisible
	tick_tap.unique_name_in_owner = true
	tick_wrap.add_child(tick_tap)
	tick_tap.owner = root

	var banked := Label.new()
	banked.name = "BankedLabel"
	banked.text = "banked $0 / $3,600"
	banked.add_theme_font_size_override("font_size", 30)
	banked.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banked.unique_name_in_owner = true
	top.add_child(banked)
	banked.owner = root

	# Standing gets the same invisible-tap-target treatment as the tick counter
	# above, for the same reason: a manual playtesting convenience, not a
	# mechanic, so it can add standing to survive long enough to actually reach
	# later shifts instead of dying to one bad walkout. PanelContainer, not the
	# label directly, so the Button on top inherits the label's own rect rather
	# than needing hand-kept coordinates - see TickWrap just above.
	var standing_wrap := PanelContainer.new()
	standing_wrap.name = "StandingWrap"
	standing_wrap.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	standing_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(standing_wrap)
	standing_wrap.owner = root

	var standing_label := Label.new()
	standing_label.name = "StandingLabel"
	standing_label.text = "standing 100/100"
	standing_label.add_theme_font_size_override("font_size", 30)
	standing_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	standing_label.unique_name_in_owner = true
	standing_wrap.add_child(standing_label)
	standing_label.owner = root

	var standing_tap := Button.new()
	standing_tap.name = "StandingTapTarget"
	standing_tap.flat = true   # no visible chrome at all - the ask was invisible
	standing_tap.unique_name_in_owner = true
	standing_wrap.add_child(standing_tap)
	standing_tap.owner = root

	var at_risk := Label.new()
	at_risk.name = "AtRiskLabel"
	at_risk.text = "nothing unsigned"
	at_risk.add_theme_font_size_override("font_size", 30)
	at_risk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	at_risk.unique_name_in_owner = true
	top.add_child(at_risk)
	at_risk.owner = root

	# --- yours: the action column, on the right rail ------------------------
	var actions := VBoxContainer.new()
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
		b.custom_minimum_size = ACTION_BUTTON
		b.add_theme_font_size_override("font_size", 30)
		b.unique_name_in_owner = true
		actions.add_child(b)
		b.owner = root

	# --- yours: the log, left, stopping short of the draw pile ------------
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
	# RichTextLabel's own theme item, separate from the project's Label-wide
	# default_font_size (26) - engine default is 16 unless set explicitly here.
	log_box.add_theme_font_size_override("normal_font_size", 20)
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

	# Last of the HUD's children, so it draws on top of everything else here -
	# the same "added last" rule DeckViewer's own comment states, for the
	# same reason: reachable while any of this HUD's other panels could be
	# showing, so it cannot be buried under one of them.
	var pull_picker: Control = (load(PULL_PICKER) as PackedScene).instantiate()
	pull_picker.name = "PullPicker"
	pull_picker.visible = false
	pull_picker.set_anchors_preset(Control.PRESET_FULL_RECT)
	pull_picker.unique_name_in_owner = true
	hud.add_child(pull_picker)
	pull_picker.owner = root

## A paper tag on the HUD that follows `anchor` on the table. `lines` is one
## [name, text, font size, palette role] per row, top to bottom. Starts hidden:
## the controller shows it once it knows where its anchor is.
func _tag(parent: Node, owner_root: Node, node_name: String, anchor: NodePath,
		fill: StringName, edge: StringName, lines: Array) -> PanelContainer:
	var tag := PanelContainer.new()
	tag.name = node_name
	tag.set_script(load("res://scripts/view/screen_tag.gd"))
	tag.set(&"anchor_path", anchor)
	tag.visible = false
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.unique_name_in_owner = true
	tag.add_theme_stylebox_override("panel", _tag_style(fill, edge))
	parent.add_child(tag)
	tag.owner = owner_root

	var col := VBoxContainer.new()
	col.name = "Lines"
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.add_child(col)
	col.owner = owner_root
	for spec in lines:
		_line(col, owner_root, spec[0], spec[1], spec[2], spec[3])
	return tag

## The empty table's note: what to do with it, and - only once there is
## something unsigned - the other thing you can do with it instead. One card,
## two options, a rule and an "or" between them, so both read as choices
## rather than as two unrelated messages that happen to share a card. The two
## options are the same size and weight, and differ only in ink.
##
## Hard line breaks rather than autowrap. A wrapping Label only learns its
## height after a layout pass has told it its width, so a note sized in the
## same frame it changed would be measured against last frame's text.
## drive_shift.gd checks the whole note fits inside the product card.
func _table_note(parent: Node, owner_root: Node, i: int) -> void:
	var note := _tag(parent, owner_root, "TableNote%d" % i,
		NodePath("Table/Carousel/Seat%d/Chair%d/TagAnchor" % [i, i]), &"paper", &"ink_dim",
		[["Title", "Nothing on the table", 20, &"ink"],
			["Sub", "Place a product here", 17, &"ink_dim"]])
	var col := note.get_node(^"Lines")

	var close_row := VBoxContainer.new()
	close_row.name = "CloseRow"
	close_row.visible = false
	close_row.add_theme_constant_override("separation", 2)
	close_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(close_row)
	close_row.owner = owner_root

	var or_row := HBoxContainer.new()
	or_row.name = "OrRow"
	or_row.add_theme_constant_override("separation", 8)
	or_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	close_row.add_child(or_row)
	or_row.owner = owner_root
	_rule(or_row, owner_root, "RuleLeft")
	_line(or_row, owner_root, "Or", "or", 16, &"ink_dim")
	_rule(or_row, owner_root, "RuleRight")

	_line(close_row, owner_root, "Close", "Double-click to\nclose the deal", 20, &"stamp")

func _line(parent: Node, owner_root: Node, node_name: String, text: String,
		size: int, role: StringName) -> Label:
	var l := Label.new()
	l.name = node_name
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Palette.color(role))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	l.owner = owner_root
	return l

## A hairline that stretches to fill its row. A PanelContainer rather than a
## ColorRect, because test_shift_scene.gd bans ColorRects anywhere under the HUD.
func _rule(parent: Node, owner_root: Node, node_name: String) -> void:
	var rule := PanelContainer.new()
	rule.name = node_name
	rule.custom_minimum_size = Vector2(0, 2)
	rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rule.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.color(&"ink_dim")
	rule.add_theme_stylebox_override("panel", style)
	parent.add_child(rule)
	rule.owner = owner_root

## Paper with an inked edge and a soft drop shadow, so a tag reads as a slip of
## paper lying on the table rather than a box painted over it.
func _tag_style(fill: StringName, edge: StringName) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Palette.color(fill)
	s.border_color = Palette.color(edge)
	s.set_border_width_all(2)
	s.set_corner_radius_all(3)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 6
	s.content_margin_bottom = 8
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 4
	s.shadow_offset = Vector2(2, 3)
	return s
