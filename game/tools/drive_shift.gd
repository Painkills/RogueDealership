extends SceneTree
## Drives a real shift.tscn and checks the table matches the model after every
## command, plus the two framings, the things that ride with the camera, and
## where every card actually lands ON SCREEN.
##
## NOT part of run_tests.gd and cannot be: the suite runs inside _init(), and
## adding a node to the tree there does not fire _ready() synchronously (found
## the hard way during G1). Everything here needs a live _ready(), so it waits
## for the first _process() frame.
##
##   godot --headless --path game --script res://tools/drive_shift.gd
##
## The screen-space checks are the point of this file now. "The customer card
## gets overlapped by the product card" and "the panel is not in position and
## overlaps the product area" were both found by eye, twice, after being
## shipped - they are arithmetic, and arithmetic should not need eyes.
##
## What it still CANNOT tell you: whether any of it is legible, whether cards
## land where you aimed, or whether the movement feels right. Real mouse picking
## needs a stepped physics space and a real camera ray, and faking it would only
## produce a test that lies.

const CARD := Vector2(2.5, 3.5)
## Nothing of the table may reach into the right-hand column, which belongs to
## the shift log for the whole shift.
const LOG_EDGE := 1480.0

var _controller: Node3D
var _done := false
var _failures: Array[String] = []
var _checks := 0

func _init() -> void:
	# The controller seeds its shift from randi(), so without pinning the global
	# RNG this plays a DIFFERENT game every run and its failures wander. Found
	# the hard way: a run reporting "all passed" had simply been dealt a kind
	# shift.
	seed(20260903)
	_controller = (load("res://scenes/shift.tscn") as PackedScene).instantiate()
	get_root().add_child(_controller)

## _physics_process, not _process: the pick checks query the physics space, and
## the space state is only valid to query during a physics frame.
func _physics_process(_delta: float) -> bool:
	if _done:
		return true
	_done = true

	# The controller no longer builds its own shift - the run layer does. The
	# driver stands in for the run layer here. This has to wait for the first
	# physics frame, not run alongside add_child() in _init(): the controller's
	# @onready fields (_event_log, _report_overlay, the card zones setup()
	# touches) are not populated until _ready() fires, and _ready() does not
	# fire synchronously on a node added to the tree from within _init().
	# A standalone driven shift has no real RunState behind it, so a full meter
	# is the honest stand-in.
	_controller.setup(Shift.new(load("res://data/shift_config.tres"),
		load("res://data/interests/interest_pool.tres"),
		load("res://data/card_pool.tres"),
		load("res://data/archetype_pool.tres"), randi()), 100)

	_check("the viewport is picking, or no card can ever be clicked",
		get_root().physics_object_picking)
	_check("the drag controller knows about all six zones",
		_controller._drag._card_collections.size() == 6)
	_check("and found a camera to ray through", _controller._drag._camera != null)
	_check("a shift is running", _controller._shift != null)
	_check("the hand fans", _controller._hand_zone.card_layout_strategy is FanCardLayout)

	_check_the_player_rides_the_camera()
	_check_floor_view_is_bare()
	_check_the_floor_cards_are_big_enough_to_read()
	_check_you_can_actually_click_the_customers()
	_check_the_hover_target_survives_its_own_flip()
	_check_hovering_a_customer_turns_their_card_over()
	_check_tapping_a_seat_peeks_before_it_approaches()
	_check_pressing_a_hand_card_lifts_it_like_hovering_would()
	_check_table("on arrival")

	_press(KEY_A)
	_settle()
	_check_you_can_actually_click_your_hand()
	_check_seat_view_brings_your_things_up()
	_check_only_the_seat_you_are_at_is_showing()
	_check_the_detail_cards_slid_out_clear()
	_check_the_seat_layout_does_not_overlap_itself()
	_check_the_customer_card_shows_who_they_are()
	_check_the_detail_card_shows_what_they_do()
	_check_the_action_buttons_stay_on_screen()
	_check_hud_does_not_overlap_itself()
	_check_table("after approaching chair A")

	_check_the_mode_button_flips()

	_put_a_product_on_the_table()
	_check_the_meter_shows_your_appeal_but_hides_their_line()
	_check_the_meter_climbs_and_changes_colour()
	_press(KEY_O);            _settle(); _check_table("after offering")
	_check_the_meter_reveals_the_line_once_you_have_asked()
	_press(KEY_2, true);      _settle(); _check_table("after digging hand card 2")
	_press(KEY_C, true);      _settle(); _check_table("after closing")
	_press(KEY_B);            _settle(); _check_table("after approaching chair B")

	_check_drop_plays_a_card()
	_check_refused_drop_comes_home()
	_check_an_empty_floor_does_not_end_the_shift()   # LAST: it empties the floor
	_check_a_fatal_shift_shows_its_own_report()      # replaces _shift entirely

	print("")
	# Guards against the failure mode that has now bitten three times: a runtime
	# error aborts one check function, the remaining checks never run, and the
	# summary happily reports "all passed" on whatever did.
	const EXPECTED_MIN := 100
	if _checks < EXPECTED_MIN:
		print("FAIL  only %d checks ran, expected at least %d - something aborted"
			% [_checks, EXPECTED_MIN])
		_failures.append("check count collapsed")

	if _failures.is_empty():
		print("%d checks, all passed" % _checks)
		quit(0)
	else:
		for f in _failures:
			print("FAIL  " + f)
		print("%d checks, %d FAILED" % [_checks, _failures.size()])
		quit(1)
	return true

func _press(keycode: Key, shift: bool = false) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.shift_pressed = shift
	ev.pressed = true
	_controller._unhandled_input(ev)

## Tweens do not advance in a single headless frame, so fast-forward them or
## every position assertion would read the value it started from.
func _settle() -> void:
	var t = _controller._framing_tween
	if t != null and t.is_valid() and t.is_running():
		t.custom_step(2.0)
	# Each detail card owns its own slide tween, so stepping the controller's
	# framing tween alone leaves them halfway out from behind their partner.
	for card in _controller._customer_details + _controller._offer_details:
		var st = card._slide_tween
		if st != null and st.is_valid() and st.is_running():
			st.custom_step(2.0)

	# A tween writes to the NODE; the physics server only learns about it when
	# the transform is flushed, which normally happens between frames. The pick
	# checks run inside this same frame, so flush by hand or every ray reports
	# "hit nothing" against colliders that are simply still at last frame's
	# position - a false failure that looks exactly like the real bug.
	for flip in _controller._customer_flips:
		var ft = flip._tween
		if ft != null and ft.is_valid() and ft.is_running():
			ft.custom_step(2.0)

	_controller._camera.force_update_transform()
	for flip in _controller._customer_flips:
		(flip as Node3D).force_update_transform()
	for card in _controller._customer_details + _controller._offer_details:
		_flush(card)
	for zone in _controller._all_zones():
		zone.force_update_transform()
		for card in zone.cards:
			_flush(card)
	for card in _controller._customer_cards:
		_flush(card)

func _flush(node: Node3D) -> void:
	# Each card also owns the tween that walks it to its place in the layout.
	# Leave those unstepped and the whole hand is still stacked on the
	# collection's origin, so every card unprojects to the same pixel.
	if node is Card3D:
		var pt = (node as Card3D).position_tween
		if pt != null and pt.is_valid() and pt.is_running():
			pt.custom_step(2.0)
	node.force_update_transform()
	var body := node.get_node_or_null(^"StaticBody3D") as Node3D
	if body != null:
		body.force_update_transform()

# --- geometry --------------------------------------------------------------

func _screen() -> Vector2:
	return Vector2(
		ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height"))

## Where a card-shaped thing lands on screen, in pixels.
func _rect_of(node: Node3D, size: Vector2) -> Rect2:
	var cam: Camera3D = _controller._camera
	var centre := node.global_position
	var tl := cam.unproject_position(centre + Vector3(-size.x * 0.5, size.y * 0.5, 0.0))
	var br := cam.unproject_position(centre + Vector3(size.x * 0.5, -size.y * 0.5, 0.0))
	return Rect2(tl, br - tl)

func _on_screen(label: String, r: Rect2) -> void:
	var s := _screen()
	_check("%s is on screen (%s)" % [label, r],
		r.position.x >= 0.0 and r.position.y >= 0.0
			and r.end.x <= s.x and r.end.y <= s.y)

func _frame_half_height() -> float:
	return absf(_controller.HAND_UP.z) \
		* tan(deg_to_rad(_controller._camera.fov * 0.5))

func _at() -> int:
	return int(_controller._shift.at)

# --- can you touch it ------------------------------------------------------

## The reported bug, and the most expensive one this project has shipped: "the
## cards are untouchable, they do not respond to hover nor clicks."
##
## Godot's 3D picking fires ONE ray and takes the CLOSEST collider, so anything
## in front of a card silently owns every click meant for it. What was in front
## was a CardCollection3D DropZone - a StaticBody3D on a 14 x 4 slab, 3.2 units
## nearer the camera than the cards - left enabled outside a drag by a previous
## version of shift_controller.gd.
##
## So this asks the physics space the same question the engine asks, rather than
## asking the scene tree a question that was never the one that mattered.
func _pick_at(p: Vector2) -> Node:
	var cam: Camera3D = _controller._camera
	var from := cam.project_ray_origin(p)
	var q := PhysicsRayQueryParameters3D.create(
		from, from + cam.project_ray_normal(p) * 200.0)
	q.collide_with_areas = true
	q.collide_with_bodies = true
	var hit := get_root().world_3d.direct_space_state.intersect_ray(q)
	return hit["collider"] if not hit.is_empty() else null

func _picks(node: Node3D) -> Node:
	var cam: Camera3D = _controller._camera
	if cam.is_position_behind(node.global_position):
		return null
	return _pick_at(cam.unproject_position(node.global_position))

func _check_picks(label: String, node: Node3D) -> void:
	var hit := _picks(node)
	var owner_node: Node = hit.get_parent() if hit != null else null
	_check("clicking %s reaches it, not %s"
		% [label, "nothing at all" if hit == null else hit.get_path()],
		owner_node == node)

## Aimed at the card, but the thing it must find is that seat's PAD - the card's
## own collider is disabled precisely so the two can never disagree about
## whether the mouse is here.
func _check_pad_owns(label: String, chair: int) -> void:
	var hit := _picks(_controller._customer_cards[chair])
	_check("the mouse over %s finds seat %d's pad, not %s"
		% [label, chair, "nothing at all" if hit == null else hit.get_path()],
		hit == _controller._hover_pads[chair])

func _check_you_can_actually_click_the_customers() -> void:
	for i in range(3):
		_check_pad_owns("customer %d on the floor" % i, i)
		_check("and customer %d's own collider is disabled, so it cannot argue" % i,
			(_controller._customer_cards[i].get_node(^"StaticBody3D/CollisionShape3D")
				as CollisionShape3D).disabled)
	_check_no_drop_zone_is_armed("on the floor")

## The reported bug: "hover makes the card stutter between flipping and not
## flipping, unless you come in from a certain angle."
##
## The cause was that the hover target WAS the thing the hover moved. A card is
## a flat quad with no thickness, so as it turns its projected area shrinks to
## nothing: the ray stopped finding it, the mouse "left", the flip reversed, the
## mouse "entered", forever. Measured with probe_input.gd before the fix - aimed
## near the card's edge, the collider was gone from 75 degrees onward and did not
## come back until 180.
##
## So this walks the pair through a full turn and asserts what the mouse finds
## never changes. Both at the centre AND near the edge, because which of the two
## you were over is what decided whether it settled.
func _check_the_hover_target_survives_its_own_flip() -> void:
	var flip = _controller._customer_flips[1]
	var pad: Node3D = _controller._hover_pads[1]
	var cam: Camera3D = _controller._camera
	var probes := {
		"centre": cam.unproject_position(pad.global_position),
		"near the edge": cam.unproject_position(
			pad.global_position + Vector3(-1.0, 0.0, 0.0)),
	}
	for deg in [0, 45, 75, 89, 90, 105, 135, 180]:
		flip.rotation.y = deg_to_rad(deg)
		(flip as Node3D).force_update_transform()
		for where in probes:
			var hit := _pick_at(probes[where])
			_check("mid-flip at %3d deg, %s of the card still finds the pad (%s)"
				% [deg, where, "nothing" if hit == null else hit.name], hit == pad)
	flip.rotation.y = 0.0
	(flip as Node3D).force_update_transform()

func _check_you_can_actually_click_your_hand() -> void:
	var hand: CardCollection3D = _controller._hand_zone
	if hand.cards.is_empty():
		_check("there are cards in hand to click", false)
		return
	# Aimed at each card's centre, but only required to reach SOME card in the
	# hand: they are fanned, so every card but the topmost has its middle
	# covered by its neighbour, and you click the sliver that is showing. What
	# must never happen is the ray reaching a drop zone, or nothing at all.
	for card in hand.cards:
		var hit := _picks(card)
		var reached: Node = hit.get_parent() if hit != null else null
		_check("a hand card's pixels belong to the hand, not to %s"
			% ("nothing at all" if hit == null else hit.get_path()),
			reached != null and hand.cards.has(reached))
	# The topmost card of the fan has nothing over it, so it must resolve to
	# exactly itself - which is the strict form of the same question.
	_check_picks("the top card of the fan", hand.cards[hand.cards.size() - 1])
	_check_pad_owns("the customer you are sitting with", _at())
	_check_no_drop_zone_is_armed("at a seat")
	_check_the_hand_shows_enough_of_every_card()

## The reported bug: "the hand isn't always legible - cards on the far left have
## some of their info covered by cards on the right."
##
## Two causes, both fixed here. The fan was short and steep: adjacent cards sat
## 0.9 apart on a 2.5-wide card, so each was four fifths covered, and the ends
## drooped 79 px below the middle. And hovering only lifted a card UP, which
## does nothing about the card overlapping it from the right - so hovering could
## not rescue the reading either. The lift now comes FORWARD as well.
func _check_the_hand_shows_enough_of_every_card() -> void:
	var cards: Array = _controller._hand_zone.cards
	if cards.size() < 2:
		_check("there is more than one card in hand to overlap", false)
		return
	var rects: Array[Rect2] = []
	for c in cards:
		rects.append(_rect_of(c, CARD))
	rects.sort_custom(func(a, b): return a.position.x < b.position.x)

	var lowest := 0.0
	var highest := 99999.0
	for i in range(rects.size()):
		lowest = maxf(lowest, rects[i].position.y)
		highest = minf(highest, rects[i].position.y)
		if i + 1 >= rects.size():
			continue
		# What is left of a card once its right-hand neighbour is laid over it.
		var showing: float = rects[i + 1].position.x - rects[i].position.x
		_check("hand card %d still shows %d px of its %d (left edge to the next card)"
			% [i, int(showing), int(rects[i].size.x)],
			showing >= rects[i].size.x * 0.45)
	_check("and the fan is level enough to read across (%d px of droop)"
		% int(lowest - highest), lowest - highest <= 40.0)
	# Hovering has to bring a card FORWARD, not just up: raised in place it is
	# still covered by the card to its right, which is the reported symptom.
	_check("hovering brings a card toward you, not only upward (%s)"
		% _controller.HAND_HOVER_LIFT,
		_controller.HAND_HOVER_LIFT.z > 0.0 and _controller.HAND_HOVER_LIFT.y > 0.0)
	for c in cards:
		_check("and every hand card is set up to lift that far",
			(c as Card3D).hover_pos_move == _controller.HAND_HOVER_LIFT)

	# The reported bug, second half: "it is still not always easy to read the
	# bottom part of the card." The hand runs off the bottom of the screen on
	# purpose, so the lift has to be enough to bring the WHOLE card back inside
	# the frame - measured by actually hovering the lowest card in the fan, not
	# by trusting the constant.
	var lowest_card = cards[0]
	for c in cards:
		if _rect_of(c, CARD).end.y > _rect_of(lowest_card, CARD).end.y:
			lowest_card = c
	var resting := _rect_of(lowest_card, CARD)
	lowest_card.set_hovered()
	var hover_tween = lowest_card.hover_tween
	if hover_tween != null and hover_tween.is_valid():
		hover_tween.custom_step(2.0)
	var mesh := lowest_card.get_node(^"CardMesh") as Node3D
	mesh.force_update_transform()
	var lifted := _rect_of(mesh, CARD * lowest_card.scale.x)
	lowest_card.remove_hovered()

	_check("hovering the lowest card in the fan brings its bottom back on screen"
		+ " (%d -> %d of 1080)" % [int(resting.end.y), int(lifted.end.y)],
		lifted.end.y <= _screen().y)
	_check("and its top too, so the whole card is readable (%d)"
		% int(lifted.position.y), lifted.position.y >= 0.0)

## The permanent guard. A drop zone armed outside a drag is a wall in front of
## the whole table, and it is invisible - nothing on screen says why the game
## stopped responding.
func _check_no_drop_zone_is_armed(when: String) -> void:
	var armed: Array[String] = []
	for zone in _controller._all_zones():
		if not (zone.get_node(^"DropZone/CollisionShape3D") as CollisionShape3D).disabled:
			armed.append(String(zone.name))
	_check("%s, with no card in hand-to-table flight, no drop zone is armed (%s)"
		% [when, "none" if armed.is_empty() else ", ".join(armed)], armed.is_empty())

# --- the floor -------------------------------------------------------------

func _check_the_player_rides_the_camera() -> void:
	var cam = _controller._camera
	for pair in [["hand", _controller._hand_zone], ["draw", _controller._draw_zone],
			["discard", _controller._discard_zone]]:
		_check("your %s is parented to the camera, so it travels with you" % pair[0],
			(pair[1] as Node3D).get_parent() == cam)

func _check_floor_view_is_bare() -> void:
	var bottom := -_frame_half_height()
	for pair in [["hand", _controller._hand_zone], ["draw", _controller._draw_zone],
			["discard", _controller._discard_zone]]:
		var z := pair[1] as Node3D
		_check("on the floor your %s is stowed below frame (top %.1f < %.1f)"
			% [pair[0], z.position.y + CARD.y * 0.5, bottom],
			z.position.y + CARD.y * 0.5 < bottom)
	# The floor is customer cards and nothing else. The product slot, whatever is
	# sitting in it and its detail card all belong to the negotiation - and the
	# detail card would be showing its blank back down there anyway.
	for i in range(3):
		_check("the product slot at seat %d is out of sight on the floor" % i,
			not _controller._chair_zones[i].visible)
		_check("and so is seat %d's detail card, which faces away" % i,
			not _controller._offer_details[i].visible)
		# One line on the floor card is what tells you a product is still sitting
		# with someone, now that you cannot see the slot.
		_check("but the floor card still says what you left with them",
			_controller._customer_cards[i]._status.visible)
	_check("no action bar on the floor - there is nobody to act on",
		not _controller._action_bar.visible)
	for i in range(3):
		_check("seat %d is visible on the floor" % i, _controller._seats[i].visible)
		_check("seat %d keeps its detail cards tucked away" % i,
			not _controller._customer_details[i].is_out()
				and not _controller._offer_details[i].is_out())

## The hover tooltip is gone; what a customer DOES is the back of their card.
## The pair has to turn as one, or you see the back of the front card and
## nothing else - which is why the flip lives on the parent and not the cards.
func _check_hovering_a_customer_turns_their_card_over() -> void:
	var flip = _controller._customer_flips[1]
	var detail: DetailCard3D = _controller._customer_details[1]
	var card: CustomerCard3D = _controller._customer_cards[1]

	_check("at rest the pair is face-front", not flip.showing_back())
	_check("with the detail card tucked behind (%.2f < %.2f)"
		% [detail.global_position.z, card.global_position.z],
		detail.global_position.z < card.global_position.z)

	_controller._on_customer_hover(1)
	_settle()
	_check("hovering turns it over", flip.showing_back())
	_check("and the detail card is now the one in front (%.2f > %.2f)"
		% [detail.global_position.z, card.global_position.z],
		detail.global_position.z > card.global_position.z)
	_check("the pad is untouched by the turn, so the hover cannot cancel itself",
		_picks(card) == _controller._hover_pads[1])
	# Only the card you are pointing at.
	_check("the seats you are not pointing at stay face-front",
		not _controller._customer_flips[0].showing_back()
			and not _controller._customer_flips[2].showing_back())

	_controller._on_customer_unhover(1)
	_settle()
	_check("and it turns back when you look away", not flip.showing_back())
	_check("with the detail behind again (%.2f < %.2f)"
		% [detail.global_position.z, card.global_position.z],
		detail.global_position.z < card.global_position.z)

## Touch has no hover, so a click alone cannot mean "go to them" the way it
## does for a mouse - hovering already flipped the card before the click ever
## lands, but a bare tap has flipped nothing. One rule serves both without
## asking which device this is: the first press on a seat only peeks it; a
## SECOND press on that already-peeked seat is what approaches.
func _check_tapping_a_seat_peeks_before_it_approaches() -> void:
	const CHAIR := 1
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true

	_check("nobody peeked at rest", _controller._peeked == -1)
	_check("and the card is face-front, from the hover test above",
		not _controller._customer_flips[CHAIR].showing_back())

	_controller._on_pad_input(null, down, Vector3.ZERO, Vector3.ZERO, 0, CHAIR)
	_check("a first tap only peeks - it has not approached",
		_controller._shift.at == null)
	_check("and shows their back, the same as hovering would",
		_controller._customer_flips[CHAIR].showing_back())

	_controller._on_pad_input(null, down, Vector3.ZERO, Vector3.ZERO, 0, CHAIR)
	_check("a SECOND tap on the already-peeked seat approaches",
		_controller._shift.at == CHAIR)
	_check("and clears the peek - it is a real seat now, not a lingering one",
		_controller._peeked == -1)

	# Leave the floor exactly as the rest of this file's sequence expects it -
	# nobody standing anywhere, ready for _press(KEY_A) right after this.
	_controller._apply(_controller._shift.leave())
	_check("back on the floor for what follows", _controller._shift.at == null)

## card_selected fires on the raw PRESS, before DragController's own threshold
## check decides whether this becomes a real drag - which is exactly the moment
## touch needs covered. A mouse never notices: hovering already lifted the card
## by the time it gets pressed, and re-tweening to the same target is a no-op.
func _check_pressing_a_hand_card_lifts_it_like_hovering_would() -> void:
	var hand: CardCollection3D = _controller._hand_zone
	if hand.cards.is_empty():
		_check("there is a hand card to press", false)
		return
	var card: Card3D = hand.cards[hand.cards.size() - 1]
	var mesh := card.get_node(^"CardMesh") as Node3D

	card.remove_hovered()
	if card.hover_tween != null and card.hover_tween.is_valid():
		card.hover_tween.custom_step(2.0)
	_check("at rest the mesh sits at home (%s)" % mesh.position,
		mesh.position.is_equal_approx(Vector3.ZERO))

	hand.card_selected.emit(card)
	if card.hover_tween != null and card.hover_tween.is_valid():
		card.hover_tween.custom_step(2.0)
	_check("a bare press lifts it, same offset hovering would use (%s)" % mesh.position,
		mesh.position.is_equal_approx(_controller.HAND_HOVER_LIFT))

	hand.card_deselected.emit(card)
	if card.hover_tween != null and card.hover_tween.is_valid():
		card.hover_tween.custom_step(2.0)
	_check("releasing it without a drag settles it back down (%s)" % mesh.position,
		mesh.position.is_equal_approx(Vector3.ZERO))

## The reported bug, in its own words: "when zoomed out its TOO far and is
## illegible". The card face is authored at 500x700, so anything under about
## half that is a face being thrown away. It used to land at 126 pixels tall.
func _check_the_floor_cards_are_big_enough_to_read() -> void:
	for i in range(3):
		var r := _rect_of(_controller._customer_cards[i], CARD)
		_check("floor card %d is %d px tall, enough of a 700 px face to read"
			% [i, int(r.size.y)], r.size.y >= 360.0)
		_on_screen("floor card %d" % i, r)
		_check("floor card %d stays out of the log's column (ends %d, log at %d)"
			% [i, int(r.end.x), int(LOG_EDGE)], r.end.x <= LOG_EDGE)

# --- a seat ----------------------------------------------------------------

func _check_seat_view_brings_your_things_up() -> void:
	var bottom := -_frame_half_height()
	for pair in [["hand", _controller._hand_zone], ["discard", _controller._discard_zone]]:
		var z := pair[1] as Node3D
		_check("sitting down raises your %s into view (y %.1f > %.1f)"
			% [pair[0], z.position.y, bottom], z.position.y > bottom)
	_check("and the action bar appears", _controller._action_bar.visible)

## The seats are close enough together that the floor view is readable, which
## puts the neighbours inside the seat framing. So they are hidden - and the
## mode button, which promises a free return, is the only way back to them.
func _check_only_the_seat_you_are_at_is_showing() -> void:
	for i in range(3):
		_check("seat %d is %s while you are at %d"
			% [i, "showing" if i == _at() else "hidden", _at()],
			_controller._seats[i].visible == (i == _at()))

	# A hidden seat must still refuse drops - you should not be able to drag a
	# card into a customer you cannot see. That is enforced DURING the drag,
	# after DragController has armed everything, because arming a drop zone
	# outside a drag walls off the entire table. Simulate the drag start.
	_controller._on_drag_started(null)
	for i in range(3):
		var zone := _controller._chair_zones[i].get_node(
			^"DropZone/CollisionShape3D") as CollisionShape3D
		if i == _at():
			continue
		_check("hidden seat %d refuses a drop even mid-drag" % i, zone.disabled)
	_controller._on_drag_stopped(null)
	_check_no_drop_zone_is_armed("once the drag is over")

func _check_the_detail_cards_slid_out_clear() -> void:
	var at := _at()
	var margins: Array[float] = []
	# You reach a seat by CLICKING a customer, which means you were hovering them,
	# which means their pair was turned over. It has to turn back before the
	# detail card slides, or the slide happens in a mirrored space and the card
	# travels the wrong way.
	_check("arriving turns the pair back to face front",
		not _controller._customer_flips[at].showing_back())
	for pair in [["customer", _controller._customer_details[at],
				_controller._customer_cards[at]],
			["offer", _controller._offer_details[at],
				_controller._chair_zones[at]]]:
		var detail: Node3D = pair[1]
		var partner: Node3D = pair[2]
		_check("the %s detail card slid out from behind" % pair[0],
			detail.is_out() and not detail.position.is_equal_approx(detail.home()))
		# It comes out facing the other way and has to turn as it goes, or it
		# arrives beside its partner still showing its own back.
		_check("and turned to face front (%s)" % detail.rotation,
			detail.rotation.is_equal_approx(Vector3.ZERO))

		var d := _rect_of(detail, DetailCard3D.CARD_SIZE)
		var p := _rect_of(partner, CARD)
		_check("and it is clear of what it describes (detail ends %d, partner starts %d)"
			% [int(d.end.x), int(p.position.x)], d.end.x <= p.position.x)
		_check("on the LEFT of it, as designed", d.position.x < p.position.x)
		_check("not on top of it", not d.intersects(p))
		_check("and it is the same size as what it hides behind (%d x %d vs %d x %d)"
			% [int(d.size.x), int(d.size.y), int(p.size.x), int(p.size.y)],
			absf(d.size.x - p.size.x) < 2.0 and absf(d.size.y - p.size.y) < 2.0)
		_on_screen("%s detail card" % pair[0], d)
		_check("%s detail stays out of the log's column (ends %d)"
			% [pair[0], int(d.end.x)], d.end.x <= LOG_EDGE)
		margins.append(p.position.x - d.end.x)

	# "There should be an equal margin between the main cards and the detail
	# cards for both product and customer." It is the same offset applied to two
	# slots of the same width, so this is really checking that the SLOT is still
	# card-sized - a wider slab behind the product would put its visible edge
	# somewhere the customer's is not.
	_check("the two margins match (customer %.0f px, product %.0f px)"
		% [margins[0], margins[1]], absf(margins[0] - margins[1]) < 2.0)

	for i in range(3):
		if i == at:
			continue
		_check("seat %d's detail cards stayed home" % i,
			not _controller._customer_details[i].is_out()
				and not _controller._offer_details[i].is_out())

## The reported bug: "when zoomed in, the customer card gets overlapped by the
## product card". Four card rectangles, none of which may touch another.
func _check_the_seat_layout_does_not_overlap_itself() -> void:
	var at := _at()
	var rects := {
		"customer card": _rect_of(_controller._customer_cards[at], CARD),
		"customer detail": _rect_of(_controller._customer_details[at],
			DetailCard3D.CARD_SIZE),
		"product slot": _rect_of(_controller._chair_zones[at], CARD),
		"offer detail": _rect_of(_controller._offer_details[at],
			DetailCard3D.CARD_SIZE),
	}
	var names := rects.keys()
	for a in range(names.size()):
		for b in range(a + 1, names.size()):
			var ra: Rect2 = rects[names[a]]
			var rb: Rect2 = rects[names[b]]
			_check("the %s never overlaps the %s (%s vs %s)"
				% [names[a], names[b], ra, rb], not ra.intersects(rb))
	for n in names:
		_on_screen(n, rects[n])
		_check("%s is big enough to read (%d px tall)" % [n, int(rects[n].size.y)],
			rects[n].size.y >= 300.0)

	# The bug before that: the hand rose and covered the product. It is allowed
	# to run off the bottom of the screen, but not up over the table.
	var hand_top: float = _controller._camera.unproject_position(
		_controller._hand_zone.global_position + Vector3(0, CARD.y * 0.5, 0)).y
	var lowest: float = 0.0
	for n in names:
		lowest = maxf(lowest, (rects[n] as Rect2).end.y)
	_check("your hand stays below the table (hand top %d, table bottom %d)"
		% [int(hand_top), int(lowest)], hand_top >= lowest)

func _check_the_customer_card_shows_who_they_are() -> void:
	var shift = _controller._shift
	if shift.at == null:
		_check("could get to a customer at all", false)
		return
	var who = shift.chairs[_at()]
	var card = _controller._customer_cards[_at()]

	_check("their card names them (%s)" % card._name.text,
		card._name.text == who.display_name)
	_check("their card names their archetype (%s)" % card._archetype.text,
		card._archetype.text.contains(who.archetype.display_name))
	_check("their card shows patience (%s)" % card._patience.text,
		card._patience.text.contains(str(who.patience)))
	# It used to grow by a third when selected, which is what drove it into the
	# product slot. Selecting them must change nothing about its size.
	_check("and selecting them did NOT resize the card (%s)" % card.scale,
		card.scale.is_equal_approx(Vector3.ONE))

## The reported bug from two rounds ago: none of the customer's own data showed
## up. It lives on the detail card now, so that is where this looks.
func _check_the_detail_card_shows_what_they_do() -> void:
	var who = _controller._shift.chairs[_at()]
	var det = _controller._customer_details[_at()]

	_check("the detail card names them (%s)" % det._title.text,
		det._title.text == who.display_name)
	_check("its customer half is showing", det._customer_body.visible)
	_check("and its offer half is not - one card, one subject",
		not det._offer_body.visible)
	_check("it says what they DO (%s)" % det._does.text.substr(0, 40),
		not det._does.text.is_empty())
	_check("and it is live data, not the editor placeholder",
		not det._does.text.begins_with("(their behaviours"))
	if who.archetype.actions.is_empty():
		_check("an archetype with no actions says so plainly",
			det._does.text.contains("just sit"))
	else:
		_check("an archetype WITH actions names one (%s)"
			% who.archetype.actions[0].display_name,
			det._does.text.contains(who.archetype.actions[0].display_name))
	_check("it says what is unsigned (%s)" % det._table.text.substr(0, 40),
		not det._table.text.begins_with("(what they have"))
	_check("and what you have worked out (%s)" % det._known.text.substr(0, 40),
		not det._known.text.begins_with("(what you have"))

	# A standing rule, not an action: close() enforces it, so it never fires and
	# never reaches the log. A Karen who refuses to sign with no reason stated
	# anywhere on screen is the game lying to you.
	# Imposed rather than waited for: whether this seed deals a Karen into this
	# chair is chance, and a check that only sometimes runs has only sometimes
	# been verified.
	var was_demands = who.demands
	who.demands = &"vehicle"
	_controller._render()
	_check("a customer who demands a category says so (%s)"
		% det._does.text.split("\n")[0],
		det._does.text.contains("WILL NOT SIGN")
			and det._does.text.to_lower().contains("vehicle"))
	who.demands = was_demands
	_controller._render()
	_check("and a customer who demands nothing does not (%s)"
		% det._does.text.split("\n")[0],
		was_demands != null or not det._does.text.contains("WILL NOT SIGN"))

	_check_the_detail_card_is_not_overflowing(det)
	_check_read_the_room_shows_you_something(det, who)

## The reported bug: "sometimes I play Read the Room and no priority category is
## revealed." It was never shown at all - reveal_room() sets known_top_category
## on the customer, and known_text() only ever walked known_ranks, which Read the
## Room does not touch. The card's own promise, "reveals their Line and the
## category of their number one", was half true.
##
## Driven through the model's own reveal_room(), which is exactly what the
## RevealRoom effect calls, rather than through whatever happens to be in hand.
func _check_read_the_room_shows_you_something(det, who) -> void:
	var was_cat = who.known_top_category
	var was_line: bool = who.known_line
	who.known_top_category = null
	who.known_line = false
	_controller._render()
	var before: String = det._known.text

	who.reveal_room()
	_controller._render()
	var after: String = det._known.text

	_check("reading the room changes what the card says (was: %s)"
		% before.substr(0, 40), after != before)
	_check("and it names the category of their number one (%s)"
		% after.split("\n")[0],
		after.to_lower().contains(str(who.known_top_category)))

	who.known_top_category = was_cat
	who.known_line = was_line
	_controller._render()

## Bigger type is only an improvement while it still fits. A VBoxContainer whose
## children want more room than it has does not grow and does not complain - it
## just runs the last section off the bottom of the card, where nothing but an
## eye would ever catch it.
## Measured against the FONT, not against get_combined_minimum_size(): an
## autowrap Label reports its minimum from its CURRENT width, and this runs on
## the first frame, before any Control has been laid out - so the container's
## own answer is computed at width zero and comes back more than double.
func _check_the_detail_card_is_not_overflowing(det) -> void:
	var margin := det.get_node(^"FrontViewport/DetailFront/Margin") as MarginContainer
	var pad_x: float = margin.get_theme_constant("margin_left") \
		+ margin.get_theme_constant("margin_right")
	var room: float = det.FRONT_SIZE.y \
		- margin.get_theme_constant("margin_top") \
		- margin.get_theme_constant("margin_bottom")
	var col := det.get_node(^"FrontViewport/DetailFront/Margin/Column") as Control
	var width: float = det.FRONT_SIZE.x - pad_x
	var live := _stack_height(col, width)
	_check("the detail card's contents fit its face (%d of %d px)"
		% [int(live), int(room)], live <= room)

	# The customer in this seat is one archetype out of seven, and the tallest
	# block on the card is what they DO. So try the worst the content can
	# actually produce - through the real formatter, by swapping the archetype
	# under a live customer rather than writing a second copy of the format here.
	var who = _controller._shift.chairs[_at()]
	var was_arch = who.archetype
	var was_demands = who.demands
	var worst := ""
	for arch in (load("res://data/archetype_pool.tres") as ArchetypePool).archetypes:
		who.archetype = arch
		who.demands = &"reliability"        # the longest category name there is
		var text := CustomerCard3D.behaviour_text(who)
		if text.length() > worst.length():
			worst = text
	who.archetype = was_arch
	who.demands = was_demands

	var was_text: String = det._does.text
	det._does.text = worst
	var wanted := _stack_height(col, width)
	det._does.text = was_text
	_check("and would still fit for the wordiest customer in the pool (%d of %d px)"
		% [int(wanted), int(room)], wanted <= room)

func _stack_height(box: Control, width: float) -> float:
	var total := 0.0
	var shown := 0
	for child in box.get_children():
		if child is not Control or not (child as Control).visible:
			continue
		shown += 1
		if child is Label:
			var l := child as Label
			total += l.get_theme_font("font").get_multiline_string_size(
				l.text, HORIZONTAL_ALIGNMENT_LEFT, width,
				l.get_theme_font_size("font_size")).y
		elif child is VBoxContainer:
			total += _stack_height(child as Control, width)
		else:
			total += maxf((child as Control).custom_minimum_size.y, 0.0)
	if shown > 1:
		total += float(box.get_theme_constant("separation") * (shown - 1))
	return total

# --- the appeal meter ------------------------------------------------------

func _put_a_product_on_the_table() -> void:
	if _controller._shift.at == null:
		_check("still with a customer before placing", false)
		return
	var face = null
	for c in _controller._hand_zone.cards:
		if c.instance != null and c.instance.is_product():
			face = c
			break
	if face == null:
		_check("there was a product in hand to place", false)
		return
	_drop(face, _controller._chair_zones[_at()])
	_settle()
	_check("placing a product put it on their table",
		_controller._shift.at != null
			and _controller._shift.chairs[_at()].offer != null)

## The change the player asked for: the fill is your own appeal and it moves
## when you play an appeal card, but the Line stays hidden until you have earned
## it. The colour is the guess in between - it is what replaced the word "COOL".
func _check_the_meter_shows_your_appeal_but_hides_their_line() -> void:
	if _controller._shift.at == null:
		_check("still seated for the meter checks", false)
		return
	var c = _controller._shift.chairs[_at()]
	if c == null or c.offer == null:
		_check("there is an offer to meter", false)
		return
	var det = _controller._offer_details[_at()]
	var bar: AppealBar = det._bar

	_check("the offer detail names the product (%s)" % det._title.text,
		det._title.text == c.offer.product.display_name)
	_check("its offer half is showing", det._offer_body.visible)
	_check("and its customer half is not", not det._customer_body.visible)
	_check("the meter fills with YOUR appeal (%d of %d)" % [bar._appeal, bar._scale],
		bar._appeal == c.offer.appeal)
	_check("on a scale that fits both it and the Line",
		bar._scale >= c.offer.appeal and bar._scale >= c.line)
	_check("the Line marker is hidden until you know it (known=%s)" % c.known_line,
		bar._line_known == c.known_line)
	_check("nothing on this card says COOL or WARM any more",
		not det._status.text.contains("COOL") and not det._status.text.contains("WARM"))
	# Red far, amber close, green once cleared - the whole point of the colour.
	var want: Color = Palette.color(&"patience_ok") if c.offer.appeal >= c.line \
		else (Palette.color(&"patience_warn") \
			if _controller._shift.band_for(c.line - c.offer.appeal) in ["ALMOST", "WARM"] \
			else Palette.color(&"patience_bad"))
	_check("and the colour says how far off you are (%s)" % bar.fill_color(),
		bar.fill_color() == want)

## "You need to show me how much appeal I currently have on that bar, and it
## fills up as I add appeal cards... Red if it's far, yellow if close, green if
## above." Walked directly rather than through a support card, because WHICH
## card is in hand is up to the deal: the thing that can actually break is
## whether the bar re-reads live state every render, and that is what this moves.
func _check_the_meter_climbs_and_changes_colour() -> void:
	if _controller._shift.at == null:
		_check("still seated to walk the meter", false)
		return
	var c = _controller._shift.chairs[_at()]
	if c == null or c.offer == null:
		_check("there is an offer to walk the meter with", false)
		return
	var bar: AppealBar = _controller._offer_details[_at()]._bar
	var was_appeal: int = c.offer.appeal
	var was_known: bool = c.known_line

	var rungs := [
		["far below", maxi(0, c.line - 24), &"patience_bad"],
		["close", maxi(0, c.line - 6), &"patience_warn"],
		["cleared", c.line, &"patience_ok"],
	]
	var last_fill := -1.0
	for rung in rungs:
		c.offer.appeal = int(rung[1])
		_controller._render()
		var fill: float = float(bar._appeal) / float(bar._scale)
		_check("appeal %s: the meter reads %d, not the number from last render"
			% [rung[0], bar._appeal], bar._appeal == int(rung[1]))
		_check("appeal %s: and the fill grew (%.2f > %.2f)" % [rung[0], fill, last_fill],
			fill > last_fill)
		_check("appeal %s: the colour is %s" % [rung[0], rung[2]],
			bar.fill_color() == Palette.color(rung[2]))
		last_fill = fill

	# The one number the fog is protecting. The fill is always honest; the marker
	# is not drawn until the model says you have earned the Line.
	# Asked of the same expression _draw() uses, not of a flag beside it.
	var track := Rect2(0, 0, 400, 60)
	c.known_line = false
	_controller._render()
	_check("with the Line unknown there is nowhere to draw the marker",
		bar.marker_x(track) < 0.0)
	c.known_line = true
	_controller._render()
	_check("and once you know it, the marker has a place on the bar (%.0f)"
		% bar.marker_x(track), bar.marker_x(track) >= 0.0)

	c.offer.appeal = was_appeal
	c.known_line = was_known
	_controller._render()

func _check_the_meter_reveals_the_line_once_you_have_asked() -> void:
	if _controller._shift.at == null:
		_check("still seated after offering", false)
		return
	var c = _controller._shift.chairs[_at()]
	if c == null:
		_check("they are still in the chair after offering", false)
		return
	_check("offering taught you their Line", c.known_line)
	if c.offer == null:
		# They signed, so the offer left the table - which is its own correct
		# outcome and leaves nothing to meter.
		_check("a sale cleared the table, so the meter has nothing to show",
			_controller._offer_details[_at()]._title.text == "nothing on the table")
		return
	var bar: AppealBar = _controller._offer_details[_at()]._bar
	_check("so the meter now draws the marker", bar._line_known)
	_check("at the Line the model actually holds (%d)" % bar._line, bar._line == c.line)

# --- the mode button -------------------------------------------------------

## The button is the only way back to the floor once the other seats are hidden,
## so both of its jobs are pinned.
func _check_the_mode_button_flips() -> void:
	var btn = _controller._mode_btn
	_check("with someone, it offers the way out (%s)" % btn.text,
		btn.visible and btn.text.to_lower().contains("floor"))

	var who = _controller._shift.chairs[_at()]
	_controller._on_mode_pressed()          # step back to the floor
	_settle()
	_check("pressing it puts you back on the floor", _controller._shift.at == null)
	_check("and the seats you could not see are back",
		_controller._seats[0].visible and _controller._seats[1].visible
			and _controller._seats[2].visible)
	_check("on the floor it offers the way back (%s)" % btn.text,
		btn.visible and btn.text.contains(who.display_name))
	# m2/README.md: returning to whoever you were last with is free. The label
	# promises that, so it had better be true.
	_check("and says so, because the model makes it free", btn.text.contains("free"))
	var before: int = _controller._shift.tick
	_controller._on_mode_pressed()          # and back to them
	_settle()
	_check("going back costs no tick (%d -> %d)" % [before, _controller._shift.tick],
		_controller._shift.tick == before)
	_check("and you are with them again", _controller._shift.at != null)

# --- the HUD ---------------------------------------------------------------

func _check_the_action_buttons_stay_on_screen() -> void:
	## The reported bug: OFFER / DROP / CLOSE vanished the moment you put
	## something on the table. It was a layout overflow, not a disabled state.
	for name in ["OfferButton", "DropButton", "CloseButton"]:
		var b := _controller.get_node_or_null(NodePath("%" + name)) as Control
		if b == null:
			_check("%s exists" % name, false)
			continue
		_on_screen(name, Rect2(b.global_position, b.size))

## The panels kept landing on each other, so this is checked rather than eyeballed.
func _check_hud_does_not_overlap_itself() -> void:
	var log_panel := _controller.get_node("%SidePanel") as Control
	var log_rect := Rect2(log_panel.position, log_panel.size)
	var bar := Rect2(_controller._action_bar.global_position, _controller._action_bar.size)
	var mode := Rect2(_controller._mode_btn.global_position, _controller._mode_btn.size)

	_check("the action column clears the log", not bar.intersects(log_rect))
	_check("the return button clears the action column", not mode.intersects(bar))
	_check("and clears the log", not mode.intersects(log_rect))

	# Buttons are the only STOP controls over a 3D table, so any button sitting
	# on a card is a click the card will never see.
	var at := _at()
	for pair in [["customer card", _rect_of(_controller._customer_cards[at], CARD)],
			["customer detail", _rect_of(_controller._customer_details[at],
				DetailCard3D.CARD_SIZE)],
			["product slot", _rect_of(_controller._chair_zones[at], CARD)],
			["offer detail", _rect_of(_controller._offer_details[at],
				DetailCard3D.CARD_SIZE)]]:
		var card: Rect2 = pair[1]
		_check("the action column does not sit on the %s" % pair[0],
			not bar.intersects(card))
		_check("nor does the return button sit on the %s" % pair[0], not mode.intersects(card))
		_check("nor does the log sit on the %s" % pair[0], not log_rect.intersects(card))

	for pair in [["action column", bar], ["return button", mode]]:
		_on_screen(pair[0], pair[1])

# --- the table matches the model -------------------------------------------

## Every card the model knows about must have exactly one node, parented to the
## collection CardHomes says it belongs in - and there must be no others.
func _check_table(when: String) -> void:
	var shift = _controller._shift
	var desired := CardHomes.desired(shift)

	_check("%s: one node per card (%d nodes, %d cards)"
		% [when, _controller._nodes.size(), desired.size()],
		_controller._nodes.size() == desired.size())

	var misplaced: Array[String] = []
	for uid in desired:
		var node = _controller._nodes.get(uid)
		if node == null:
			misplaced.append("uid %d has no node" % uid)
			continue
		var want = _controller._zone_for(desired[uid]["zone"])
		if node.get_parent() != want:
			misplaced.append("uid %d is in %s, wanted %s"
				% [uid, node.get_parent().name, want.name])
	_check("%s: every card sits where the model says (%s)"
		% [when, ", ".join(misplaced) if not misplaced.is_empty() else "ok"],
		misplaced.is_empty())

	var wrong_collision: Array[String] = []
	for uid in desired:
		var node = _controller._nodes.get(uid)
		if node == null:
			continue
		var shape := node.get_node(^"StaticBody3D/CollisionShape3D") as CollisionShape3D
		var draggable: bool = desired[uid]["zone"] == CardHomes.ZONE_HAND
		if shape.disabled == draggable:
			wrong_collision.append("uid %d in %s" % [uid, desired[uid]["zone"]])
	_check("%s: only hand cards are draggable (%s)"
		% [when, ", ".join(wrong_collision) if not wrong_collision.is_empty() else "ok"],
		wrong_collision.is_empty())

	# Both piles are turned over: what is spent and what has not been dealt are
	# neither of them decisions you are still making, and a face-up discard is a
	# second hand's worth of faces beside the actual hand.
	var wrong_face: Array[String] = []
	for uid in desired:
		var node = _controller._nodes.get(uid)
		if node == null:
			continue
		var zone: StringName = desired[uid]["zone"]
		var hidden: bool = zone == CardHomes.ZONE_DRAW or zone == CardHomes.ZONE_DISCARD
		if node.face_down != hidden:
			wrong_face.append("uid %d in %s" % [uid, zone])
	_check("%s: the draw and discard piles are face down (%s)"
		% [when, ", ".join(wrong_face) if not wrong_face.is_empty() else "ok"],
		wrong_face.is_empty())

## Simulate what DragController does on a drop - move the node, then emit - and
## confirm the model followed. Only the mouse is faked; the handler is real.
func _drop(face, to_zone) -> void:
	var from = face.get_parent()
	var at: int = from.cards.find(face)
	from.remove_card(at)
	to_zone.append_card(face)
	_controller._on_drag_card_moved(face, from, to_zone, at, to_zone.cards.size() - 1)
	_controller._on_drag_stopped(face)

func _check_drop_plays_a_card() -> void:
	var shift = _controller._shift
	var hand = _controller._hand_zone
	# Must be a PRODUCT. Most support cards carry needs_offer, so dropping one on
	# a customer with nothing on the table is refused - correctly - and would
	# test the bounce path rather than the play path.
	var face = null
	for c in hand.cards:
		if c.instance != null and c.instance.is_product():
			face = c
			break
	if face == null:
		_check("there was a product in hand to drag onto someone", false)
		return
	var uid: int = face.uid

	_drop(face, _controller._chair_zones[1])
	_settle()

	_check("dropping on a seat reached the model (uid gone from hand: %s)"
		% [CardIndex.of(shift, uid) == -1], CardIndex.of(shift, uid) == -1)
	# at can legitimately be null afterwards: place() burns a tick, and a tick
	# that empties the chair you are at vacates you.
	_check("and it took you to that seat (at=%s, chair1=%s)"
		% [shift.at, "empty" if shift.chairs[1] == null else "seated"],
		shift.at == 1 or shift.chairs[1] == null)
	_check_table("after dropping a card on seat B")

func _check_refused_drop_comes_home() -> void:
	## Dropping onto the draw pile is meaningless, so the model is never called
	## and the card must end up back in hand - carried there by reconciliation,
	## not by an explicit revert.
	var shift = _controller._shift
	var hand = _controller._hand_zone
	if hand.cards.is_empty():
		_check("there was a card in hand to bounce", false)
		return
	var face = hand.cards[0]
	var uid: int = face.uid
	var before: int = shift.hand.size()

	_drop(face, _controller._draw_zone)
	_settle()

	_check("a meaningless drop changes nothing in the model",
		shift.hand.size() == before)
	_check("the card is still in hand as far as the model is concerned",
		CardIndex.of(shift, uid) != -1)
	_check("and its node came home to the hand zone", face.get_parent() == hand)
	_check("with an explanation in the log rather than silence",
		_controller._event_log.get_parsed_text().length() > 0)
	_check_table("after a refused drop")

## The reported softlock: "if the last customer leaves when other chairs are
## empty you are stuck forever - you cannot play cards so you cannot move the
## ticks to get new people in chairs."
##
## The model half is covered by test_waiting.gd. What this pins is the VIEW half,
## which is where the trap actually was: dig can move the clock without a
## customer, but dig goes through your hand, and your hand is stowed below the
## bottom of the screen the whole time you are out on the floor. So there was
## genuinely nothing on screen to press.
##
## Runs last, because it empties the floor to get there.
func _check_an_empty_floor_does_not_end_the_shift() -> void:
	var shift = _controller._shift
	if shift.is_over():
		_check("the shift was still running, so an empty floor means something", false)
		return
	for c in shift.seated():
		c.patience = 0
	shift._settle_patience()
	_check("every chair is empty with the clock still going (tick %d of %d)"
		% [shift.tick, shift.tick_budget],
		shift.seated().is_empty() and not shift.is_over())

	var before: int = shift.tick
	var logged: int = _controller._event_log.get_parsed_text().length()
	# There is no input left to make on an empty floor, so this is the view
	# acting by itself - through the same funnel every command goes through.
	_controller._apply(Result.new(true, "", "test"))
	_settle()

	_check("time moved on without being asked (%d -> %d)" % [before, shift.tick],
		shift.tick > before)
	_check("and there is somebody to sell to again, or the shift is over",
		not shift.seated().is_empty() or shift.is_over())
	_check("with the jump written down rather than silently skipped",
		_controller._event_log.get_parsed_text().length() > logged)
	_check("and the log says how long it took",
		_controller._event_log.get_parsed_text().contains("later"))

## No unit test can reach this - it needs an instantiated Control tree to read
## the button and title text a real player would see. A fatal shift and a
## completed one must not look identical on screen, which is the whole point
## of a standing meter: this is the only place that ever renders "fired" at all.
func _check_a_fatal_shift_shows_its_own_report() -> void:
	var fatal_shift := Shift.new(load("res://data/shift_config.tres"),
		load("res://data/interests/interest_pool.tres"),
		load("res://data/card_pool.tres"),
		load("res://data/archetype_pool.tres"), randi())
	# A deliberately low standing_before, chosen so this fresh shift's own total
	# wipeout (margin_banked stays 0, the default damage scale costs half a full
	# meter) crosses zero. tick == tick_budget is the cheap, direct way to reach
	# is_over() without playing the shift out - Shift.is_over() is exactly that
	# comparison and nothing else.
	const LOW_STANDING := 10
	_controller.setup(fatal_shift, LOW_STANDING)
	fatal_shift.tick = fatal_shift.tick_budget
	_controller._apply(Result.new(true, "", "test"))
	_check("a fatal shift's report overlay comes up", _controller._report_overlay.visible)
	_check("and its button says so (%s)" % _controller._report_overlay._restart.text,
		_controller._report_overlay._restart.text.to_upper().contains("FIRED"))
	_check("and its title says so (%s)" % _controller._report_overlay._title.text,
		_controller._report_overlay._title.text.to_upper().contains("FIRED"))

func _check(label: String, ok: bool) -> void:
	_checks += 1
	if not ok:
		_failures.append(label)
