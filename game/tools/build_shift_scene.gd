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
## The cameras are UNPITCHED. These cards are flat quads with text rendered into
## them, and any tilt at all foreshortens the one thing the whole view exists to
## make legible. The table reads as a table because of the felt and the staging,
## not because the camera is leaning over it.

const COLLECTION := "res://addons/card_3d/scenes/card_collection_3d.tscn"
const CUSTOMER_CARD := "res://scenes/cards/customer_card_3d.tscn"
const DETAIL_CARD := "res://scenes/cards/detail_card_3d.tscn"
const REPORT := "res://scenes/report.tscn"

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

## Well behind everything, and now behind the BACK of the circle (z -3) as well.
## Your hand rides at PILE_DEPTH in FRONT of the camera, which puts it at world
## z = cam_z + PILE_DEPTH; if the felt sat closer than that the hand would slide
## behind the table as the camera pushed in and simply vanish. It did.
## test_shift_scene.gd pins the clearance now.
const FELT_Z := -14.0

## See the header. K = 540 / tan(14deg) = 2165.85.
const CAM_FOV := 28.0
## ONE seat camera, not three: the carousel does the moving, so the camera only
## ever travels between these two points, both on the axis and both unpitched.
##
## Near card plane 6.03, so N = 18.90 and a card is 2.5x3.5 x (K/N) = 286x402 px
## - pixel-identical to the pre-carousel floor card, which is why the >= 360 px
## readability floor survives untouched for whoever is at the front.
const FLOOR_CAM := Vector3(0.0, 4.00, 24.93)
## N = 21.17 here, and K/N = 102.31 against the old framing's 102.33: the
## negotiation lands on the pixels it already landed on, and the flankers are
## pure addition on either side of it.
const SEAT_CAM := Vector3(0.0, 1.40, 27.20)

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
const MODE_RECT := Rect2(28, 40, 360, 84)
## Stops well above the bottom strip, which is where the discard rises into.
const LOG_RECT := Rect2(1480, 40, 416, 690)
## A column, not a row. The bottom of the screen belongs to the hand and the two
## piles, and a Button laid over a card steals the click meant for the card.
##
## LEFT rail now, mirroring the log. The right rail is fully spoken for (log
## 1480..1896, discard 1607..1879) and the 155 px gutters inside the carousel
## composition are too narrow for a 300 px button. Real cost: OFFER/DROP/CLOSE
## sit further from the product they act on. It is the only placement that
## satisfies "no button sits on a card" for five card rects instead of four.
const ACTION_RECT := Rect2(96, 300, 330, 340)
const ACTION_BUTTON := Vector2(330, 100)

func _init() -> void:
	var root := Node3D.new()
	root.name = "ShiftRoot"
	root.set_script(load("res://scripts/view/shift_controller.gd"))

	var cam := Camera3D.new()
	cam.name = "Camera3D"
	cam.fov = CAM_FOV
	cam.current = true
	cam.position = FLOOR_CAM
	root.add_child(cam)
	cam.owner = root

	var floor_mark := Marker3D.new()
	floor_mark.name = "CameraFloor"
	floor_mark.position = FLOOR_CAM
	floor_mark.unique_name_in_owner = true
	root.add_child(floor_mark)
	floor_mark.owner = root

	var light := DirectionalLight3D.new()
	light.name = "DirectionalLight3D"
	light.position = Vector3(0, 12, 18)
	light.rotation_degrees = Vector3(-38, -22, 0)
	light.light_energy = 1.2
	light.shadow_enabled = true
	light.shadow_opacity = 0.55
	light.shadow_blur = 3.0
	root.add_child(light)
	light.owner = root

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Palette.color(&"neutral_1")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Palette.color(&"panel_hi")
	env.ambient_light_energy = 1.0
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	root.add_child(we)
	we.owner = root

	var felt := QuadMesh.new()
	felt.size = Vector2(220, 130)
	var felt_mat := StandardMaterial3D.new()
	felt_mat.albedo_color = Palette.color(&"bg")
	felt_mat.roughness = 0.95
	var table_mesh := MeshInstance3D.new()
	table_mesh.name = "Felt"
	table_mesh.mesh = felt
	table_mesh.material_override = felt_mat
	table_mesh.position = Vector3(0, 0, FELT_Z)
	root.add_child(table_mesh)
	table_mesh.owner = root

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
		var theta := deg_to_rad(120.0 * i)
		var seat := Node3D.new()
		seat.name = "Seat%d" % i
		seat.position = Vector3(CAROUSEL_R * sin(theta), 0.0, CAROUSEL_R * cos(theta))
		seat.unique_name_in_owner = true
		carousel.add_child(seat)
		seat.owner = root

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
		_mark(chair, root, "SEAT %s\ndrag a product here" % ["A", "B", "C"][i],
			Palette.color(&"appeal"))

		_detail(detail_scene, "OfferDetail%d" % i,
			Vector3(0.0, CHAIR_Y, BACK_Z), seat, root)


	var seat_cam := Marker3D.new()
	seat_cam.name = "SeatCam"
	seat_cam.position = SEAT_CAM
	seat_cam.unique_name_in_owner = true
	root.add_child(seat_cam)
	seat_cam.owner = root

	# --- yours: parented to the camera, stowed below frame ----------------
	var hand := _collection(collection_scene, "Hand", HAND_STOWED, cam, root)
	var fan := FanCardLayout.new()
	fan.arc_angle_deg = FAN_ANGLE
	fan.arc_radius = FAN_RADIUS
	hand.card_layout_strategy = fan
	_mark(hand, root, "YOUR HAND", Palette.color(&"margin"))

	var discard := _collection(collection_scene, "Discard", DISCARD_STOWED, cam, root)
	discard.card_layout_strategy = PileCardLayout.new()
	_mark(discard, root, "DISCARD\ndrag here to dig", Palette.color(&"action"))

	var draw := _collection(collection_scene, "Draw", DRAW_STOWED, cam, root)
	draw.card_layout_strategy = PileCardLayout.new()
	_mark(draw, root, "DRAW", Palette.color(&"neutral_3"))

	var drag := DragController.new()
	drag.name = "DragController"
	# Camera-local 16.60 from SEAT_CAM, the same fraction of the way to the
	# table that 7.17 was before the lens changed.
	drag.card_drag_plane = Plane(Vector3(0, 0, 1), 10.60)
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

func _collection(scene: PackedScene, node_name: String, pos: Vector3,
		parent: Node, owner_root: Node) -> Node3D:
	var c := scene.instantiate()
	c.name = node_name
	c.position = pos
	c.unique_name_in_owner = true
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

## A labelled translucent slab behind a zone - the only thing that makes a
## CardCollection3D visible in the editor, and a useful "drop here" at runtime.
func _mark(zone: Node3D, owner_root: Node, text: String, tint: Color) -> void:
	var slab := QuadMesh.new()
	slab.size = SLOT_SIZE
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(tint.r, tint.g, tint.b, 0.16)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var mesh := MeshInstance3D.new()
	mesh.name = "ZoneSlab"
	mesh.mesh = slab
	mesh.material_override = mat
	mesh.position = Vector3(0, 0, -0.05)
	zone.add_child(mesh)
	mesh.owner = owner_root

	var label := Label3D.new()
	label.name = "ZoneLabel"
	label.text = text
	label.font_size = 64
	label.pixel_size = 0.005
	label.modulate = tint
	label.outline_size = 10
	label.outline_modulate = Palette.color(&"neutral_1")
	label.shaded = false
	label.double_sided = false
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.position = Vector3(0, -2.3, 0.02)
	zone.add_child(label)
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

	# --- the shift bar, always ------------------------------------------
	var top := HBoxContainer.new()
	top.name = "TopBar"
	top.position = Vector2(28, 18)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 48)
	hud.add_child(top)
	top.owner = root

	var placeholders := {
		"TickLabel": "tick 0/24",
		"BankedLabel": "banked $0 / $3,600",
		"StandingLabel": "standing 100/100",
		"AtRiskLabel": "nothing unsigned",
	}
	for label_name in placeholders:
		var l := Label.new()
		l.name = label_name
		l.text = placeholders[label_name]
		l.add_theme_font_size_override("font_size", 30)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.unique_name_in_owner = true
		top.add_child(l)
		l.owner = root

	# --- the one button that changes where you are ------------------------
	# Big and obvious on purpose: with the other two seats hidden while you
	# negotiate, this is how you check on them, so it must never be a hunt.
	var mode := Button.new()
	mode.name = "ModeButton"
	mode.text = "RETURN TO FLOOR"
	mode.position = MODE_RECT.position
	mode.size = MODE_RECT.size
	mode.custom_minimum_size = MODE_RECT.size
	mode.add_theme_font_size_override("font_size", 28)
	mode.unique_name_in_owner = true
	hud.add_child(mode)
	mode.owner = root

	# --- yours: the action column, right of the table and left of the log --
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

	# --- yours: the log, right, stopping short of the discard -------------
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
