extends Node3D
## The whole game: a 3D card table with a 2D HUD over it.
##
## Two rules hold this file together.
##
## ONE: the model is authoritative and this never guesses. Every command goes
## through _apply(), and where a card node ends up is never decided by whoever
## moved it - it is recomputed from model state by CardHomes afterwards. That is
## why a customer walking out at zero patience takes their unsigned offer to the
## discard correctly, even though nothing dragged it there.
##
## TWO: cards are matched by uid, never rebuilt. G1's _render() freed and
## recreated the whole hand every frame; in 3D that would free the node a drag
## is holding and kill every tween mid-flight. _reconcile() diffs instead.

const CardFaceScene := preload("res://scenes/cards/card_face_3d.tscn")
const FloorCardScene := preload("res://scenes/floor_card.tscn")
const CustomerPanelScene := preload("res://scenes/customer_panel.tscn")

## Gap in pixels between a chair's card and the info panel drawn under it.
const FLOOR_CARD_GAP := 14.0
## Half a card's height in world units, from card_3d.tscn's 2.5 x 3.5 PlaneMesh.
const CARD_HALF_HEIGHT := 1.75
const SEAT_PANEL_SIZE := Vector2(320, 224)
## How long the camera takes to move between the floor and a seat.
const FRAMING_TWEEN := 0.45
## Where the seats you are NOT with go while negotiating: a small strip, top
## left, subordinate to the panel but still readable. GODOT_SPEC.md 6 requires
## patience and unsigned to stay live for every chair, and a customer walking
## out unnoticed is the exact frustration that rule exists to prevent.
const STRIP_ORIGIN := Vector2(28, 78)
const STRIP_SCALE := 0.55
const STRIP_GAP := 16.0
## Must match build_shift_scene.gd's HAND_Y_* - the hand's resting height in
## each framing.
const HAND_Y_FLOOR := -13.0
const HAND_Y_SEAT := -4.4

@onready var _camera: Camera3D = $Camera3D
@onready var _camera_floor: Marker3D = %CameraFloor
@onready var _drag: DragController = $DragController
@onready var _hand_zone: CardCollection3D = %Hand
@onready var _draw_zone: CardCollection3D = %Draw
@onready var _discard_zone: CardCollection3D = %Discard

@onready var _hud: Control = %HudRoot
@onready var _tick_label: Label = %TickLabel
@onready var _banked_label: Label = %BankedLabel
@onready var _at_risk_label: Label = %AtRiskLabel
@onready var _customer_slot: Control = %CustomerSlot
@onready var _empty_slot_label: Label = %EmptySlotLabel
@onready var _event_log: RichTextLabel = %EventLog
@onready var _report_overlay = %ReportOverlay

var _shift: Shift
var _chair_zones: Array = []
var _seat_cams: Array = []
var _framing_tween: Tween
var _framed_at = null            ## which seat the camera is currently framing
var _floor_cards: Array = []
var _customer_panel
var _nodes: Dictionary = {}          ## uid -> CardFace3D
var _dragging: CardFace3D = null
var _events_seen: int = 0
var _actions_seen: int = 0

func _ready() -> void:
	# Card3D receives mouse input through StaticBody3D.input_event, which does
	# nothing at all unless the viewport is picking. It defaults to false.
	get_viewport().physics_object_picking = true

	_chair_zones = [%Chair0, %Chair1, %Chair2]
	_seat_cams = [%SeatCam0, %SeatCam1, %SeatCam2]
	for zone in _chair_zones:
		_drag.add_card_collection(zone)
	_drag.add_card_collection(_hand_zone)
	_drag.add_card_collection(_draw_zone)
	_drag.add_card_collection(_discard_zone)

	# Only DragController's card_moved. CardCollection3D has a DIFFERENT signal
	# of the same name and lower arity for intra-collection reorders, which
	# move_card() re-emits - and reconciliation calls move_card(). Connecting
	# both is how this becomes infinitely recursive.
	_drag.card_moved.connect(_on_drag_card_moved)
	_drag.drag_started.connect(_on_drag_started)
	_drag.drag_stopped.connect(_on_drag_stopped)

	_register_keyboard_actions()
	_start_new_shift()
	_report_overlay.restart_pressed.connect(_start_new_shift)

# --- input -----------------------------------------------------------------

func _register_keyboard_actions() -> void:
	_bind_key(&"card_1", KEY_1)
	_bind_key(&"card_2", KEY_2)
	_bind_key(&"card_3", KEY_3)
	_bind_key(&"card_4", KEY_4)
	_bind_key(&"dig_1", KEY_1, true)        # Shift+1..4: dig, distinct from playing
	_bind_key(&"dig_2", KEY_2, true)
	_bind_key(&"dig_3", KEY_3, true)
	_bind_key(&"dig_4", KEY_4, true)
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
	# consuming a click here would take it away from every card on the table.
	if _shift == null or _shift.is_over():
		return
	if event.is_action_pressed("dig_1"): _try_dig(0)
	elif event.is_action_pressed("dig_2"): _try_dig(1)
	elif event.is_action_pressed("dig_3"): _try_dig(2)
	elif event.is_action_pressed("dig_4"): _try_dig(3)
	elif event.is_action_pressed("card_1"): _try_card(0)
	elif event.is_action_pressed("card_2"): _try_card(1)
	elif event.is_action_pressed("card_3"): _try_card(2)
	elif event.is_action_pressed("card_4"): _try_card(3)
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

func _start_new_shift() -> void:
	var cfg: ShiftConfig = load("res://data/shift_config.tres")
	var interests: InterestPool = load("res://data/interests/interest_pool.tres")
	var cards: CardPool = load("res://data/card_pool.tres")
	var archetypes: ArchetypePool = load("res://data/archetype_pool.tres")
	_shift = Shift.new(cfg, interests, cards, archetypes, randi(), [])
	_events_seen = 0
	_actions_seen = 0
	_event_log.clear()
	_report_overlay.visible = false

	# The ONLY place card nodes are freed. _reconcile() never frees: a freed node
	# still referenced by DragController or a collection's `cards` array crashes
	# the next apply_card_layout().
	_dragging = null
	for zone in _all_zones():
		for card in zone.remove_all():
			card.queue_free()
	_nodes.clear()

	for c in _floor_cards:
		c.queue_free()
	_floor_cards.clear()
	for i in range(_chair_zones.size()):
		var fc := FloorCardScene.instantiate()
		_hud.add_child(fc)
		fc.size = SEAT_PANEL_SIZE
		fc.pressed.connect(_on_chair_pressed)
		_floor_cards.append(fc)

	if _customer_panel:
		_customer_panel.queue_free()
	_customer_panel = CustomerPanelScene.instantiate()
	_customer_slot.add_child(_customer_panel)
	_customer_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_customer_panel.offer_pressed.connect(_on_offer)
	_customer_panel.close_pressed.connect(_on_close)
	_customer_panel.drop_pressed.connect(_on_drop)

	_render()

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

## Every model command funnels through here. A refusal costs nothing but must
## still say why - "the rules never say no" only holds if the player hears it.
func _apply(res: Result) -> void:
	if not res.ok:
		_event_log.append_text("[color=red]%s[/color]\n" % res.msg)
	_render()
	if _shift.is_over():
		_show_report()

# --- dragging --------------------------------------------------------------

func _on_drag_started(card) -> void:
	_dragging = card as CardFace3D

func _on_drag_stopped(_card) -> void:
	_dragging = null
	if _shift == null:
		return
	# DragController keeps working on the card AFTER emitting card_moved: it
	# restores the card's global_position (so the drop point animates) and
	# re-enables its collision, both of which undo what _dress() just decided.
	# Settling here, once the library has finished, is what makes a bounced card
	# actually fly home instead of sticking where it was dropped.
	_render()
	for zone in _all_zones():
		zone.apply_card_layout()

## A card was dropped somewhere new. Ask the router what that means, run it, and
## let reconciliation put the node wherever the model ends up saying it belongs.
##
## There is deliberately no explicit revert. A refusal costs nothing, so the card
## is still in shift.hand, so CardHomes still says ZONE_HAND, so _reconcile()
## walks it back on its own - and tweens it, because _move_card() preserves
## global_position across the reparent. The bounce IS the reconcile.
func _on_drag_card_moved(card, from_coll, to_coll, _from_index: int, _to_index: int) -> void:
	if _shift == null or from_coll == to_coll:
		# Same collection means a hand reorder. The model has no command for it,
		# and reconciliation will restore model order on the next render - which
		# is correct, because the 1-4 keys index the model's hand and a view-only
		# reorder would quietly break that mapping.
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
	# actions, and a Karen's DiscardHand can take the very card being dragged -
	# so the index resolved before the move may now point at a different card.
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

# --- rendering -------------------------------------------------------------

func _render() -> void:
	_tick_label.text = "tick %d/%d" % [_shift.tick, _shift.tick_budget]
	_banked_label.text = "banked %s / %s" \
		% [Format.money(_shift.margin_banked), Format.money(_shift.quota)]
	var risk: int = _shift.margin_at_risk()
	_at_risk_label.text = "%s unsigned on the floor" % Format.money(risk) \
		if risk > 0 else "nothing unsigned"

	_apply_framing()
	for i in range(_floor_cards.size()):
		_floor_cards[i].setup(_shift.chairs[i], _shift.walk_up[i], i)
	_position_floor_cards()

	if _shift.at != null:
		var cust: Customer = _shift.chairs[_shift.at]
		var band := ""
		if cust.offer != null and not cust.offer.revealed:
			band = _shift.band_for(cust.line - cust.offer.appeal)
		_customer_panel.visible = true
		_empty_slot_label.visible = false
		_customer_panel.setup(cust, band)
	else:
		_customer_panel.visible = false
		_empty_slot_label.visible = true

	_reconcile()
	_drain_log()

## Move the camera between the wide floor shot and a single seat. The two modes
## have to LOOK different or nothing tells you which one you are in; pushing in
## also makes the hand big enough to read, which no amount of font tuning at the
## old framing achieved.
func _apply_framing() -> void:
	var target: Node3D = _camera_floor
	if _shift != null and _shift.at != null:
		target = _seat_cams[int(_shift.at)]
	if _framed_at == _shift.at:
		return
	_framed_at = _shift.at
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
	# "Your cards come up." The hand is dropped out of the shot on the floor and
	# lifts into reach when you sit down with someone.
	var hand_y: float = HAND_Y_SEAT if _shift.at != null else HAND_Y_FLOOR
	_framing_tween.tween_property(_hand_zone, "position:y", hand_y, FRAMING_TWEEN)

## On the floor, each seat's panel sits under its own seat, so who is where is
## spatial. While negotiating, the seat you are AT is described by the side
## panel instead, and the other two shrink into a corner strip - present enough
## to triage, never lined up as equals with the person in front of you.
func _position_floor_cards() -> void:
	var negotiating: bool = _shift.at != null
	var strip_slot := 0
	for i in range(_floor_cards.size()):
		var card: Control = _floor_cards[i]
		if _report_overlay.visible:
			card.visible = false
			continue

		if negotiating:
			if i == int(_shift.at):
				card.visible = false          # the side panel describes this seat now
				continue
			card.visible = true
			card.scale = Vector2(STRIP_SCALE, STRIP_SCALE)
			card.position = STRIP_ORIGIN + Vector2(
				strip_slot * (SEAT_PANEL_SIZE.x * STRIP_SCALE + STRIP_GAP), 0)
			strip_slot += 1
			continue

		card.scale = Vector2.ONE
		var anchor: Vector3 = _chair_zones[i].global_position + Vector3(0, -CARD_HALF_HEIGHT, 0)
		if _camera.is_position_behind(anchor):
			card.visible = false
			continue
		card.visible = true
		var p := _camera.unproject_position(anchor)
		card.position = Vector2(p.x - card.size.x * 0.5, p.y + FLOOR_CARD_GAP)

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
	_report_overlay.setup(_shift.report())
	_position_floor_cards()

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
## frees, and never touches the card currently under the cursor.
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
	node.face_down = zone == CardHomes.ZONE_DRAW
	# Only cards in hand are draggable. A placed product must not intercept the
	# pointer aimed at the zone it is sitting in.
	if zone == CardHomes.ZONE_HAND:
		node.enable_collision()
	else:
		node.disable_collision()
