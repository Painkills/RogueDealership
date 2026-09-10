extends Node3D
## The whole game: a 3D card table with a 2D HUD over it.
##
## Three rules hold this file together.
##
## ONE: THE CAMERA IS THE PLAYER. Your hand, draw and discard are children of
## Camera3D, stowed below frame. They follow you for free; arriving at a seat
## only tweens them up in camera-local space. That is why the seat framing has to
## contain the customer and their table and nothing else.
##
## TWO: the model is authoritative and this never guesses. Every command goes
## through _apply(), and where a card node ends up is recomputed from model state
## by CardHomes afterwards - never decided by whoever moved it. That is why a
## customer walking out at zero patience takes their unsigned offer to the
## discard correctly, though nothing dragged it there.
##
## THREE: cards are matched by uid, never rebuilt. Freeing and recreating the
## hand each render would free the node a drag is holding and kill every tween.

const CardFaceScene := preload("res://scenes/cards/card_face_3d.tscn")

## Camera-local resting places. Must match build_shift_scene.gd.
const PILE_DEPTH := -8.6
const HAND_UP := Vector3(0.0, -4.77, PILE_DEPTH)
const HAND_STOWED := Vector3(0.0, -12.6, PILE_DEPTH)
const DISCARD_UP := Vector3(7.2, -3.68, PILE_DEPTH)
const DISCARD_STOWED := Vector3(7.2, -12.6, PILE_DEPTH)
const DRAW_UP := Vector3(-7.27, -3.68, PILE_DEPTH)
const DRAW_STOWED := Vector3(-7.27, -12.6, PILE_DEPTH)

## How high a hovered hand card lifts. The hand deliberately runs off the bottom
## of the screen - big enough to read beats small enough to fit - so this has to
## clear the part that is off screen, rather than being the addon's small nudge.
## The Z is what makes a fanned hand readable: hand cards overlap, so a card
## raised in place is still half-covered by the one to its right. Coming FORWARD
## puts it in front of every sibling. It moves the mesh, not the collider, so
## the card cannot slide out from under its own cursor.
const HAND_HOVER_LIFT := Vector3(0.0, 2.5, 0.8)

const FRAMING_TWEEN := 0.5
## Your things arrive a beat after the camera settles, so the move reads as
## travelling and then setting your things down.
const PILE_TWEEN := 0.4
const PILE_DELAY := 0.18

## The run layer listens for this. The controller plays ONE shift; deciding
## what comes next is not its job.
signal shift_finished(report: Dictionary)

@onready var _camera: Camera3D = $Camera3D
@onready var _camera_floor: Marker3D = %CameraFloor
@onready var _drag: DragController = $DragController
@onready var _hand_zone: CardCollection3D = %Hand
@onready var _draw_zone: CardCollection3D = %Draw
@onready var _discard_zone: CardCollection3D = %Discard

@onready var _hud: Control = %HudRoot
@onready var _tick_label: Label = %TickLabel
@onready var _banked_label: Label = %BankedLabel
@onready var _standing_label: Label = %StandingLabel
@onready var _at_risk_label: Label = %AtRiskLabel
@onready var _event_log: RichTextLabel = %EventLog
@onready var _mode_btn: Button = %ModeButton
@onready var _action_bar: Control = %ActionBar
@onready var _offer_btn: Button = %OfferButton
@onready var _drop_btn: Button = %DropButton
@onready var _close_btn: Button = %CloseButton
@onready var _report_overlay = %ReportOverlay

var _shift: Shift
var _standing_before: int = 0        ## the run's standing when THIS shift started
var _seats: Array = []               ## one Node3D per seat, hidden when elsewhere
var _chair_zones: Array = []
var _seat_cams: Array = []
var _customer_cards: Array = []
var _customer_flips: Array = []      ## the pair-turning node, one per seat
var _hover_pads: Array = []          ## the immovable thing the mouse actually finds
var _customer_details: Array = []
var _offer_details: Array = []
var _nodes: Dictionary = {}          ## uid -> CardFace3D
var _dragging: CardFace3D = null
var _framing_tween: Tween
var _framed_at = null
var _hovered: int = -1
var _events_seen: int = 0
var _actions_seen: int = 0

func _ready() -> void:
	# Card3D takes mouse input through StaticBody3D.input_event, which does
	# nothing at all unless the viewport is picking. It defaults to false.
	get_viewport().physics_object_picking = true

	_seats = [%Seat0, %Seat1, %Seat2]
	_chair_zones = [%Chair0, %Chair1, %Chair2]
	_seat_cams = [%SeatCam0, %SeatCam1, %SeatCam2]
	_customer_cards = [%Customer0, %Customer1, %Customer2]
	_customer_flips = [%CustomerFlip0, %CustomerFlip1, %CustomerFlip2]
	_hover_pads = [%HoverPad0, %HoverPad1, %HoverPad2]
	_customer_details = [%CustomerDetail0, %CustomerDetail1, %CustomerDetail2]
	_offer_details = [%OfferDetail0, %OfferDetail1, %OfferDetail2]

	for zone in _chair_zones:
		_drag.add_card_collection(zone)
	_drag.add_card_collection(_hand_zone)
	_drag.add_card_collection(_draw_zone)
	_drag.add_card_collection(_discard_zone)

	# Only DragController's card_moved. CardCollection3D has a same-named signal
	# of lower arity for reorders which move_card() re-emits - and reconciling
	# calls move_card(). Connecting both makes this recursive.
	_drag.card_moved.connect(_on_drag_card_moved)
	_drag.drag_started.connect(_on_drag_started)
	_drag.drag_stopped.connect(_on_drag_stopped)

	# These belong to the PLAYER, so they are wired once and outlive any
	# particular customer.
	_offer_btn.pressed.connect(_on_offer)
	_drop_btn.pressed.connect(_on_drop)
	_close_btn.pressed.connect(_on_close)
	_mode_btn.pressed.connect(_on_mode_pressed)

	# Hover and click belong to the PAD, not to the card. The card turns over,
	# and a flat collider edge-on has no area at all - so hovering the card made
	# it flicker between flipped and not, and where you brought the cursor in
	# from decided whether it settled. The pad never moves.
	for i in range(_customer_cards.size()):
		_customer_cards[i].chair = i
		var pad: StaticBody3D = _hover_pads[i]
		pad.mouse_entered.connect(_on_customer_hover.bind(i))
		pad.mouse_exited.connect(_on_customer_unhover.bind(i))
		pad.input_event.connect(_on_pad_input.bind(i))

	_register_keyboard_actions()
	_report_overlay.continue_pressed.connect(
		func(): shift_finished.emit(_shift.report()))

# --- input -----------------------------------------------------------------

func _register_keyboard_actions() -> void:
	_bind_key(&"card_1", KEY_1)
	_bind_key(&"card_2", KEY_2)
	_bind_key(&"card_3", KEY_3)
	_bind_key(&"card_4", KEY_4)
	_bind_key(&"card_5", KEY_5)
	_bind_key(&"dig_1", KEY_1, true)        # Shift+1..5: dig, distinct from playing
	_bind_key(&"dig_2", KEY_2, true)
	_bind_key(&"dig_3", KEY_3, true)
	_bind_key(&"dig_4", KEY_4, true)
	_bind_key(&"dig_5", KEY_5, true)
	_bind_key(&"chair_a", KEY_A)
	_bind_key(&"chair_b", KEY_B)
	_bind_key(&"chair_c", KEY_C)
	_bind_key(&"offer_key", KEY_O)
	_bind_key(&"drop_key", KEY_D)
	_bind_key(&"close_key", KEY_C, true)    # Shift+C, distinct from chair_c's bare C
	_bind_key(&"floor_key", KEY_F)          # step back to the floor (Shift.leave())

func _bind_key(action: StringName, keycode: Key, shift: bool = false) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	if not InputMap.action_get_events(action).is_empty():
		return
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.shift_pressed = shift
	InputMap.action_add_event(action, ev)

func _unhandled_input(event: InputEvent) -> void:
	# Never handle mouse here: _unhandled_input runs BEFORE physics picking, so
	# consuming a click here takes it from every card on the table.
	if _shift == null or _shift.is_over():
		return
	if event.is_action_pressed("dig_5"): _try_dig(4)
	elif event.is_action_pressed("dig_1"): _try_dig(0)
	elif event.is_action_pressed("dig_2"): _try_dig(1)
	elif event.is_action_pressed("dig_3"): _try_dig(2)
	elif event.is_action_pressed("dig_4"): _try_dig(3)
	elif event.is_action_pressed("card_1"): _try_card(0)
	elif event.is_action_pressed("card_2"): _try_card(1)
	elif event.is_action_pressed("card_3"): _try_card(2)
	elif event.is_action_pressed("card_4"): _try_card(3)
	elif event.is_action_pressed("card_5"): _try_card(4)
	elif event.is_action_pressed("chair_a"): _apply(_shift.approach(0))
	elif event.is_action_pressed("chair_b"): _apply(_shift.approach(1))
	elif event.is_action_pressed("close_key"): _on_close()
	elif event.is_action_pressed("chair_c"): _apply(_shift.approach(2))
	elif event.is_action_pressed("offer_key"): _on_offer()
	elif event.is_action_pressed("drop_key"): _on_drop()
	elif event.is_action_pressed("floor_key"): _apply(_shift.leave())

func _try_card(index: int) -> void:
	if index < _shift.hand.size():
		_apply(_shift.play_card(index))

func _try_dig(index: int) -> void:
	if index < _shift.hand.size():
		_apply(_shift.dig(index))

# --- lifecycle -------------------------------------------------------------

func setup(shift: Shift, standing_before: int) -> void:
	## Play THIS shift. The run builds it - this file used to construct its own,
	## which made it the run orchestrator as well as the table, the framing, the
	## HUD and reconciliation.
	##
	## standing_before travels in separately from the Shift because it belongs to
	## the RUN, not the shift - Shift has never held a RunState reference, and this
	## is the one number the report needs from outside the shift it is reporting on.
	_shift = shift
	_standing_before = standing_before
	_standing_label.text = "standing %d/%d" % [_standing_before, shift.cfg.standing_start]
	_events_seen = 0
	_actions_seen = 0
	_event_log.clear()
	_report_overlay.visible = false
	# The button that ends this shift must not promise "Continue" on the shift
	# that ends the run - pressing it silently restarts a fresh run underneath,
	# indistinguishable to the player from the deck-persistence bug this whole
	# milestone exists to prevent.
	_report_overlay.set_button_text("FINISH THE RUN"
		if _shift.shift_number >= _shift.cfg.shifts_in_run else "Continue")
	_hovered = -1
	_framed_at = -999                     # force the framing to re-apply

	# The ONLY place card nodes are freed. _reconcile() never frees: a freed node
	# still held by DragController crashes the next apply_card_layout().
	_dragging = null
	for zone in _all_zones():
		for card in zone.remove_all():
			card.queue_free()
	_nodes.clear()

	# A shift is dealt with people in it, but this is the other door into the
	# view besides _apply(), and an empty floor is a dead end from either.
	_let_time_pass_on_an_empty_floor()
	_render()

## Hiding a Node3D does NOT hide a CanvasLayer child - the HUD is not a
## CanvasItem and does not inherit the 3D node's visibility. Both have to be
## told, or stepping into the shop leaves the shift's HUD floating over it.
func set_active(on: bool) -> void:
	visible = on
	($HUD as CanvasLayer).visible = on
	set_process_unhandled_input(on)

func _all_zones() -> Array:
	var out := _chair_zones.duplicate()
	out.append_array([_hand_zone, _draw_zone, _discard_zone])
	return out

# --- commands --------------------------------------------------------------

func _on_chair_pressed(chair_index: int) -> void:
	_apply(_shift.approach(chair_index))

func _on_offer() -> void:
	_apply(_shift.offer())

func _on_close() -> void:
	_apply(_shift.close())

func _on_drop() -> void:
	_apply(_shift.drop_offer())

## One button, two jobs. With someone: step back to the floor. On the floor with
## someone to go back to: return to them. The model makes returning to your LAST
## customer free, so the label can promise that honestly.
func _on_mode_pressed() -> void:
	if _shift.at != null:
		_apply(_shift.leave())
		return
	var back := _last_customer_chair()
	if back != -1:
		_apply(_shift.approach(back))

func _last_customer_chair() -> int:
	if _shift.last_customer == null:
		return -1
	for i in range(_shift.chairs.size()):
		if _shift.chairs[i] != null and _shift.chairs[i] == _shift.last_customer:
			return i
	return -1

## Every model command funnels through here. A refusal costs nothing but must
## still say why - "the rules never say no" only holds if the player hears it.
func _apply(res: Result) -> void:
	if not res.ok:
		_event_log.append_text("[color=red]%s[/color]\n" % res.msg)
	_let_time_pass_on_an_empty_floor()
	_render()
	if _shift.is_over():
		_show_report()

## An empty floor is not a decision, it is a wait, so it is not something to make
## the player press a button for. It is also the one state the view cannot get
## itself out of: your hand is stowed off screen while you are on the floor, and
## everything else that moves the clock needs a customer to move it on.
##
## Loops because one wait seats one person, and a walk-up timer that was already
## running down can leave the floor empty again immediately. The guard is not
## defensive dressing: this runs inside a UI callback, and a wait that ever
## returned ok without advancing would hang the game rather than just misbehave.
func _let_time_pass_on_an_empty_floor() -> void:
	var guard := 0
	while not _shift.is_over() and _shift.seated().is_empty():
		guard += 1
		if guard > _shift.tick_budget:
			push_error("wait() stopped advancing the clock")
			break
		if not _shift.wait().ok:
			break

# --- hover -----------------------------------------------------------------

## The seat pad's click. Ignored when you are already standing there, because the
## model would only answer "you are already standing with X" and clicking the
## person you are talking to should not put a refusal in the log.
func _on_pad_input(_cam: Node, event: InputEvent, _pos: Vector3, _normal: Vector3,
		_shape: int, chair: int) -> void:
	if not (event is InputEventMouseButton):
		return
	var click := event as InputEventMouseButton
	if click.button_index != MOUSE_BUTTON_LEFT or not click.pressed:
		return
	if _shift == null or _shift.at == chair:
		return
	_on_chair_pressed(chair)

func _on_customer_hover(chair: int) -> void:
	_hovered = chair
	_render_hover_flip()

func _on_customer_unhover(chair: int) -> void:
	if _hovered == chair:
		_hovered = -1
	_render_hover_flip()

## On the floor a customer card carries only identity, so what they DO lives on
## its BACK: hovering turns the pair over. This replaced a HUD tooltip panel,
## which had to be positioned somewhere it did not collide with anything, and
## which - being a Control over a 3D table - is one wrong mouse_filter away from
## swallowing the very hover that summoned it.
##
## Suppressed once you are seated, because there the detail card is already out
## beside them and turning it over would take away what you came to read.
func _render_hover_flip() -> void:
	var floor_view: bool = _shift != null and _shift.at == null \
		and not _report_overlay.visible
	for i in range(_customer_flips.size()):
		_customer_flips[i].show_back(
			floor_view and i == _hovered and _shift.chairs[i] != null)

# --- framing ---------------------------------------------------------------

## Move between the wide floor shot and one seat, and raise or stow the things
## that belong to you. The two modes have to LOOK different or nothing tells you
## which one you are in.
func _apply_framing() -> void:
	if _framed_at == _shift.at:
		return
	_framed_at = _shift.at
	var seated: bool = _shift.at != null
	var target: Node3D = _seat_cams[int(_shift.at)] if seated else _camera_floor

	# The seats sit close enough together for the floor view to be readable,
	# which means the neighbours are unavoidably inside the seat framing. They
	# are hidden rather than escaped - the mode button is how you check on them,
	# and it says so.
	for i in range(_seats.size()):
		var here: bool = seated and i == int(_shift.at)
		_show_seat(i, here or not seated)
		_customer_details[i].reveal(here)
		_offer_details[i].reveal(here)
		# The floor is customer cards and nothing else. The product slot and
		# whatever is sitting in it belong to the negotiation, and its detail
		# card would otherwise show its blank back down there. What you have left
		# on someone's table is on their floor card, in one line.
		_chair_zones[i].visible = seated
		_offer_details[i].visible = seated

	if _framing_tween != null and _framing_tween.is_running():
		_framing_tween.kill()
	_framing_tween = create_tween()
	_framing_tween.set_parallel(true)
	_framing_tween.set_ease(Tween.EASE_OUT)
	_framing_tween.set_trans(Tween.TRANS_CUBIC)
	_framing_tween.tween_property(_camera, "global_position",
		target.global_position, FRAMING_TWEEN)
	_framing_tween.tween_property(_camera, "global_rotation",
		target.global_rotation, FRAMING_TWEEN)

	# Camera-LOCAL, so this is purely "up into view" or "down out of it" - the
	# piles are already travelling with the camera for free.
	var delay: float = PILE_DELAY if seated else 0.0
	_tween_pile(_hand_zone, HAND_UP if seated else HAND_STOWED, delay)
	_tween_pile(_discard_zone, DISCARD_UP if seated else DISCARD_STOWED, delay)
	_tween_pile(_draw_zone, DRAW_UP if seated else DRAW_STOWED, delay)

func _show_seat(index: int, shown: bool) -> void:
	_seats[index].visible = shown

## NEVER enable a drop zone outside a drag.
##
## A CardCollection3D's DropZone is a StaticBody3D on a 14 x 4 slab sitting 3.2
## units IN FRONT of the cards, and Godot's 3D picking uses intersect_ray, which
## returns only the CLOSEST collider. An enabled drop zone is therefore a wall:
## the ray aimed at your hand hits Chair0/DropZone and the card never receives
## input_event or mouse_entered at all. That is why the addon enables them in
## _drag_card_start() and disables them again in _stop_drag(), and it is why a
## previous version of this file - which enabled them to stop hidden seats
## taking drops - made every card in the game untouchable.
##
## The hidden seats still must not take drops, so they are re-disabled HERE
## instead: DragController emits drag_started after enabling them all, so this
## runs late enough to win, and its own _stop_drag() disables everything again.
func _refuse_drops_on_hidden_seats() -> void:
	for i in range(_chair_zones.size()):
		if not _seats[i].visible:
			_chair_zones[i].disable_drop_zone()

func _tween_pile(zone: Node3D, to: Vector3, delay: float) -> void:
	_framing_tween.tween_property(zone, "position", to, PILE_TWEEN).set_delay(delay)

# --- rendering -------------------------------------------------------------

func _render() -> void:
	_tick_label.text = "tick %d/%d" % [_shift.tick, _shift.tick_budget]
	_banked_label.text = "banked %s / %s" \
		% [Format.money(_shift.margin_banked), Format.money(_shift.quota)]
	var risk: int = _shift.margin_at_risk()
	_at_risk_label.text = "%s unsigned on the floor" % Format.money(risk) \
		if risk > 0 else "nothing unsigned"

	_apply_framing()

	var seated: bool = _shift.at != null
	for i in range(_customer_cards.size()):
		_customer_cards[i].setup(_shift.chairs[i], seated and i == int(_shift.at))

	_render_mode_button(seated)
	_render_details()
	_render_hover_flip()
	_action_bar.visible = seated and not _report_overlay.visible
	_reconcile()
	_drain_log()

func _render_mode_button(seated: bool) -> void:
	if _report_overlay.visible:
		_mode_btn.visible = false
		return
	if seated:
		_mode_btn.visible = true
		_mode_btn.text = "< RETURN TO FLOOR"
		return
	var back := _last_customer_chair()
	if back == -1:
		_mode_btn.visible = false
		return
	# Going back to whoever you were last with costs nothing (m2/README.md's
	# free-return rule), and the label says so because otherwise checking the
	# floor feels like it must be costing you time.
	_mode_btn.visible = true
	_mode_btn.text = "BACK TO %s  (free)" % _shift.chairs[back].display_name

## The detail cards. There is no positioning to do and no panel to keep clear of
## anything: each one is a card parked behind the thing it describes, so "beside
## the product" is geometry the scene already guarantees rather than arithmetic
## this file has to get right every frame. The shared HUD panel that used to do
## this job kept landing on top of the very product it was describing.
##
## All three seats are refreshed, not just the one you are with. Two of them are
## occluded so it costs nothing worth counting, and it means a detail card can
## never slide out carrying what was true the last time you sat down.
func _render_details() -> void:
	for i in range(_seats.size()):
		var c: Customer = _shift.chairs[i]
		_customer_details[i].show_customer(c)
		# band_for lives on Shift, so the COOL / WARM / ALMOST thresholds that
		# decide the meter's colour have exactly one definition, in the model.
		var band := ""
		if c != null and c.offer != null:
			band = _shift.band_for(c.line - c.offer.appeal)
		_offer_details[i].show_offer(c, band)

func _drain_log() -> void:
	for line in _shift.events.slice(_events_seen):
		_event_log.append_text(line + "\n")
	_events_seen = _shift.events.size()
	for entry in _shift.action_log.slice(_actions_seen):
		var color := "red" if entry["floor_wide"] else "purple"
		_event_log.append_text("[color=%s]>> %s (%s): %s - %s[/color]\n"
			% [color, entry["customer"], entry["key"], entry["name"],
				", ".join(entry["descriptions"])])
	_actions_seen = _shift.action_log.size()

func _show_report() -> void:
	_report_overlay.visible = true
	var r := _shift.report()
	# Enriched here, not in Shift.report(): standing_BEFORE belongs to the run,
	# which Shift has never held a reference to. This is the first point that
	# knows both halves - and the only point that can tell a fatal shift from an
	# ordinary one, so the button override happens right here too.
	var standing_after: int = clampi(
		_standing_before + int(r["standing_delta"]), 0, _shift.cfg.standing_start)
	r["standing_before"] = _standing_before
	r["standing_after"] = standing_after
	r["standing_start"] = _shift.cfg.standing_start
	if standing_after <= 0:
		_report_overlay.set_button_text("YOU'RE FIRED")
	_report_overlay.setup(r)
	_action_bar.visible = false
	_mode_btn.visible = false
	_hovered = -1
	_render_hover_flip()
	# The camera stays where it is - the overlay covers it - but the table itself
	# must not be left mid-negotiation underneath, with two thirds of the floor
	# hidden and two detail cards still slid out over a shift that is finished.
	for i in range(_seats.size()):
		_show_seat(i, true)
		_customer_details[i].reveal(false)
		_offer_details[i].reveal(false)

# --- dragging --------------------------------------------------------------

func _on_drag_started(card) -> void:
	_dragging = card as CardFace3D
	_refuse_drops_on_hidden_seats()

func _on_drag_stopped(_card) -> void:
	_dragging = null
	if _shift == null:
		return
	# DragController keeps working on the card AFTER emitting card_moved: it
	# restores global_position and re-enables collision, undoing what _dress()
	# decided. Settling here, once it has finished, is what makes a bounced card
	# fly home instead of sticking where it was dropped.
	_render()
	for zone in _all_zones():
		zone.apply_card_layout()

## A card was dropped somewhere new. Ask the router what that means, run it, and
## let reconciliation put the node where the model ends up saying it belongs.
##
## There is deliberately no explicit revert. A refusal costs nothing, so the card
## is still in shift.hand, so CardHomes still says ZONE_HAND, so _reconcile()
## walks it back - tweening, because _move_card() preserves global_position.
## The bounce IS the reconcile.
func _on_drag_card_moved(card, from_coll, to_coll, _from_index: int, _to_index: int) -> void:
	if _shift == null or from_coll == to_coll:
		# Same collection is a hand reorder. The model has no command for it, and
		# reconciling restores model order next render - which is right, because
		# the 1-4 keys index the model's hand.
		return

	var face := card as CardFace3D
	var plan := DropRouter.plan(_shift, face.uid, _zone_name_of(to_coll))
	var command: StringName = plan["command"]

	if command == DropRouter.IGNORE:
		return
	if command == DropRouter.NONE:
		_event_log.append_text("[color=red]%s[/color]\n" % plan["reason"])
		_render()
		return

	if int(plan["approach"]) >= 0:
		var move := _shift.approach(int(plan["approach"]))
		if not move.ok:
			_apply(move)
			return

	# MANDATORY, not defensive. approach() burns a tick, a tick fires customer
	# actions, and a Karen's DiscardHand can take the very card being dragged.
	var idx := CardIndex.of(_shift, face.uid)
	if idx == -1:
		_event_log.append_text(
			"[color=red]That card left your hand before you could play it.[/color]\n")
		_render()
		return

	_apply(_shift.dig(idx) if command == DropRouter.DIG else _shift.play_card(idx))

func _zone_name_of(collection) -> StringName:
	for i in range(_chair_zones.size()):
		if collection == _chair_zones[i]:
			return CardHomes.chair_zone(i)
	if collection == _hand_zone:
		return CardHomes.ZONE_HAND
	if collection == _discard_zone:
		return CardHomes.ZONE_DISCARD
	if collection == _draw_zone:
		return CardHomes.ZONE_DRAW
	return &"unknown"

# --- reconciliation --------------------------------------------------------

func _zone_for(zone: StringName) -> CardCollection3D:
	if zone == CardHomes.ZONE_HAND:
		return _hand_zone
	if zone == CardHomes.ZONE_DRAW:
		return _draw_zone
	if zone == CardHomes.ZONE_DISCARD:
		return _discard_zone
	var chair := CardHomes.chair_of(zone)
	return _chair_zones[chair] if chair >= 0 and chair < _chair_zones.size() else _discard_zone

## Diff the table against the model. Adds and moves only what changed; never
## frees, and never touches the card under the cursor.
func _reconcile() -> void:
	var desired := CardHomes.desired(_shift)

	for uid in desired:
		if not _nodes.has(uid):
			var node: CardFace3D = CardFaceScene.instantiate()
			node.setup(desired[uid]["instance"])
			_nodes[uid] = node
			var home := _zone_for(desired[uid]["zone"])
			home.insert_card(node, clampi(desired[uid]["ordinal"], 0, home.cards.size()))

	for uid in desired:
		var node: CardFace3D = _nodes[uid]
		if node == _dragging:
			continue
		# Re-rendered every pass on purpose: a product's margin changes under it
		# while it sits on the table.
		node.setup(desired[uid]["instance"])
		var zone: StringName = desired[uid]["zone"]
		var home := _zone_for(zone)
		var ordinal: int = desired[uid]["ordinal"]
		if node.get_parent() != home:
			_move_card(node, home, ordinal)
		elif home == _hand_zone and home.cards.find(node) != ordinal:
			home.move_card(node, clampi(ordinal, 0, home.cards.size() - 1))
		_dress(node, zone)

func _move_card(node: CardFace3D, to_zone: CardCollection3D, ordinal: int) -> void:
	# Preserve where the card was on screen across the reparent, so the layout
	# tween reads as the card travelling rather than teleporting.
	var was := node.global_position
	var from := node.get_parent()
	if from is CardCollection3D:
		var at: int = (from as CardCollection3D).cards.find(node)
		if at != -1:
			(from as CardCollection3D).remove_card(at)
	to_zone.insert_card(node, clampi(ordinal, 0, to_zone.cards.size()))
	node.global_position = was
	to_zone.apply_card_layout()

func _dress(node: CardFace3D, zone: StringName) -> void:
	# Both piles are turned over. A face-up discard is a second hand's worth of
	# card faces competing for the same glance as the hand right next to it, and
	# what has already been spent is not a decision you are still making.
	node.face_down = zone == CardHomes.ZONE_DRAW or zone == CardHomes.ZONE_DISCARD
	# Only cards in hand are draggable. A placed product must not intercept the
	# pointer aimed at the zone it sits in.
	if zone == CardHomes.ZONE_HAND:
		node.enable_collision()
		node.hover_pos_move = HAND_HOVER_LIFT
	else:
		node.disable_collision()
