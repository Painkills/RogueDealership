extends SceneTree
## Drives a real shift.tscn through its keyboard commands and checks that the
## table matches the model after every one.
##
## This is NOT part of run_tests.gd and cannot be: the suite runs inside _init(),
## and adding a node to the tree there does not fire _ready() synchronously
## (found the hard way during G1). Everything here needs a live _ready(), so it
## waits for the first _process() frame instead.
##
##   godot --headless --path game --script res://tools/drive_shift.gd
##
## What it CANNOT tell you: whether any of it is legible, whether the cards land
## where you aimed, or whether dragging feels right. Real mouse picking needs a
## stepped physics space and a real camera ray, and faking it here would only
## produce a test that lies.

var _controller: Node3D
var _done := false
var _failures: Array[String] = []
var _checks := 0

func _init() -> void:
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
	# DragController grabs the viewport's CURRENT camera in _ready and rays
	# through it for every drag. If Camera3D.current were ever unset, drags would
	# null-dereference rather than fail visibly.
	_check("and found a camera to ray through", _controller._drag._camera != null)
	_check("a shift is running", _controller._shift != null)
	_check("three floor panels", _controller._floor_cards.size() == 3)
	_check("the hand was narrowed from the library default",
		is_equal_approx(
			(_controller._hand_zone.card_layout_strategy as LineCardLayout).max_width,
			_controller.HAND_MAX_WIDTH))

	_check_table("on arrival")
	_check_panels_clear_of_each_other()

	_press(KEY_A);            _check_table("after approaching chair A")
	_press(KEY_1);            _check_table("after playing hand card 1")
	_press(KEY_O);            _check_table("after offering")
	_press(KEY_2, true);      _check_table("after digging hand card 2")
	_press(KEY_C, true);      _check_table("after closing")
	_press(KEY_F);            _check_table("after stepping back to the floor")
	_press(KEY_B);            _check_table("after approaching chair B")

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

	# A card in hand is draggable; one on the table or in a pile is not, or it
	# would intercept the pointer aimed at the zone underneath it.
	var wrong_collision: Array[String] = []
	for uid in desired:
		var node = _controller._nodes.get(uid)
		if node == null:
			continue
		var shape := node.get_node(^"StaticBody3D/CollisionShape3D") as CollisionShape3D
		var should_be_draggable: bool = desired[uid]["zone"] == CardHomes.ZONE_HAND
		if shape.disabled == should_be_draggable:
			wrong_collision.append("uid %d in %s" % [uid, desired[uid]["zone"]])
	_check("%s: only hand cards are draggable (%s)"
		% [when, ", ".join(wrong_collision) if not wrong_collision.is_empty() else "ok"],
		wrong_collision.is_empty())

## The floor panels are positioned by unprojecting the chairs, so a bad camera
## or a bad offset shows up as panels landing on top of each other or off screen.
func _check_panels_clear_of_each_other() -> void:
	var rects: Array[Rect2] = []
	for card in _controller._floor_cards:
		rects.append(Rect2(card.position, card.size))
	for i in range(rects.size()):
		var r: Rect2 = rects[i]
		_check("floor panel %d is on screen (%s)" % [i, r],
			r.position.x >= 0 and r.position.y >= 0
				and r.end.x <= 960 and r.end.y <= 540)
		for j in range(i + 1, rects.size()):
			_check("floor panels %d and %d do not overlap" % [i, j],
				not r.intersects(rects[j]))

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
	if hand.cards.is_empty():
		_check("there was a card in hand to drag", false)
		return
	var face = hand.cards[0]
	var uid: int = face.uid
	var before: int = shift.hand.size()

	_drop(face, _controller._chair_zones[1])

	_check("dropping on a chair actually played the card (hand %d -> %d)"
		% [before, shift.hand.size()], shift.hand.size() < before
			or CardIndex.of(shift, uid) == -1)
	_check("and it moved you to that chair", shift.at == 1)
	_check_table("after dropping a card on chair B")

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

	_check("a meaningless drop changes nothing in the model",
		shift.hand.size() == before)
	_check("the card is still in hand as far as the model is concerned",
		CardIndex.of(shift, uid) != -1)
	_check("and its node came home to the hand zone",
		face.get_parent() == hand)
	_check("with an explanation in the log rather than silence",
		_controller._event_log.get_parsed_text().length() > 0)
	_check_table("after a refused drop")

func _check(label: String, ok: bool) -> void:
	_checks += 1
	if not ok:
		_failures.append(label)
