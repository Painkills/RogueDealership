extends SceneTree
## Drives a real shift.tscn and checks the table matches the model after every
## command, plus the two framings and the things that ride with the camera.
##
## NOT part of run_tests.gd and cannot be: the suite runs inside _init(), and
## adding a node to the tree there does not fire _ready() synchronously (found
## the hard way during G1). Everything here needs a live _ready(), so it waits
## for the first _process() frame.
##
##   godot --headless --path game --script res://tools/drive_shift.gd
##
## What it CANNOT tell you: whether any of it is legible, whether cards land
## where you aimed, or whether the movement feels right. Real mouse picking needs
## a stepped physics space and a real camera ray, and faking it would only
## produce a test that lies.

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

func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true

	_check("the viewport is picking, or no card can ever be clicked",
		get_root().physics_object_picking)
	_check("the drag controller knows about all six zones",
		_controller._drag._card_collections.size() == 6)
	_check("and found a camera to ray through", _controller._drag._camera != null)
	_check("a shift is running", _controller._shift != null)
	_check("the hand fans", _controller._hand_zone.card_layout_strategy is FanCardLayout)

	_check_the_player_rides_the_camera()
	_check_floor_view_is_bare()
	_check_table("on arrival")

	_press(KEY_A)
	_settle()
	_check_seat_view_brings_your_things_up()
	_check_the_customer_actually_shows_their_data()
	_check_the_action_buttons_stay_on_screen()
	_check_hud_does_not_overlap_itself()
	_check_table("after approaching chair A")

	_check_the_mode_button_flips()

	_press(KEY_1);            _settle(); _check_table("after playing hand card 1")
	_press(KEY_O);            _settle(); _check_table("after offering")
	_press(KEY_2, true);      _settle(); _check_table("after digging hand card 2")
	_press(KEY_C, true);      _settle(); _check_table("after closing")
	_press(KEY_B);            _settle(); _check_table("after approaching chair B")

	_check_drop_plays_a_card()
	_check_refused_drop_comes_home()

	print("")
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
	# Each customer card owns its own expand/contract tween, so stepping the
	# controller's framing tween alone leaves the cards mid-grow.
	for card in _controller._customer_cards:
		var ct = card._scale_tween
		if ct != null and ct.is_valid() and ct.is_running():
			ct.custom_step(2.0)

func _frame_half_height() -> float:
	return absf(_controller.HAND_UP.z) * tan(deg_to_rad(_controller._camera.fov * 0.5))

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
		_check("on the floor your %s is stowed below frame (y %.1f < %.1f)"
			% [pair[0], z.position.y, bottom], z.position.y < bottom)
	_check("no action bar on the floor - there is nobody to act on",
		not _controller._action_bar.visible)
	_check("no offer panel on the floor", not _controller._offer_panel.visible)

func _check_seat_view_brings_your_things_up() -> void:
	var bottom := -_frame_half_height()
	for pair in [["hand", _controller._hand_zone], ["discard", _controller._discard_zone]]:
		var z := pair[1] as Node3D
		_check("sitting down raises your %s into view (y %.1f > %.1f)"
			% [pair[0], z.position.y, bottom], z.position.y > bottom)
	_check("and the action bar appears", _controller._action_bar.visible)
	_check("and the offer panel appears", _controller._offer_panel.visible)

## The button is the only way back to the floor once the other seats are off
## screen, so both of its jobs are pinned.
func _check_the_mode_button_flips() -> void:
	var btn = _controller._mode_btn
	_check("with someone, it offers the way out (%s)" % btn.text,
		btn.visible and btn.text.to_lower().contains("floor"))

	var who = _controller._shift.chairs[int(_controller._shift.at)]
	_controller._on_mode_pressed()          # step back to the floor
	_settle()
	_check("pressing it puts you back on the floor", _controller._shift.at == null)
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

func _check_the_customer_actually_shows_their_data() -> void:
	var shift = _controller._shift
	if shift.at == null:
		_check("could get to a customer at all", false)
		return
	var who = shift.chairs[int(shift.at)]
	var card = _controller._customer_cards[int(shift.at)]

	_check("their card names them (%s)" % card._name.text,
		card._name.text == who.display_name)
	_check("their card names their archetype (%s)" % card._archetype.text,
		card._archetype.text.contains(who.archetype.display_name))
	_check("their card shows patience (%s)" % card._patience.text,
		card._patience.text.contains(str(who.patience)))
	_check("selecting them expands the card", card._detail.visible)
	_check("and the card grew (%s)" % card.scale, card.scale.x > 1.0)

	# The reported bug: none of the customer's own data showed up, because their
	# behaviours only ever existed on a hover panel that is hidden while
	# negotiating. It is on the expanded card now.
	_check("the card says what they DO (%s)" % card._does.text.substr(0, 40),
		not card._does.text.is_empty())
	_check("and it is live data, not the editor placeholder",
		not card._does.text.begins_with("(their behaviours"))
	if who.archetype.actions.is_empty():
		_check("an archetype with no actions says so plainly",
			card._does.text.contains("just sit"))
	else:
		_check("an archetype WITH actions names one (%s)"
			% who.archetype.actions[0].display_name,
			card._does.text.contains(who.archetype.actions[0].display_name))

func _check_the_action_buttons_stay_on_screen() -> void:
	## The reported bug: OFFER / DROP / CLOSE vanished the moment you put
	## something on the table. It was a layout overflow, not a disabled state.
	var screen := _screen()
	for name in ["OfferButton", "DropButton", "CloseButton"]:
		var b := _controller.get_node_or_null(NodePath("%" + name)) as Control
		if b == null:
			_check("%s exists" % name, false)
			continue
		var r := Rect2(b.global_position, b.size)
		_check("%s is on screen (%s)" % [name, r],
			r.position.x >= 0.0 and r.position.y >= 0.0
				and r.end.x <= screen.x and r.end.y <= screen.y)

## The panels kept landing on each other, so this is checked rather than eyeballed.
func _check_hud_does_not_overlap_itself() -> void:
	var log_panel := _controller.get_node("%SidePanel") as Control
	var log_rect := Rect2(log_panel.position, log_panel.size)
	var bar := Rect2(_controller._action_bar.global_position, _controller._action_bar.size)
	var offer := Rect2(_controller._offer_panel.global_position, _controller._offer_panel.size)
	var mode := Rect2(_controller._mode_btn.global_position, _controller._mode_btn.size)

	_check("the action bar clears the log", not bar.intersects(log_rect))
	_check("the offer panel clears the log", not offer.intersects(log_rect))
	_check("the offer panel clears the action bar", not offer.intersects(bar))
	_check("the return button clears the offer panel", not mode.intersects(offer))
	for pair in [["action bar", bar], ["offer panel", offer], ["return button", mode]]:
		var r: Rect2 = pair[1]
		_check("the %s is on screen (%s)" % [pair[0], r],
			r.position.x >= 0.0 and r.position.y >= 0.0
				and r.end.x <= _screen().x and r.end.y <= _screen().y)

func _screen() -> Vector2:
	return Vector2(
		ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height"))

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

func _check(label: String, ok: bool) -> void:
	_checks += 1
	if not ok:
		_failures.append(label)
