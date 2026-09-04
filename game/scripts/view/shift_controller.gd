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
const PILE_DEPTH := -11.0
const HAND_UP := Vector3(0.0, -3.2, PILE_DEPTH)
const HAND_STOWED := Vector3(0.0, -12.5, -11.0)
const DISCARD_UP := Vector3(8.6, -4.4, -11.0)
const DISCARD_STOWED := Vector3(8.6, -13.5, -11.0)
const DRAW_UP := Vector3(-8.6, -4.4, -11.0)
const DRAW_STOWED := Vector3(-8.6, -13.5, -11.0)

const FRAMING_TWEEN := 0.5
## Your things arrive a beat after the camera settles, so the move reads as
## travelling and then setting your things down.
const PILE_TWEEN := 0.4
const PILE_DELAY := 0.18

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
@onready var _event_log: RichTextLabel = %EventLog
@onready var _mode_btn: Button = %ModeButton
@onready var _action_bar: Control = %ActionBar
@onready var _offer_btn: Button = %OfferButton
@onready var _drop_btn: Button = %DropButton
@onready var _close_btn: Button = %CloseButton
@onready var _tooltip: Control = %Tooltip
@onready var _tooltip_label: Label = %TooltipLabel
@onready var _report_overlay = %ReportOverlay

var _shift: Shift
var _chair_zones: Array = []
var _seat_cams: Array = []
var _customer_cards: Array = []
var _offer_panels: Array = []
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

	_chair_zones = [%Chair0, %Chair1, %Chair2]
	_seat_cams = [%SeatCam0, %SeatCam1, %SeatCam2]
	_customer_cards = [%Customer0, %Customer1, %Customer2]
	_offer_panels = [%OfferPanel0, %OfferPanel1, %OfferPanel2]

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

	for i in range(_customer_cards.size()):
		var card = _customer_cards[i]
		card.chair = i
		card.card_3d_mouse_down.connect(_on_chair_pressed.bind(i))
		card.card_3d_mouse_over.connect(_on_customer_hover.bind(i))
		card.card_3d_mouse_exit.connect(_on_customer_unhover.bind(i))

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
	# consuming a click here takes it from every card on the table.
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
	_hovered = -1
	_framed_at = -999                     # force the framing to re-apply

	# The ONLY place card nodes are freed. _reconcile() never frees: a freed node
	# still held by DragController crashes the next apply_card_layout().
	_dragging = null
	for zone in _all_zones():
		for card in zone.remove_all():
			card.queue_free()
	_nodes.clear()

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
	_render()
	if _shift.is_over():
		_show_report()

# --- hover -----------------------------------------------------------------

func _on_customer_hover(chair: int) -> void:
	_hovered = chair
	_render_tooltip()

func _on_customer_unhover(chair: int) -> void:
	if _hovered == chair:
		_hovered = -1
	_render_tooltip()

## On the floor a customer card carries only identity, so what they DO lives
## behind a hover. Once you are with them it is on the expanded card instead,
## which is why the tooltip is suppressed in that framing.
func _render_tooltip() -> void:
	var showing: bool = _hovered != -1 and _shift != null and _shift.at == null \
		and not _report_overlay.visible and _shift.chairs[_hovered] != null
	_tooltip.visible = showing
	if not showing:
		return
	var c = _shift.chairs[_hovered]
	_tooltip_label.text = "%s - %s\n\nWHAT THEY DO\n%s" % [
		c.display_name, c.archetype.display_name, CustomerCard3D.behaviour_text(c)]
	var p := _camera.unproject_position(
		_customer_cards[_hovered].global_position + Vector3(0, -2.2, 0))
	_tooltip.position = Vector2(
		clampf(p.x - _tooltip.size.x * 0.5, 16.0, 1904.0 - _tooltip.size.x),
		clampf(p.y + 16.0, 16.0, 1064.0 - _tooltip.size.y))

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
	_render_offer(seated)
	_render_tooltip()
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

## Each seat owns its panel, so this only has to pick the right one and hide the
## rest - no repositioning a shared panel between customers.
func _render_offer(seated: bool) -> void:
	for i in range(_offer_panels.size()):
		_offer_panels[i].visible = seated and i == int(_shift.at) 			and not _report_overlay.visible
	if not seated or _report_overlay.visible:
		return

	var chair := int(_shift.at)
	var c: Customer = _shift.chairs[chair]
	var panel: Control = _offer_panels[chair]
	var col: Node = panel.get_node(^"Row/Column")
	var bar: Control = panel.get_node(^"Row/AppealBar")
	var name_label := col.get_node(^"OfferNameLabel") as Label
	var cat_label := col.get_node(^"OfferCategoryLabel") as Label
	var margin_label := col.get_node(^"OfferMarginLabel") as Label
	var gap_label := col.get_node(^"GapLabel") as Label

	var o = c.offer
	if o == null:
		name_label.text = "nothing on the table"
		cat_label.text = "drag a product onto them"
		margin_label.text = ""
		gap_label.text = ""
		bar.set_state(0, c.line, 40, "")
		_position_offer_panel(chair)
		return

	name_label.text = o.product.display_name
	cat_label.text = "%s . %s" % [o.product.interest.category.display_name,
		o.product.interest.display_name]
	margin_label.text = Format.money(o.margin)

	if not o.revealed:
		var band := _shift.band_for(c.line - o.appeal)
		bar.set_state(0, c.line, 40, band)
		gap_label.text = band
		gap_label.add_theme_color_override("font_color", Palette.color(&"text_dim"))
	else:
		bar.set_state(o.appeal, c.line, 40, "")
		var gap: int = c.line - o.appeal
		if gap <= 0:
			gap_label.text = "READY"
			gap_label.add_theme_color_override("font_color", Palette.color(&"patience_ok"))
		else:
			gap_label.text = "%d SHORT" % gap
			gap_label.add_theme_color_override("font_color", Palette.color(&"alert"))
	_position_offer_panel(chair)

## Sits to the LEFT of its OWN seat's product slot, clear of the card, so the
## numbers are beside the thing they describe.
func _position_offer_panel(chair: int) -> void:
	var panel: Control = _offer_panels[chair]
	var slot: Vector3 = _chair_zones[chair].global_position
	if _camera.is_position_behind(slot):
		return
	# Offset by the card's own half-width in screen space, so the panel clears
	# the product rather than landing on top of it.
	var edge := _camera.unproject_position(slot + Vector3(-1.45, 0.0, 0.0))
	var mid := _camera.unproject_position(slot)
	panel.position = Vector2(
		clampf(edge.x - panel.size.x - 24.0, 16.0, 1904.0 - panel.size.x),
		clampf(mid.y - panel.size.y * 0.5, 16.0, 1064.0 - panel.size.y))

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
	_action_bar.visible = false
	for panel in _offer_panels:
		panel.visible = false
	_tooltip.visible = false
	_mode_btn.visible = false

# --- dragging --------------------------------------------------------------

func _on_drag_started(card) -> void:
	_dragging = card as CardFace3D

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
	node.face_down = zone == CardHomes.ZONE_DRAW
	# Only cards in hand are draggable. A placed product must not intercept the
	# pointer aimed at the zone it sits in.
	if zone == CardHomes.ZONE_HAND:
		node.enable_collision()
	else:
		node.disable_collision()
