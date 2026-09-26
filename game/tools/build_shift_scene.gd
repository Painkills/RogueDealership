extends SceneTree
## Builds res://scenes/shift.tscn.
##
## THE CAMERA IS THE PLAYER. Your hand, your draw pile and your discard are
## children of Camera3D, parked below the bottom of frame. They travel with you
## for free, and arriving at a seat only has to tween them up in camera-local
## space.
##
## A SEAT IS A FOLDER, A SLOT AND A TABLET. The customer is a file folder with
## a detail card tucked behind it facing the other way; hovering them turns the
## PAIR over, so the detail really is the back of the folder. In front of them
## is the product slot, standing in the middle of a tablet's screen - and the
## tablet, not a second card, is what says how the product is landing.
##
## Both halves of the folder are the same size, which is not decoration: a back
## that is not the same shape as its front is not a back.
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
const TABLET := "res://scenes/offer_tablet.tscn"
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
## The discard's own, a unit taller at the top (+3 where every other zone
## stops at +2.2): "give the discard dropzone a little more vertical area."
## The pile sits low in the bottom-right corner, so upward is the only way it
## can grow on screen - and it still stops well short of the middle of the
## screen, a target in the corner and nowhere else. drive_shift.gd pins both
## ends of that.
const DISCARD_DROPZONE_SHAPE := "res://scenes/discard_dropzone_shape_3d.tres"

# --- table geometry, world units -------------------------------------------
## Seats sit on this circle at 0, 120 and 240 degrees. Seat i is at carousel
## angle 120*i, so fronting it means turning the carousel to -120*i - which
## puts seat (i+1)%3 on the RIGHT and seat (i+2)%3 on the LEFT, always.
const CAROUSEL_R := 6.0
const CUSTOMER_Y := 4.0      ## their card, seat-local
## The offer slot in front of them, seat-local: the middle of the tablet's
## screen, with the tablet's bottom edge where the card's own used to be - so
## the tablet stands on the desk and your hand clears it exactly as it cleared
## the card.
const CHAIR_Y := (OfferTablet.SIZE.y - 3.5) * 0.5
## A hair behind the slot's own outline and highlight slabs, so the card, its
## outline and its highlight all sit on the screen rather than behind it.
const TABLET_Z := -0.07
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
## The office windows along that wall - see OfficeWindows. Five tall panes,
## showroom glass, across the whole width either framing sees: low sills, so
## the town's rooftops show under the two customers either side of you, and
## tops past the top of both framings, so they are never in shot. At a desk
## the customers and the tablet stand in front of most of it, and the sky
## shows round them - widest on the right, where the old button rail was.
const WINDOW_PANES := 5
const WINDOW_W := 7.0
const WINDOW_GAP := 1.0
const WINDOW_SILL := -2.6
const WINDOW_TOP := 11.5
## The frame's bars: how wide, and how far they stand off the wall.
const WINDOW_BAR := 0.24
const WINDOW_BAR_DEPTH := 0.12
## The sky they look out on, in pixels: the same shape as the five panes laid
## side by side, gaps left out, since the gaps are wall and never show sky.
const SKY_PX := Vector2i(1400, 564)
## The office floor. Low enough that nothing of yours that is ever on screen
## reaches it: the lowest visible point of your hand is about y -3.3, and the
## piles only dip below this off the bottom of the frame.
const FLOOR_Y := -4.0

## One per seat, level in the world (see the header): a TABLE, not a cabinet.
## The first pass was a solid-fronted desk with the product card floating in
## front of it, and it read as a podium. What makes a table read as a table is
## a top you can see down onto and legs with the floor showing between them,
## so the product card stands ON the top, at its front, and the top runs back
## past the customer. A light laminate top on a black steel frame - the
## showroom's desk, not a banker's.
##
## Seat-local, in the desk's own un-leaned frame. TABLE_TOP_Y is a hair under
## the tablet's lowest edge (-1.73 once the seat's lean tips it), so the tablet
## stands on the table rather than through it or above it.
const TABLE_TOP_Y := -1.76
## Wide enough for the tablet to stand on with room either side of it.
const TABLE_SIZE := Vector3(8.0, 0.14, 3.4)   ## the top: width, thickness, depth
const TABLE_FRONT_Z := 1.1
const TABLE_LEG := 0.12
## The customer's chair: an ordinary office chair on the far side of the desk,
## drawn to the desk's own scale. The desk top stands 2.24 above the floor -
## call it 75 cm - so a seat 1.35 up is the usual 45 cm, well BELOW the desk
## top, and the back tops out about a hand's width above the desk. The first
## chair was a slab as wide as their folder, which read as a church pew, and
## the second still had its seat higher than the desk.
##
## The seat tucks a little under the desk's back edge (z -2.3), the way a
## chair is left pushed in.
const CHAIR_Z := -2.75                              ## the seat's centre
const CHAIR_SEAT_Y := FLOOR_Y + 1.35                ## the seat's top
const CHAIR_SEAT := Vector3(1.45, 0.2, 1.3)
const CHAIR_BACK_SIZE := Vector3(1.3, 1.6, 0.16)   ## width, height, thickness
## The back's corners: small against its width, so it reads as a chair back's
## rounded rectangle rather than a ball peering over the desk.
const CHAIR_BACK_ROUND := 0.4
const CHAIR_BACK_LIFT := 0.14                       ## the gap above the seat

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
## LEFT rail. Stops well above the bottom strip, which is where the draw pile
## rises into. As narrow as it is so the left flanker's folder clears it from
## the floor, where it is biggest.
const LOG_RECT := Rect2(18, 80, 370, 650)
## The log's fold button, in its heading row.
const LOG_TOGGLE := Vector2(84, 34)
## The app bar across the top that the shift's numbers sit on. The log starts
## below it.
const TOP_STRIP_HEIGHT := 66.0
## How far in from their folder's right-hand edge a customer's CLOSE SOON tag
## sits, in world units. It hangs in the strip beside the folder's tab, the
## one empty space on the folder.
const CLOSE_SOON_INSET := 0.1
## Control.layout_mode's ANCHORS value, which Godot does not expose as a
## constant - see _cover_the_hud().
const LAYOUT_MODE_ANCHORS := 1

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

	# A neutral white key and a neutral fill - showroom lighting, not a desk
	# lamp. The cards are white now, and a tinted light is the first thing that
	# makes white look dated.
	var light := DirectionalLight3D.new()
	light.name = "DirectionalLight3D"
	light.position = Vector3(0, 12, 18)
	light.rotation_degrees = Vector3(-38, -22, 0)
	light.light_color = Color("f8faff")
	# Low enough that a white card face is not clipped to a flat blank: key
	# plus fill any brighter and the faces lost their edges.
	light.light_energy = 0.62
	light.shadow_enabled = true
	light.shadow_opacity = 0.55
	light.shadow_blur = 3.0
	root.add_child(light)
	light.owner = root

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Palette.color(&"neutral_1")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c9ced6")
	env.ambient_light_energy = 0.4
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

	_windows(root)

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
	var tablet_scene: PackedScene = load(TABLET)

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

		# Where the customer's CLOSE SOON tag hangs: the folder's top-right
		# corner, in the strip beside its tab. On the SEAT, not on the folder -
		# the folder turns over, and a tag riding it vanished with the front
		# every time you turned it to read the back. The seat never turns.
		var corner := Marker3D.new()
		corner.name = "CloseSoonAnchor%d" % i
		corner.position = Vector3(CustomerCard3D.CARD_SIZE.x * 0.5 - CLOSE_SOON_INSET,
			CUSTOMER_Y + CustomerCard3D.CARD_SIZE.y * 0.5, FACE_Z)
		seat.add_child(corner)
		corner.owner = root

		# The back of their folder is folder-sized too.
		var back := _detail(detail_scene, "CustomerDetail%d" % i,
			Vector3(0.0, 0.0, BACK_Z), flip, root)
		back.set(&"card_size", CustomerCard3D.CARD_SIZE)
		back.set(&"face_size", CustomerCard3D.FRONT_SIZE)

		# The hover target CANNOT be the card, because the card is what the hover
		# moves. A rotating quad has no thickness: past about 75 degrees the ray
		# stops finding it, the mouse "leaves", the flip reverses, the mouse
		# "enters" again - and the card stutters. This pad sits in front of the
		# pair and never moves, so what is under the cursor never depends on what
		# the cursor started.
		_hover_pad(i, Vector3(0.0, CUSTOMER_Y, FACE_Z + 0.1), CustomerCard3D.CARD_SIZE,
			seat, root)

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
		# The slot's own outline - a pale sheet over the tablet's well - plus
		# the anchor the HUD's TableNote%d hangs from. The note says "nothing
		# on the table", and "or double-click to close the deal" underneath it
		# when there is something to close.
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
		# one card offering both. Stamp red, like the words.
		_drag_hint(chair, root, "CloseHint%d" % i, Palette.color(&"stamp"), false)

		# A drop target that never actually holds a card - CardHomes never
		# assigns anything here, so a dropped offer always snaps back to
		# Chair%d once reconciliation runs. It exists only so dragging what's
		# already on the table back onto the customer reads as "offer them
		# this", distinct from Chair%d's own "place a card from your hand"
		# meaning - see shift_controller.gd's _on_drag_card_moved.
		var customer_zone := _collection(collection_scene, "CustomerZone%d" % i,
			Vector3(0.0, CUSTOMER_Y, FACE_Z + 0.1), seat, root)
		customer_zone.card_layout_strategy = PileCardLayout.new()
		_drag_hint(customer_zone, root, "OfferDragHint%d" % i, Palette.color(&"appeal"),
			true, CustomerCard3D.CARD_SIZE)

		# The tablet the product stands on. Off until you sit at this desk -
		# see shift_controller.gd's _render_details().
		var tablet: Node3D = tablet_scene.instantiate()
		tablet.name = "Tablet%d" % i
		tablet.position = Vector3(0.0, CHAIR_Y, TABLET_Z)
		tablet.visible = false
		tablet.unique_name_in_owner = true
		seat.add_child(tablet)
		tablet.owner = root


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
	discard.dropzone_collision_shape = load(DISCARD_DROPZONE_SHAPE)
	# A pale outline like the empty product slot's, so an empty discard reads
	# as an empty place to put something rather than a murky purple block.
	_mark(discard, root, Palette.color(&"paper"), 0.2)
	_drag_hint(discard, root, "DropDragHint", Palette.color(&"stamp"))

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

## A desk for the seat: a light laminate table on a black steel frame, and the
## customer's office chair behind it. It cancels the seat's lean, so it stands
## level in the world while the cards above it lean back to face the lens.
## Never collides with anything - it is scenery, and the table's picking is
## already delicate enough (see shift_controller.gd's drop-zone notes).
func _desk(seat: Node3D, owner_root: Node, index: int) -> void:
	var desk := Node3D.new()
	desk.name = "Desk%d" % index
	desk.rotation = lean().inverse().get_euler()
	seat.add_child(desk)
	desk.owner = owner_root

	var laminate := _matte(Palette.color(&"desk_top"), 0.4)
	var steel := _matte(Palette.color(&"desk_frame"), 0.35)
	steel.metallic = 0.4
	var mesh_fabric := _matte(Palette.color(&"chair"), 0.9)
	var chrome := _matte(Palette.color(&"chair_base"), 0.3)
	chrome.metallic = 0.6

	# --- the table ----------------------------------------------------------
	var top_z := TABLE_FRONT_Z - TABLE_SIZE.z * 0.5
	var under := TABLE_TOP_Y - TABLE_SIZE.y
	_box(desk, owner_root, "Top", TABLE_SIZE,
		Vector3(0.0, TABLE_TOP_Y - TABLE_SIZE.y * 0.5, top_z), laminate)
	# A black edge band on the front, the way a modern desk is finished.
	_box(desk, owner_root, "Edge", Vector3(TABLE_SIZE.x, TABLE_SIZE.y, 0.03),
		Vector3(0.0, TABLE_TOP_Y - TABLE_SIZE.y * 0.5, TABLE_FRONT_Z + 0.015), steel)
	var leg_h := under - FLOOR_Y
	var inset_x := TABLE_SIZE.x * 0.5 - 0.25
	var back_leg_z := TABLE_FRONT_Z - TABLE_SIZE.z + 0.25
	for corner in [["LegFrontLeft", -inset_x, TABLE_FRONT_Z - 0.25],
			["LegFrontRight", inset_x, TABLE_FRONT_Z - 0.25],
			["LegBackLeft", -inset_x, back_leg_z],
			["LegBackRight", inset_x, back_leg_z]]:
		_box(desk, owner_root, corner[0], Vector3(TABLE_LEG, leg_h, TABLE_LEG),
			Vector3(corner[1], FLOOR_Y + leg_h * 0.5, corner[2]), steel)
	# A stretcher between the back legs - the frame reads as a frame.
	_box(desk, owner_root, "Stretcher", Vector3(inset_x * 2.0, 0.08, 0.08),
		Vector3(0.0, FLOOR_Y + leg_h * 0.35, back_leg_z), steel)

	# --- the customer's office chair, on the far side of it ------------------
	# A rounded back: a narrow capsule stretched out to the back's width and
	# pressed flat, so its top and bottom are gentle curves rather than either
	# the corners of a slab or a half-circle.
	var back_z := CHAIR_Z - CHAIR_SEAT.z * 0.5
	var back := CapsuleMesh.new()
	back.radius = CHAIR_BACK_ROUND
	back.height = CHAIR_BACK_SIZE.y
	var back_inst := MeshInstance3D.new()
	back_inst.name = "ChairBack"
	back_inst.mesh = back
	back_inst.material_override = mesh_fabric
	back_inst.position = Vector3(0.0,
		CHAIR_SEAT_Y + CHAIR_BACK_LIFT + CHAIR_BACK_SIZE.y * 0.5, back_z)
	back_inst.scale = Vector3(CHAIR_BACK_SIZE.x / (CHAIR_BACK_ROUND * 2.0), 1.0,
		CHAIR_BACK_SIZE.z / (CHAIR_BACK_ROUND * 2.0))
	desk.add_child(back_inst)
	back_inst.owner = owner_root
	# The spine the back hangs from, so it is held up rather than floating.
	_box(desk, owner_root, "ChairSpine", Vector3(0.16, CHAIR_BACK_LIFT + 0.5, 0.08),
		Vector3(0.0, CHAIR_SEAT_Y + (CHAIR_BACK_LIFT + 0.5) * 0.5 - 0.1, back_z - 0.04),
		chrome)
	_box(desk, owner_root, "ChairSeat", CHAIR_SEAT,
		Vector3(0.0, CHAIR_SEAT_Y - CHAIR_SEAT.y * 0.5, CHAIR_Z), mesh_fabric)
	# One post down to a five-point base, the way every office chair stands.
	var post := CylinderMesh.new()
	post.top_radius = 0.07
	post.bottom_radius = 0.07
	post.height = CHAIR_SEAT_Y - CHAIR_SEAT.y - FLOOR_Y - 0.1
	_mesh(desk, owner_root, "ChairPost", post,
		Vector3(0.0, FLOOR_Y + 0.1 + post.height * 0.5, CHAIR_Z), chrome)
	for k in range(5):
		var spoke := Node3D.new()
		spoke.name = "ChairLeg%d" % k
		spoke.position = Vector3(0.0, FLOOR_Y + 0.08, CHAIR_Z)
		spoke.rotation = Vector3(0.0, TAU * k / 5.0, 0.0)
		desk.add_child(spoke)
		spoke.owner = owner_root
		_box(spoke, owner_root, "Spoke", Vector3(0.08, 0.07, 0.72),
			Vector3(0.0, 0.0, 0.36), chrome)

func _box(parent: Node3D, owner_root: Node, node_name: String, size: Vector3,
		pos: Vector3, mat: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	_mesh(parent, owner_root, node_name, mesh, pos, mat)

func _mesh(parent: Node3D, owner_root: Node, node_name: String, mesh: Mesh,
		pos: Vector3, mat: Material) -> void:
	var inst := MeshInstance3D.new()
	inst.name = node_name
	inst.mesh = mesh
	inst.material_override = mat
	inst.position = pos
	parent.add_child(inst)
	inst.owner = owner_root

## The windows along the back wall: five panes onto the one sky (see
## OfficeWindows and SkyView), each in a frame, over one long sill.
func _windows(root: Node) -> void:
	var windows := Node3D.new()
	windows.name = "OfficeWindows"
	# A hair off the wall, so the glass never fights it for the same depth.
	windows.position = Vector3(0.0, 0.0, WALL_Z + 0.05)
	windows.set_script(load("res://scripts/view/office_windows.gd"))
	windows.unique_name_in_owner = true
	root.add_child(windows)
	windows.owner = root

	var vp := SubViewport.new()
	vp.name = "SkyViewport"
	vp.size = SKY_PX
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	windows.add_child(vp)
	vp.owner = root
	var sky := Control.new()
	sky.name = "Sky"
	sky.set_script(load("res://scripts/view/sky_view.gd"))
	sky.size = Vector2(SKY_PX)
	vp.add_child(sky)
	sky.owner = root

	var panes := Node3D.new()
	panes.name = "Panes"
	windows.add_child(panes)
	panes.owner = root
	var frames := Node3D.new()
	frames.name = "Frames"
	windows.add_child(frames)
	frames.owner = root

	var metal := _matte(Palette.color(&"window_frame"), 0.5)
	var tall := WINDOW_TOP - WINDOW_SILL
	var mid := (WINDOW_TOP + WINDOW_SILL) * 0.5
	var stand := WINDOW_BAR_DEPTH * 0.5
	for i in range(WINDOW_PANES):
		var x := (i - (WINDOW_PANES - 1) * 0.5) * (WINDOW_W + WINDOW_GAP)
		var glass := QuadMesh.new()
		glass.size = Vector2(WINDOW_W, tall)
		var pane := MeshInstance3D.new()
		pane.name = "Pane%d" % i
		pane.mesh = glass
		pane.position = Vector3(x, mid, 0.0)
		pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		panes.add_child(pane)
		pane.owner = root
		# A bar down each side, one along the bottom, and a transom across -
		# the top of the frame is never in shot.
		for bar in [
				["Left%d" % i, Vector3(x - WINDOW_W * 0.5, mid, stand),
					Vector3(WINDOW_BAR, tall, WINDOW_BAR_DEPTH)],
				["Right%d" % i, Vector3(x + WINDOW_W * 0.5, mid, stand),
					Vector3(WINDOW_BAR, tall, WINDOW_BAR_DEPTH)],
				["Bottom%d" % i, Vector3(x, WINDOW_SILL, stand),
					Vector3(WINDOW_W + WINDOW_BAR, WINDOW_BAR, WINDOW_BAR_DEPTH)],
				["Transom%d" % i, Vector3(x, WINDOW_SILL + tall * 0.62, stand),
					Vector3(WINDOW_W, WINDOW_BAR * 0.6, WINDOW_BAR_DEPTH * 0.8)]]:
			_box(frames, root, bar[0], bar[2], bar[1], metal)
	# One long ledge under the lot.
	var span := WINDOW_PANES * (WINDOW_W + WINDOW_GAP)
	_box(frames, root, "Sill", Vector3(span, WINDOW_BAR * 0.9, 0.4),
		Vector3(0.0, WINDOW_SILL - WINDOW_BAR * 0.9, 0.2), metal)

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
func _hover_pad(index: int, pos: Vector3, card: Vector2, parent: Node,
		owner_root: Node) -> void:
	var body := StaticBody3D.new()
	body.name = "HoverPad%d" % index
	body.position = pos
	body.unique_name_in_owner = true
	parent.add_child(body)
	body.owner = owner_root

	# Exactly the card it sits over - a customer's folder is wider than a
	# product card, and the whole of it should answer the pointer.
	var box := BoxShape3D.new()
	box.size = Vector3(card.x, card.y, 0.1)
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
		anchored: bool = true, card: Vector2 = SLOT_SIZE) -> void:
	var hint := Node3D.new()
	hint.name = node_name
	hint.visible = false
	hint.unique_name_in_owner = true
	zone.add_child(hint)
	hint.owner = owner_root

	# The size of the card it lights up - a customer's folder is wider.
	var slab := QuadMesh.new()
	slab.size = card
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

	# White pills for the piles, which only name a place; filled pills in the
	# button colours for the two drops, which are doing something.
	_tag(hints, root, "DrawTag", ^"Camera3D/Draw/TagAnchor", &"paper", &"neutral_3",
		[["Label", "DRAW", 22, &"ink"]])
	_tag(hints, root, "DiscardTag", ^"Camera3D/Discard/TagAnchor", &"paper", &"neutral_3",
		[["Label", "DISCARD", 22, &"ink"], ["Sub", "drag a card here to dig", 16, &"ink_dim"]])
	# Same top edge as DiscardTag, and only ever shown in its place.
	_tag(hints, root, "DropTag", ^"Camera3D/Discard/DropDragHint/TagAnchor", &"stamp", &"stamp",
		[["Label", "DROP PRODUCT", 24, &"paper"]])
	for i in range(3):
		_tag(hints, root, "OfferTag%d" % i,
			NodePath("Table/Carousel/Seat%d/CustomerZone%d/OfferDragHint%d/TagAnchor" % [i, i, i]),
			&"primary", &"primary", [["Label", "OFFER PRODUCT", 24, &"paper"]])
		_table_note(hints, root, i)
		_close_soon_tag(hints, root, i)

	# --- the shift bar, always ------------------------------------------
	# A white app bar across the top of the screen that the shift's numbers
	# sit on, so they read as a dashboard rather than as text floating over
	# the office wall.
	var strip := PanelContainer.new()
	strip.name = "TopStrip"
	strip.position = Vector2.ZERO
	strip.size = Vector2(1920, TOP_STRIP_HEIGHT)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.unique_name_in_owner = true
	var strip_style := StyleBoxFlat.new()
	strip_style.bg_color = Palette.color(&"panel")
	strip_style.border_color = Palette.color(&"neutral_2")
	strip_style.border_width_bottom = 1
	strip_style.shadow_color = Color(0, 0, 0, 0.18)
	strip_style.shadow_size = 8
	strip_style.shadow_offset = Vector2(0, 2)
	strip.add_theme_stylebox_override("panel", strip_style)
	hud.add_child(strip)
	strip.owner = root

	var top := HBoxContainer.new()
	top.name = "TopBar"
	top.position = Vector2(28, 14)
	top.unique_name_in_owner = true
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
	tick_label.theme_type_variation = &"Heading"
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
	banked.theme_type_variation = &"Heading"
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
	standing_label.theme_type_variation = &"Heading"
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
	at_risk.theme_type_variation = &"Heading"
	at_risk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	at_risk.unique_name_in_owner = true
	top.add_child(at_risk)
	at_risk.owner = root

	# No action column. OFFER, DROP and CLOSE were buttons on the right rail;
	# each is a gesture on the table now - drag the product onto the customer
	# to offer it, onto the discard to drop it, and double-click the empty
	# tablet to close - with O, D and Shift+C still on the keyboard.

	# --- yours: the log, left, stopping short of the draw pile ------------
	# An activity feed: a white card with a small heading over the entries.
	var panel := PanelContainer.new()
	panel.name = "SidePanel"
	panel.position = LOG_RECT.position
	panel.size = LOG_RECT.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.unique_name_in_owner = true
	var card := StyleBoxFlat.new()
	card.bg_color = Palette.color(&"panel")
	card.border_color = Palette.color(&"neutral_2")
	card.set_border_width_all(1)
	card.set_corner_radius_all(14)
	card.content_margin_left = 18
	card.content_margin_right = 16
	card.content_margin_top = 14
	card.content_margin_bottom = 14
	card.shadow_color = Color(0, 0, 0, 0.3)
	card.shadow_size = 10
	card.shadow_offset = Vector2(0, 4)
	panel.add_theme_stylebox_override("panel", card)
	hud.add_child(panel)
	panel.owner = root

	var col := VBoxContainer.new()
	col.name = "Column"
	col.add_theme_constant_override("separation", 8)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(col)
	col.owner = root

	# The heading, and the log's one control beside it: fold the log up to just
	# this row, out of the way of the table, or open it again.
	var head := HBoxContainer.new()
	head.name = "LogHead"
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)
	head.owner = root

	var log_title := Label.new()
	log_title.name = "LogTitle"
	log_title.text = "SHIFT LOG"
	log_title.theme_type_variation = &"Heading"
	log_title.add_theme_font_size_override("font_size", 20)
	log_title.add_theme_color_override("font_color", Palette.color(&"text_dim"))
	log_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	log_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(log_title)
	log_title.owner = root

	var toggle := Button.new()
	toggle.name = "LogToggle"
	toggle.text = "HIDE"
	toggle.custom_minimum_size = LOG_TOGGLE
	toggle.add_theme_font_size_override("font_size", 16)
	ButtonStyle.outlined(toggle, Palette.color(&"ink_dim"))
	toggle.unique_name_in_owner = true
	head.add_child(toggle)
	toggle.owner = root
	_rule(col, root, "TitleRule")

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
	_cover_the_hud(report)
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
	_cover_the_hud(pull_picker)
	pull_picker.unique_name_in_owner = true
	hud.add_child(pull_picker)
	pull_picker.owner = root

## Stretches an instanced overlay over the whole HUD - and says so in ANCHORS
## layout mode, explicitly.
##
## Left to itself the packer saved these two instances in POSITION mode with
## their full-rect anchors alongside. The text scene applies both, in order, so
## every headless run saw a full-screen report. The Web export's binary scene
## drops the anchor overrides as redundant with the instanced scene's own - and
## switching a Control INTO position mode resets its anchors to the top-left,
## so on the Web the report came up at its minimum size in the corner.
func _cover_the_hud(overlay: Control) -> void:
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.set(&"layout_mode", LAYOUT_MODE_ANCHORS)

## A pill on the HUD that follows `anchor` on the table. `lines` is one
## [name, text, font size, palette role] per row, top to bottom; the first is
## the tag's headline, set in the heading face. Starts hidden: the controller
## shows it once it knows where its anchor is.
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
	for k in range(lines.size()):
		var spec: Array = lines[k]
		var l := _line(col, owner_root, spec[0], spec[1], spec[2], spec[3])
		if k == 0:
			l.theme_type_variation = &"Heading"
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
		NodePath("Table/Carousel/Seat%d/Chair%d/TagAnchor" % [i, i]), &"paper", &"neutral_3",
		[["Title", "Nothing on the table", 21, &"ink"],
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

	var close := _line(close_row, owner_root, "Close", "Double-click to\nclose the deal",
		21, &"stamp")
	close.theme_type_variation = &"Heading"

## A customer's CLOSE SOON: a small red tab tucked inside their folder's
## top-right corner, in the strip beside the folder's own tab - see the
## CloseSoonAnchor%d markers. On the HUD like every other hint, so it reads at
## full size on a flanker's folder as well as on yours, and it stays exactly
## where it is while the folder turns over under it. Red with white words: the
## loudest thing on the table, as it should be when the bell is about to take
## what is unsigned.
func _close_soon_tag(parent: Node, owner_root: Node, i: int) -> void:
	var tag := _tag(parent, owner_root, "CloseSoonTag%d" % i,
		NodePath("Table/Carousel/Seat%d/CloseSoonAnchor%d" % [i, i]), &"stamp", &"stamp",
		[["Label", "CLOSE SOON", 18, &"paper"]])
	# Hung from the corner rather than a midpoint, and only just inside it.
	tag.set(&"hang", 1.0)
	tag.set(&"drop_px", 3.0)
	# Slimmer than a pill: it has to fit the strip beside the folder's tab.
	var style := _tag_style(&"stamp", &"stamp")
	style.set_corner_radius_all(8)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 2
	style.content_margin_bottom = 3
	tag.add_theme_stylebox_override("panel", style)

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
	style.bg_color = Palette.color(&"neutral_3")
	rule.add_theme_stylebox_override("panel", style)
	parent.add_child(rule)
	rule.owner = owner_root

## A rounded pill with a hairline edge and a soft shadow, so a tag reads as a
## label floating just off the card rather than a box painted over it.
func _tag_style(fill: StringName, edge: StringName) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Palette.color(fill)
	s.border_color = Palette.color(edge)
	s.set_border_width_all(1)
	s.set_corner_radius_all(12)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 6
	s.content_margin_bottom = 8
	s.shadow_color = Color(0, 0, 0, 0.28)
	s.shadow_size = 6
	s.shadow_offset = Vector2(0, 2)
	return s
