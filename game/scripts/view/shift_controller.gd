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
const PILE_DEPTH := -19.91
const HAND_UP := Vector3(0.0, -4.77, PILE_DEPTH)
const HAND_STOWED := Vector3(0.0, -12.6, PILE_DEPTH)
const DISCARD_UP := Vector3(7.2, -4.00, PILE_DEPTH)
const DISCARD_STOWED := Vector3(7.2, -12.6, PILE_DEPTH)
const DRAW_UP := Vector3(-7.27, -4.00, PILE_DEPTH)
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

## Pushes DragController's own drag-start threshold (addons/card_3d/scripts/
## drag_controller.gd) far past anything a mouse gesture could cross, while a
## pull is pending - pressing a card still lifts it for a hover-style read
## (that gate is can_select_card, a separate code path this never touches),
## but the mouse can never travel far enough to turn that into a real drag.
## Restored to whatever the scene actually configured (_normal_drag_threshold,
## captured once at _ready()) the moment the pull resolves.
const _LOCKED_DRAG_THRESHOLD := 999999.0

## The run layer listens for this. The controller plays ONE shift; deciding
## what comes next is not its job.
signal shift_finished(report: Dictionary)
## Clicking the draw pile - "your deck" - the run layer owns the actual
## overlay (see run_controller.gd), reachable from here and from the shop's
## own button.
signal deck_viewed

@onready var _camera: Camera3D = $Camera3D
@onready var _drag: DragController = $DragController
@onready var _hand_zone: CardCollection3D = %Hand
@onready var _draw_zone: CardCollection3D = %Draw
@onready var _discard_zone: CardCollection3D = %Discard

@onready var _hud: Control = %HudRoot
@onready var _tick_label: Label = %TickLabel
@onready var _banked_label: Label = %BankedLabel
@onready var _product_quota_label: Label = %ProductQuotaLabel
@onready var _standing_label: Label = %StandingLabel
@onready var _at_risk_label: Label = %AtRiskLabel
@onready var _event_log: RichTextLabel = %EventLog
@onready var _side_panel: Control = %SidePanel
@onready var _log_toggle: Button = %LogToggle
## Who is waiting for a chair - see _render_waiting().
@onready var _waiting_panel: Control = %WaitingPanel
@onready var _waiting_rows: Control = %WaitingRows
@onready var _waiting_row: Control = %WaitingRow
@onready var _next_arrival: Label = %NextArrival
## What YOU say as you play a card - see build_shift_scene.gd's
## PLAYER_BUBBLE_RECT, and _drain_log().
@onready var _player_bubble: SpeechBubble = %PlayerBubble
@onready var _drop_drag_hint: Node3D = %DropDragHint
@onready var _report_overlay = %ReportOverlay
@onready var _pull_picker: Control = %PullPicker
## The table's hints, drawn flat on the HUD rather than into the scene - see
## screen_tag.gd for why. Each one follows a TagAnchor on the table.
@onready var _hint_layer: Control = %HintLayer
@onready var _draw_tag: ScreenTag = %DrawTag
@onready var _discard_tag: ScreenTag = %DiscardTag
@onready var _drop_tag: ScreenTag = %DropTag
## The windows along the back wall - see OfficeWindows.
@onready var _windows: OfficeWindows = %OfficeWindows

var _shift: Shift
## Which part of the day this shift is worked in: a ShiftProfile id, the key
## ShiftHours and the week's calendar use. It sets what the windows show and
## the time on the tablet's clock.
var _time_of_day: StringName = &"midday"
## The shift log folded up to its heading - see set_log_folded(). Kept from one
## shift to the next, since the same ShiftView plays every shift of a run.
var _log_folded := false
## The log's size open, as the scene built it, to open it back up to.
var _log_open_size := Vector2.ZERO
## The waiting list the rows were last built for, so a render that changes
## nothing about it leaves them alone.
var _waiting_shown: Array[CustomerArchetype] = []
## True while a RunController-level overlay (the deck viewer) sits on top of
## the floor - see set_hud_dimmed(). Both HUD panels it hides live in their
## own CanvasLayer, drawing OVER any plain Control regardless of tree order,
## so the overlay being visually "on top" does nothing to them on its own.
var _hud_dimmed := false
## Captured once, at _ready() - whatever the scene actually configured
## DragController's own threshold to, before anything here ever touches it.
var _normal_drag_threshold: float = 0.0
var _standing_before: int = 0        ## the run's standing when THIS shift started
var _seats: Array = []               ## one Node3D per seat, never hidden now
## Whoever the carousel is pointed at. Survives stepping out to the floor, so
## the view does not spin back to seat 0 every time you stand up.
var _last_station: int = 0
var _chair_zones: Array = []
## Drop-only targets over each customer's own card - see build_shift_scene.gd's
## CustomerZone%d. Never holds a card; dragging the table's offer here means
## "offer it", distinct from Chair%d's own "place a card from your hand".
var _customer_zones: Array = []
## Double-tap-to-close targets over each PRODUCT slot - see build_shift_scene.gd's
## ChairPad%d. Collision starts disabled; _render_details() enables it only when
## that seat's table is empty and there is something unsigned left to close.
var _chair_pads: Array = []
var _close_hints: Array = []         ## one Node3D (slab+label) per seat, same rule
## "CLOSE SOON" - a red tab in each customer's folder corner, shown while time
## is short and they have something unsigned. A HUD tag, so it stays up while
## the folder turns over under it.
var _close_soon_tags: Array = []
## The tablet at each desk: on at the one you are sitting at, where the product
## stands on its screen with how it is landing either side of it.
var _tablets: Array = []
## Touch's own double-tap tracker: InputEventMouseButton.double_click never
## actually fires for a touch-emulated click on a real device (only real
## mice), unlike the hover-equivalence _on_pad_input leans on - confirmed
## broken on an actual phone. -1/0.0 means "no pending first tap".
var _last_chair_tap_chair: int = -1
var _last_chair_tap_time: float = 0.0
const CHAIR_DOUBLE_TAP_WINDOW := 0.4
var _offer_drag_hints: Array = []    ## one Node3D (slab) per seat, hidden until dragged
var _offer_tags: Array = []          ## "OFFER PRODUCT", following _offer_drag_hints
## "Nothing on the table", plus "or double-click to close the deal" when there
## is something to close. One per seat; only the seat you are at ever shows one.
var _table_notes: Array = []
var _tags: Array = []                ## every ScreenTag, placed together each frame
var _seat_cam: Marker3D = null
var _carousel: Node3D = null
var _customer_cards: Array = []
var _customer_flips: Array = []      ## the pair-turning node, one per seat
var _hover_pads: Array = []          ## the immovable thing the mouse actually finds
var _customer_details: Array = []
var _nodes: Dictionary = {}          ## uid -> CardFace3D
var _dragging: CardFace3D = null
var _framing_tween: Tween
var _framed_at = null
var _hovered: int = -1
var _peeked: int = -1                ## touch's stand-in for hover: tap once to peek
## A customer pad the pointer reached while carrying a card - or was on when it
## let go of one - and has not left since. Being there is not looking at them:
## finishing a drag onto a customer used to turn their folder over, burying the
## front you were dropping onto. It takes leaving and coming back to turn it.
var _hover_held: int = -1
## Whether the pointer has really moved since the table last moved under it - a
## chair switch, or someone new sitting down. See _on_pad_entered().
var _hover_armed := true
## A pad the pointer came to be over without moving, waiting for it to move.
var _entered_unarmed: int = -1
## Who was in each chair at the last render - someone new sitting down under a
## resting pointer must not count as being looked at.
var _seated_seen: Array = []
## Injectable so a test can force the touch branch without a real touchscreen -
## production never overrides this, always the real platform check.
var _touch_check: Callable = DisplayServer.is_touchscreen_available
## Where the pointer is, for the same reason: a headless run has no mouse to
## put over a customer. Unset in production, which asks the viewport.
var _pointer: Callable = Callable()
var _events_seen: int = 0
var _actions_seen: int = 0
var _player_lines_seen: int = 0
## A customer's line held back to answer yours - see _say_on_the_card().
const REPLY_DELAY := 0.7
var _pending_says: Array = []
## True once the tick counter has already pulsed for THIS stretch of low time -
## reset the moment time is no longer short, so a shift that somehow recovers
## (it never does today, but nothing here should assume that) pulses again.
var _tick_warning_flashed := false

func _ready() -> void:
	# Card3D takes mouse input through StaticBody3D.input_event, which does
	# nothing at all unless the viewport is picking. It defaults to false.
	get_viewport().physics_object_picking = true

	_seats = [%Seat0, %Seat1, %Seat2]
	_chair_zones = [%Chair0, %Chair1, %Chair2]
	_customer_zones = [%CustomerZone0, %CustomerZone1, %CustomerZone2]
	_offer_drag_hints = [%OfferDragHint0, %OfferDragHint1, %OfferDragHint2]
	_chair_pads = [%ChairPad0, %ChairPad1, %ChairPad2]
	_close_hints = [%CloseHint0, %CloseHint1, %CloseHint2]
	_close_soon_tags = [%CloseSoonTag0, %CloseSoonTag1, %CloseSoonTag2]
	_tablets = [%Tablet0, %Tablet1, %Tablet2]
	_seat_cam = %SeatCam
	_carousel = %Carousel
	_customer_cards = [%Customer0, %Customer1, %Customer2]
	_customer_flips = [%CustomerFlip0, %CustomerFlip1, %CustomerFlip2]
	_hover_pads = [%HoverPad0, %HoverPad1, %HoverPad2]
	_customer_details = [%CustomerDetail0, %CustomerDetail1, %CustomerDetail2]
	_offer_tags = [%OfferTag0, %OfferTag1, %OfferTag2]
	_table_notes = [%TableNote0, %TableNote1, %TableNote2]
	_tags = [_draw_tag, _discard_tag, _drop_tag]
	_tags.append_array(_offer_tags)
	_tags.append_array(_table_notes)
	_tags.append_array(_close_soon_tags)
	# The tag lives in the HUD and its anchor on the table, so the scene root
	# (this node) is the one place a path between them resolves from.
	for tag in _tags:
		tag.anchor = get_node(tag.anchor_path) as Node3D

	for zone in _chair_zones:
		_drag.add_card_collection(zone)
	for zone in _customer_zones:
		_drag.add_card_collection(zone)
	_drag.add_card_collection(_hand_zone)
	_drag.add_card_collection(_draw_zone)
	_drag.add_card_collection(_discard_zone)
	_normal_drag_threshold = _drag.card_drag_threshold

	# "Your deck" - clicking the pile itself, not dragging FROM it (the pile
	# is only ever a DROP target, for the hand card a dig discards) - opens
	# the same whole-deck overlay the shop's own button does.
	_draw_zone.card_clicked.connect(func(_card): deck_viewed.emit())

	# Only DragController's card_moved. CardCollection3D has a same-named signal
	# of lower arity for reorders which move_card() re-emits - and reconciling
	# calls move_card(). Connecting both makes this recursive.
	_drag.card_moved.connect(_on_drag_card_moved)
	_drag.drag_started.connect(_on_drag_started)
	_drag.drag_stopped.connect(_on_drag_stopped)

	# card_selected fires on PRESS, before the addon's own drag-threshold check -
	# hovering already lifts a card for a mouse, but touch has no hover state at
	# all, so without this a tap-and-hold shows nothing until you have dragged
	# far enough to count as a drag. This is hand-only: draw/discard are face
	# down, and a card already on someone's table isn't re-dragged from there.
	# Harmless for a mouse - hovering already lifted it, and set_hovered() on an
	# already-lifted card just re-tweens to the same place.
	_hand_zone.card_selected.connect(_on_hand_card_pressed)
	_hand_zone.card_deselected.connect(_on_hand_card_released)

	# Hover and click belong to the PAD, not to the card. The card turns over,
	# and a flat collider edge-on has no area at all - so hovering the card made
	# it flicker between flipped and not, and where you brought the cursor in
	# from decided whether it settled. The pad never moves.
	for i in range(_customer_cards.size()):
		_customer_cards[i].chair = i
		var pad: StaticBody3D = _hover_pads[i]
		pad.mouse_entered.connect(_on_pad_entered.bind(i))
		pad.mouse_exited.connect(_on_customer_unhover.bind(i))
		pad.input_event.connect(_on_pad_input.bind(i))

	# Double-tap the empty table to close, when there is something unsigned
	# left to close - see _render_details() for what turns this pad on.
	for i in range(_chair_pads.size()):
		(_chair_pads[i] as StaticBody3D).input_event.connect(_on_chair_pad_input.bind(i))

	_register_keyboard_actions()
	_log_open_size = _side_panel.size
	_log_toggle.pressed.connect(func(): set_log_folded(not _log_folded))
	# Mobile has no Ctrl+E: an invisible button laid over the tick counter
	# itself is the touch equivalent, wired to the exact same method.
	(%TickTapTarget as Button).pressed.connect(_debug_skip_shift)
	# Same trick over the standing counter - a manual playtesting convenience
	# so a run can survive long enough to fast-forward through several shifts
	# instead of ending the moment one bad walkout zeroes it out.
	(%StandingTapTarget as Button).pressed.connect(_debug_add_standing)
	_report_overlay.continue_pressed.connect(
		func(): shift_finished.emit(_shift.report()))
	_pull_picker.card_chosen.connect(func(i): _apply(_shift.choose_pull(i)))
	_pull_picker.cancel_pressed.connect(func(): _apply(_shift.cancel_pull()))

# --- input -----------------------------------------------------------------

## The number keys go by WHERE they are, not what they print. A browser reports
## Shift+1 as "!" - so a dig bound to "Shift + the 1 key's label" never fired on
## the web build - and on layouts like AZERTY the digits need Shift to begin
## with. The key's physical place is the same on every keyboard and with every
## modifier held.
func _register_keyboard_actions() -> void:
	var digits: Array[Key] = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6]
	for i in range(digits.size()):
		_bind_key(StringName("card_%d" % (i + 1)), digits[i], false, false, true)
		# Shift+number: dig that card, distinct from playing it.
		_bind_key(StringName("dig_%d" % (i + 1)), digits[i], true, false, true)
	_bind_key(&"chair_a", KEY_A)
	_bind_key(&"chair_b", KEY_B)
	_bind_key(&"chair_c", KEY_C)
	_bind_key(&"offer_key", KEY_O)
	_bind_key(&"drop_key", KEY_D)
	_bind_key(&"close_key", KEY_C, true)    # Shift+C, distinct from chair_c's bare C
	_bind_key(&"floor_key", KEY_F)          # step away from them / back (Shift.leave())
	_bind_key(&"debug_skip_shift", KEY_E, false, true)   # Ctrl+E: burn the clock

func _bind_key(action: StringName, keycode: Key, shift: bool = false,
		ctrl: bool = false, physical: bool = false) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	if not InputMap.action_get_events(action).is_empty():
		return
	var ev := InputEventKey.new()
	if physical:
		ev.physical_keycode = keycode
	else:
		ev.keycode = keycode
	ev.shift_pressed = shift
	ev.ctrl_pressed = ctrl
	InputMap.action_add_event(action, ev)

## Only ever reads the pointer moving - it consumes nothing, so every click and
## drag still reaches the table. See _hover_armed.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion \
			and (event as InputEventMouseMotion).relative.length_squared() > 4.0:
		_arm_hover()
		return
	var pressed_at = null
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		pressed_at = (event as InputEventMouseButton).position
	elif event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		pressed_at = (event as InputEventScreenTouch).position
	if pressed_at == null:
		return
	# A tap is a deliberate act at a place - as good as a move for hover.
	_arm_hover()
	# "Tapping away or anywhere else doesn't clear the hover. Only tapping on
	# the other customer flips them, and the one you most recently tapped gets
	# stuck. Mobile specifically." A peek is touch's hover, and a touchscreen
	# has no pointer to ever leave the folder - so a press anywhere but on the
	# peeked one is it looking away. A tap on another customer still peeks
	# them, in _on_pad_input(), which runs after this.
	if _peeked >= 0 and _pad_under(pressed_at) != _peeked:
		_peeked = -1
		_render_hover_flip()

func _unhandled_input(event: InputEvent) -> void:
	# Never handle mouse here: _unhandled_input runs BEFORE physics picking, so
	# consuming a click here takes it from every card on the table.
	if _shift == null or _shift.is_over():
		return
	# A pending pull locks every OTHER action, not just dragging - the
	# keyboard shortcuts below are a full parallel input path to the mouse,
	# and letting them through would let a keyboard player dig or offer
	# while a mouse player could not.
	if _shift.pending_pull != null:
		return
	if event.is_action_pressed("dig_6"): _try_dig(5)
	elif event.is_action_pressed("dig_5"): _try_dig(4)
	elif event.is_action_pressed("dig_1"): _try_dig(0)
	elif event.is_action_pressed("dig_2"): _try_dig(1)
	elif event.is_action_pressed("dig_3"): _try_dig(2)
	elif event.is_action_pressed("dig_4"): _try_dig(3)
	elif event.is_action_pressed("card_1"): _try_card(0)
	elif event.is_action_pressed("card_2"): _try_card(1)
	elif event.is_action_pressed("card_3"): _try_card(2)
	elif event.is_action_pressed("card_4"): _try_card(3)
	elif event.is_action_pressed("card_5"): _try_card(4)
	elif event.is_action_pressed("card_6"): _try_card(5)
	elif event.is_action_pressed("chair_a"): _apply(_shift.approach(0))
	elif event.is_action_pressed("chair_b"): _apply(_shift.approach(1))
	elif event.is_action_pressed("close_key"): _on_close()
	elif event.is_action_pressed("chair_c"): _apply(_shift.approach(2))
	elif event.is_action_pressed("offer_key"): _on_offer()
	elif event.is_action_pressed("drop_key"): _on_drop()
	# F steps away from the customer you are with - what "give us a minute"
	# asks for - or returns to whoever you were last with. Free either way, and
	# the view never changes: you stay at your seat, with your hand.
	elif event.is_action_pressed("floor_key"): _on_mode_pressed()
	elif event.is_action_pressed("debug_skip_shift"): _debug_skip_shift()

func _try_card(index: int) -> void:
	if index < _shift.hand.size():
		_apply(_shift.play_card(index))

func _try_dig(index: int) -> void:
	if index < _shift.hand.size():
		_apply(_shift.dig(index))

## Ctrl+E: burn the whole shift instantly - the same technique
## drive_run.gd's own _finish_the_shift() uses to reach the shop without
## playing it out. A manual testing convenience, not a mechanic: dig
## whatever is in hand (the cheapest always-legal command), and leave
## whoever you are with so an empty floor's own free wait() can carry the
## clock the rest of the way.
func _debug_skip_shift() -> void:
	var guard := 0
	while not _shift.is_over() and guard < 1000:
		guard += 1
		if not _shift.hand.is_empty():
			_apply(_shift.dig(0))
		elif _shift.at != null:
			_apply(_shift.leave())
		elif _shift.seated().is_empty():
			_apply(_shift.wait())
		else:
			break

## Mobile/manual tap target over the standing counter, wired the same way as
## the tick counter's own cheat above. A run over from one bad walkout can't
## be fast-forwarded through - this is what lets a playtest keep skipping
## shifts (Ctrl+E / TickTapTarget) instead of ending the run outright. Same
## clamp ChangeStanding uses, so this can never push standing above its own
## starting value or read negative.
func _debug_add_standing() -> void:
	_shift.standing = clampi(_shift.standing + 50, 0, _shift.cfg.standing_start)
	_render()

# --- lifecycle -------------------------------------------------------------

func setup(shift: Shift, standing_before: int,
		time_of_day: StringName = &"midday") -> void:
	## Play THIS shift. The run builds it - this file used to construct its own,
	## which made it the run orchestrator as well as the table, the framing, the
	## HUD and reconciliation.
	##
	## standing_before is what the RUN's standing was before this shift seeded
	## the Shift's own live copy (Shift.standing, which a walkout now docks
	## immediately - Shift still holds no RunState reference, it is just handed
	## the one number it needs to start counting from). Kept here too because
	## _show_report() needs the ORIGINAL value once the shift is over, by which
	## point Shift.standing has already moved.
	##
	## time_of_day is the picked ShiftProfile's id - see _time_of_day.
	_shift = shift
	_standing_before = standing_before
	_time_of_day = time_of_day
	_windows.show_time(time_of_day)
	_events_seen = 0
	_actions_seen = 0
	_player_lines_seen = 0
	_player_bubble.hush()
	_pending_says.clear()
	_seated_seen = []
	_held.clear()
	_clear_fx()
	_event_log.clear()
	_report_overlay.visible = false
	# The button that ends this shift must not promise "Continue" on the shift
	# that ends the run - pressing it silently restarts a fresh run underneath,
	# indistinguishable to the player from the deck-persistence bug this whole
	# milestone exists to prevent.
	_report_overlay.set_button_text("FINISH THE RUN"
		if _shift.shift_number >= _shift.cfg.shifts_in_run else "Continue")
	_hovered = -1
	_peeked = -1
	_hover_held = -1
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

## The deck viewer is a RunController-level overlay, but the shift log and
## the top bar live in the HUD's own CanvasLayer - drawn according to THEIR
## layer, not tree order, so the deck viewer being visually "in front" does
## nothing to them on its own. RunController calls this whenever the
## deck viewer opens or closes (see its own _deck_viewer.visibility_changed
## wiring), regardless of which of the three ways it was opened.
func set_hud_dimmed(dimmed: bool) -> void:
	_hud_dimmed = dimmed
	_side_panel.visible = not dimmed
	_waiting_panel.visible = not dimmed
	# The shift's manila strip is opaque now, where its bare numbers used to
	# float over whatever was beneath them - over the deck viewer it would be a
	# folder lying across the top of someone else's screen.
	(%TopStrip as Control).visible = not dimmed
	(%TopBar as Control).visible = not dimmed
	_render()

## "Make the shift log collapsible." Folded, it is its heading row and the
## button to open it again - the rest of the rail is the table's. Everything
## logged while it is folded is there when it opens.
func set_log_folded(folded: bool) -> void:
	_log_folded = folded
	_event_log.visible = not folded
	(_side_panel.get_node(^"Column/TitleRule") as Control).visible = not folded
	_log_toggle.text = "SHOW" if folded else "HIDE"
	# A panel keeps whatever size it was given when what is in it hides.
	# Asked for no height at all, it takes the least its heading needs.
	_side_panel.size = Vector2(_log_open_size.x, 0.0) if folded else _log_open_size

func log_folded() -> bool:
	return _log_folded

func _all_zones() -> Array:
	var out := _chair_zones.duplicate()
	out.append_array([_hand_zone, _draw_zone, _discard_zone])
	return out

# --- for the tutorial coach ------------------------------------------------
# The coach (tutorial_coach.gd) teaches by WATCHING, not by being wired into
# every command: it reads the model to see what you did, and asks this where
# things are to point at them. These are the only doors it uses, and none of
# them changes anything but refresh().

func current_shift() -> Shift:
	return _shift

## Re-render after something outside the view changed the model - the coach
## moving the practice customer's Line, say.
func refresh() -> void:
	if _shift != null:
		_render()

func customer_showing_back(chair: int) -> bool:
	return chair >= 0 and chair < _customer_flips.size() \
		and _customer_flips[chair].showing_back()

func hud_dimmed() -> bool:
	return _hud_dimmed

## Where a named thing is on screen right now, in the 1920x1080 design space,
## clipped to the screen - or an empty Rect2 when it is not showing at all.
func screen_rect_of(target: StringName) -> Rect2:
	if _shift == null:
		return Rect2()
	var front: int = _front()
	var card := CardFace3D.CARD_SIZE
	match target:
		&"customer":
			return _on_screen_rect(_card_rect(_customer_cards[front],
				CustomerCard3D.CARD_SIZE))
		&"table":
			if not _chair_zones[front].visible:
				return Rect2()
			return _on_screen_rect(_card_rect(_chair_zones[front], card))
		&"tablet", &"appeal":
			# The whole tablet, or just its appeal panel - the meter the
			# practice shift teaches you to read.
			var tablet: OfferTablet = _tablets[front]
			if not tablet.is_on():
				return Rect2()
			if target == &"tablet":
				return _on_screen_rect(_card_rect(tablet, OfferTablet.SIZE))
			return _on_screen_rect(_rect_at(
				tablet.to_global(OfferTablet.centre_of(OfferTablet.APPEAL_RECT)),
				OfferTablet.size_of(OfferTablet.APPEAL_RECT)))
		&"hand":
			var r := Rect2()
			for c in _hand_zone.cards:
				var one := _card_rect(c, card)
				r = one if r.size == Vector2.ZERO else r.merge(one)
			return _on_screen_rect(r)
		&"discard":
			return _on_screen_rect(_card_rect(_discard_zone, card))
		&"clock":
			return _tick_label.get_global_rect()
	return Rect2()

## A card-shaped thing's rect on screen, measured along the camera's own axes -
## every card faces the lens square-on, so this is its exact outline.
func _card_rect(node: Node3D, size: Vector2) -> Rect2:
	return _rect_at(node.global_position, size)

## The same, for a card-shaped patch centred anywhere - a panel on the tablet.
func _rect_at(centre: Vector3, size: Vector2) -> Rect2:
	var right := _camera.global_basis.x * size.x * 0.5
	var up := _camera.global_basis.y * size.y * 0.5
	var tl := _camera.unproject_position(centre - right + up)
	var br := _camera.unproject_position(centre + right - up)
	return Rect2(tl, br - tl)

func _on_screen_rect(r: Rect2) -> Rect2:
	return r.intersection(get_viewport().get_visible_rect())

# --- commands --------------------------------------------------------------

func _on_chair_pressed(chair_index: int) -> void:
	_apply(_shift.approach(chair_index))

func _on_offer() -> void:
	var here = _shift.at
	var res := _shift.offer()
	# "The chat bubble on the customer whose table you're at should also go
	# away if you offer them a product." Whatever they were saying before you
	# asked has been answered: it clears, and whatever the offer itself made
	# them say - taking the product, most often - is what _drain_log() puts up
	# in its place.
	if res.ok and here != null:
		_customer_cards[int(here)].hush()
	_apply(res)

func _on_close() -> void:
	_apply(_shift.close())

func _on_drop() -> void:
	_apply(_shift.drop_offer())

## The F key's two jobs. With someone: step away (Shift.leave()). Stepped away
## with someone to go back to: return to them, free - leave()/approach() are
## both free on the model side, this just decides which the key means now.
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
		_event_log.append_text("[color=%s]%s[/color]\n" % [Palette.hex(&"alert"), res.msg])
	_let_time_pass_on_an_empty_floor()
	_render()
	if _shift.is_over():
		_show_report()

## An empty floor is not a decision, it is a wait, so it is not something to make
## the player press a button for. It is also the one state the view cannot get
## itself out of: your hand is stowed off screen while you are on the floor, and
## everything else that moves the clock needs a customer to move it on.
##
## Loops because a wait only runs to the next arrival, and that can be the
## closing bell rather than a customer. The guard is not
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
##
## On a mouse, hovering already peeked the seat before the click ever arrives -
## so _hovered is already true and this approaches on the first click, exactly
## as it always has. Touch has no REAL hover, but confirmed on an actual
## device: Godot's touch-emulates-mouse layer fires mouse_entered on the touch
## itself, essentially simultaneously with the press - so _hovered reads true
## on the very first tap too, and trusting it there skipped the peek entirely.
## No per-event way to tell a real hover from an emulated one apart, so this
## asks the platform once instead: a touchscreen NEVER consults _hovered here,
## only its own explicit _peeked, which only a PRIOR discrete tap can set.
func _on_pad_input(_cam: Node, event: InputEvent, _pos: Vector3, _normal: Vector3,
		_shape: int, chair: int) -> void:
	if not (event is InputEventMouseButton):
		return
	var click := event as InputEventMouseButton
	if click.button_index != MOUSE_BUTTON_LEFT or not click.pressed:
		return
	if _shift == null or _shift.at == chair:
		return
	# A desk this shift has no chair for (the practice shift has one) is
	# scenery: nothing to peek at, and "No such chair." is not worth a log line.
	if chair >= _shift.chairs.size():
		return
	var already_seen := chair == _peeked if _touch_check.call() \
		else (chair == _hovered or chair == _peeked)
	if already_seen:
		_peeked = -1
		_on_chair_pressed(chair)
	else:
		_peeked = chair
		_render_hover_flip()

## A real mouse's double_click flag is trustworthy, but a touch-emulated click
## never sets it on an actual device - confirmed broken on a real phone, so
## touch gets its own explicit two-taps-within-a-window tracker instead. The
## pad itself is only ever enabled when close() could actually succeed (see
## _render_details()), but this still re-checks rather than trust that - a
## stale enabled pad from a race with a command applied elsewhere must never
## fire close() on a table that no longer qualifies.
func _on_chair_pad_input(_cam: Node, event: InputEvent, _pos: Vector3, _normal: Vector3,
		_shape: int, chair: int) -> void:
	if not (event is InputEventMouseButton):
		return
	var click := event as InputEventMouseButton
	if click.button_index != MOUSE_BUTTON_LEFT or not click.pressed:
		return

	var is_double: bool
	if _touch_check.call():
		var now := Time.get_ticks_msec() / 1000.0
		is_double = _last_chair_tap_chair == chair \
			and (now - _last_chair_tap_time) <= CHAIR_DOUBLE_TAP_WINDOW
		if is_double:
			_last_chair_tap_chair = -1
		else:
			_last_chair_tap_chair = chair
			_last_chair_tap_time = now
	else:
		is_double = click.double_click
	if not is_double:
		return

	if _shift == null or _shift.at == null or int(_shift.at) != chair:
		return
	var c = _shift.chairs[chair]
	if c == null or c.offer != null or c.unsigned.is_empty():
		return
	_on_close()

## Touch's stand-in for the hand's hover-lift: DragController's own
## _drag_card_start() already un-lifts and takes over positioning once a real
## drag begins, and "it follows you" from there is already exactly what
## dragging does - this only has to cover the moment BEFORE that, where a bare
## press should show what hovering already would.
func _on_hand_card_pressed(card: Card3D) -> void:
	card.set_hovered()

## Fires on every release, whether it ended a real drag (already un-lifted by
## DragController the moment it crossed the drag threshold) or was a tap that
## never moved. Safe either way - remove_hovered() on an already-resting card
## is a harmless repeat tween to the position it is already at.
func _on_hand_card_released(card: Card3D) -> void:
	card.remove_hovered()

func _on_customer_hover(chair: int) -> void:
	_hovered = chair
	# Reaching a customer while carrying a card is delivering it, not looking
	# at them - see _hover_held.
	if _dragging != null:
		_hover_held = chair
	# A real look at a customer means you have heard what they just said, so
	# it gets out of the way - whichever desk they are at. Left alone, it keeps
	# the time SpeechBubble gives it: short at yours, longer at the others.
	elif _hover_held != chair:
		_customer_cards[chair].hush()
	_render_hover_flip()

## A pad's mouse_entered is not proof anybody is looking. Physics picking fires
## it whenever a pad ends up under the cursor - the carousel turning one under a
## mouse that never moved, a customer sitting down in the chair it was resting
## over - and every one of those turned a folder over that nobody had pointed
## at. So it only counts once the pointer has really moved since the last such
## change (_hover_armed); until then it waits in _entered_unarmed for the first
## move to confirm it.
func _on_pad_entered(chair: int) -> void:
	if _hover_armed:
		_on_customer_hover(chair)
	else:
		_entered_unarmed = chair

## The table moved under the pointer: what it is over now has not been looked
## at yet. Whatever it was hovering waits for a real move to count again.
func _disarm_hover() -> void:
	_hover_armed = false
	if _hovered >= 0:
		_entered_unarmed = _hovered
		_hovered = -1
		_render_hover_flip()

func _arm_hover() -> void:
	if _hover_armed:
		return
	_hover_armed = true
	var waiting := _entered_unarmed
	_entered_unarmed = -1
	# Still over it after moving: that one is a real look.
	if waiting >= 0 and _pad_under(_pointer_at()) == waiting:
		_on_customer_hover(waiting)

func _on_customer_unhover(chair: int) -> void:
	if _entered_unarmed == chair:
		_entered_unarmed = -1
	if _hovered == chair:
		_hovered = -1
	# Leaving is what makes the next arrival a real look.
	if _hover_held == chair:
		_hover_held = -1
	_render_hover_flip()

## Which customer's pad is under screen point `p`, or -1. Asked of the geometry
## rather than of physics picking, because the one moment it is needed - a drag
## has just ended - is exactly when picking is between answers: the drop zones
## that walled the pads off during the drag were only just switched off, and
## the pad under the pointer has not been told it is there yet. It will be, a
## frame later, and _hover_held is what that frame finds waiting for it.
func _pad_under(p: Vector2) -> int:
	var from := _camera.project_ray_origin(p)
	var dir := _camera.project_ray_normal(p)
	var half := CustomerCard3D.CARD_SIZE * 0.5
	for i in range(_hover_pads.size()):
		var t: Transform3D = (_hover_pads[i] as Node3D).global_transform
		var hit = Plane(t.basis.z.normalized(), t.origin).intersects_ray(from, dir)
		if hit == null:
			continue
		var local: Vector3 = t.affine_inverse() * (hit as Vector3)
		if absf(local.x) <= half.x and absf(local.y) <= half.y:
			return i
	return -1

func _pointer_at() -> Vector2:
	return _pointer.call() if _pointer.is_valid() else get_viewport().get_mouse_position()

## A customer card carries only identity on its front, so what they DO lives
## on its BACK: hovering turns the pair over. This replaced a HUD tooltip
## panel, which had to be positioned somewhere it did not collide with
## anything, and which - being a Control over a 3D table - is one wrong
## mouse_filter away from swallowing the very hover that summoned it.
##
## Works at a SEAT now too, not just on the floor. It used to be suppressed
## there on the assumption the customer's own detail card was already out
## beside them - true back when sitting down slid it out, false since the
## interest grid moved that content onto the FRONT of the card instead and the
## seat stopped sliding it out at all. The back is the only place their
## archetype's tells still live, and there was no reason left to keep it out
## of reach just because you sat down.
func _render_hover_flip() -> void:
	var usable: bool = _shift != null and not _report_overlay.visible
	# A stale peek left pointing at a chair that emptied out from under it must
	# not silently haunt whoever sits down there next - cleared here rather than
	# wherever a chair empties, so every path that could vacate one (walking off,
	# closing, a walk-up timer) is covered by the one place that already runs
	# on every render.
	if _peeked >= 0 and (_shift == null or _peeked >= _shift.chairs.size() \
			or _shift.chairs[_peeked] == null):
		_peeked = -1
	for i in range(_customer_flips.size()):
		# See _render()'s identical guard: a ShiftProfile may run with fewer
		# chairs than the carousel was built for.
		var chair_here: bool = _shift != null and i < _shift.chairs.size() \
			and _shift.chairs[i] != null
		var looking: bool = (i == _hovered and i != _hover_held) or i == _peeked
		_customer_flips[i].show_back(usable and looking and chair_here)

# --- framing ---------------------------------------------------------------

## Move between the wide floor shot and one seat, and raise or stow the things
## that belong to you. The two modes have to LOOK different or nothing tells you
## which one you are in.
## Which way the carousel must be turned to put seat `i` at the front. Seat i
## sits at carousel angle 120*i, so this is simply its negative - and with it
## applied, seat (i+1)%3 is always on the RIGHT and (i+2)%3 always on the LEFT.
static func station_for(chair: int) -> float:
	return deg_to_rad(-120.0 * chair)

func _apply_framing() -> void:
	if _framed_at == _shift.at:
		return
	_framed_at = _shift.at
	# A hover or peek belongs to whichever pad the pointer was actually sitting
	# on a moment ago - and approaching is a CLICK on that same pad, so the
	# pointer has not moved an inch by the time you arrive. Carried through
	# uncleared, it would flip the card you just got to (or just left) on the
	# very next render, simply because the mouse never left it - hiding the
	# identity card exactly when arriving is supposed to show it. Cleared here,
	# once, on every real transition, rather than at each of the several places
	# that can cause one.
	_hovered = -1
	_peeked = -1
	_hover_held = -1
	# The carousel is about to turn pads under a pointer that has not moved.
	_hover_armed = false
	_entered_unarmed = -1
	var seated: bool = _shift.at != null
	# THERE IS NO FLOOR VIEW. Between customers - one just signed or walked, or
	# you stood up - the camera stays where it was, at the seat you last had,
	# and your hand, draw and discard stay up. Moving to the next customer is
	# only the carousel turning, never the camera pulling out and back in, and
	# the hand is never put away: it is what you dig with while the floor
	# refills. Whoever you last dealt with stays at the front.
	var target: Node3D = _seat_cam
	var station := station_for(int(_shift.at) if seated else _last_station)
	if seated:
		_last_station = int(_shift.at)

	# NOBODY IS HIDDEN ANY MORE. The carousel turns instead, so the two you are
	# not with fall away to either side - smaller because they are further off,
	# not because anything scaled them. What still belongs only to the seat you
	# are at is the NEGOTIATION: the product slot and what is sitting in it. The
	# tablet it stands on follows the same rule, in _render_details().
	for i in range(_seats.size()):
		var here: bool = i == _front()
		_show_seat(i, true)
		_chair_zones[i].visible = here
		_customer_zones[i].visible = here

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
	_framing_tween.tween_property(_carousel, "rotation:y", station, FRAMING_TWEEN)
	# Each seat cancels the turn so its cards keep facing the camera. It has to
	# be per-seat: a single counter-rotating node above them would undo their
	# positions along with their facing.
	for seat in _seats:
		_framing_tween.tween_property(seat, "rotation:y", -station, FRAMING_TWEEN)

	# Camera-LOCAL, so this is purely "up into view" - the piles are already
	# travelling with the camera for free. They start the shift stowed and rise
	# a beat after the camera settles; from then on they stay up.
	_tween_pile(_hand_zone, HAND_UP, PILE_DELAY)
	_tween_pile(_discard_zone, DISCARD_UP, PILE_DELAY)
	_tween_pile(_draw_zone, DRAW_UP, PILE_DELAY)

## The seat in front: the one you are at, or - if you stepped away on purpose -
## the one you last had. Your iPad, product slot and hand always belong to it.
func _front() -> int:
	return int(_shift.at) if _shift.at != null else _last_station

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
## The slots you are not at still must not take drops, so they are re-disabled
## HERE instead: DragController emits drag_started after enabling them all, so
## this runs late enough to win, and its own _stop_drag() disables everything
## again. Keyed on the SLOT's own visibility rather than the seat's, because
## since the carousel arrived every seat is visible and only the one you are at
## has a product slot showing.
func _refuse_drops_on_slots_you_are_not_at() -> void:
	for i in range(_chair_zones.size()):
		if not _chair_zones[i].visible:
			_chair_zones[i].disable_drop_zone()
	for i in range(_customer_zones.size()):
		if not _customer_zones[i].visible:
			_customer_zones[i].disable_drop_zone()

func _tween_pile(zone: Node3D, to: Vector3, delay: float) -> void:
	_framing_tween.tween_property(zone, "position", to, PILE_TWEEN).set_delay(delay)

# --- closing and walkouts, out loud -----------------------------------------
# "There needs to be some pizzaz around closing a deal. Maybe make the amount
# banked float up towards the banked part of the screen and the numbers roll up
# to the new total. Same for walkouts." Read off who left which chair since the
# last render, and how - Customer.state says signed or walked - so it plays the
# same whichever command, tick or timer caused it.

const FX_FLY := 0.9        ## seconds for an amount to fly to the top bar
const FX_ROLL := 0.6       ## seconds for the number there to roll to its total
const FX_STAMP := 1.6      ## seconds a WALKED OUT / SIGNED stamp stays up

## What the top bar is SHOWING, which trails the model while an amount is
## still on its way up to it.
var _banked_shown: int = 0
var _standing_shown: int = 0
var _banked_rolling := false
var _standing_rolling := false
## Every floating label and stamp still playing, and their tweens - cleared
## with the shift, and stepped through by drive_shift.gd.
var _fx: Array = []
var _fx_tweens: Array = []

func _write_banked(v: int) -> void:
	_banked_shown = v
	_banked_label.text = "banked %s / %s" % [Format.money(v), Format.money(_shift.quota)]

## The boss's product quota beside what you have banked: "Vehicle 1/2", amber
## until it is met and green after. Hidden on a shift without one.
func _write_product_quota() -> void:
	var need: int = _shift.category_quota_count
	_product_quota_label.visible = need > 0
	if need <= 0:
		return
	var sold: int = _shift.category_sold
	# Agreed but not signed yet: shown, because the player has sold it - but it
	# only counts once they sign, so the count itself stays what is signed.
	var pending: int = _shift.category_unsigned()
	_product_quota_label.text = "%s %d/%d%s" % [_shift.category_quota_name,
		mini(sold, need), need, "  (+%d unsigned)" % pending if pending > 0 and sold < need else ""]
	_product_quota_label.add_theme_color_override("font_color",
		Palette.color(&"patience_ok" if sold >= need else &"patience_warn"))

func _write_standing(v: int) -> void:
	_standing_shown = v
	_standing_label.text = "standing %d/%d" % [v, _shift.cfg.standing_start]

func _notice_departures() -> void:
	var n := mini(_shift.chairs.size(), _seated_seen.size())
	for i in range(n):
		var was = _seated_seen[i]
		if was == null or was == _shift.chairs[i]:
			continue
		if was.state == "signed":
			_celebrate_close(i, was.unsigned_margin())
		elif was.state == "walked":
			_mourn_walkout(i, was.unsigned_margin())
		else:
			continue
		# "Wait to show the new customer who appears in the chair until the
		# 'signed' or 'walk out' sign has disappeared."
		_held[i] = {"who": was, "until": Time.get_ticks_msec() + int(HOLD_SECONDS * 1000.0)}

## How long a chair keeps showing who just left it - the stamp's whole life.
const HOLD_SECONDS := FX_STAMP + 0.7
## chair -> {who, until}: a chair still showing whoever just signed or walked.
var _held: Dictionary = {}

## Who the chair's folder shows: whoever just left it while their stamp is up,
## otherwise whoever is in it.
func _shown_in(chair: int):
	if _held.has(chair):
		return _held[chair]["who"]
	return _shift.chairs[chair] if chair < _shift.chairs.size() else null

## Lets every chair whose stamp has finished show who is really in it - all of
## them with `now`, for a driver with no time to wait.
func _release_holds(now: bool = false) -> void:
	if _held.is_empty() or _shift == null:
		return
	var clock := Time.get_ticks_msec()
	var done := false
	for chair in _held.keys():
		if now or clock >= int(_held[chair]["until"]):
			_held.erase(chair)
			done = true
	if done:
		_render()

func _chair_on_screen(chair: int) -> Vector2:
	return _card_rect(_customer_cards[chair], CustomerCard3D.CARD_SIZE).get_center()

## A big outlined label on the HUD, centred on `at`.
func _fx_label(text: String, role: StringName, size: int, at: Vector2) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.theme_type_variation = &"Heading"
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Palette.color(role))
	l.add_theme_color_override("font_outline_color", Palette.color(&"paper"))
	l.add_theme_constant_override("outline_size", maxi(6, size / 6))
	_hud.add_child(l)
	l.size = l.get_combined_minimum_size()
	l.pivot_offset = l.size * 0.5
	l.position = at - l.size * 0.5
	_fx.append(l)
	return l

func _fx_tween() -> Tween:
	var tw := create_tween()
	_fx_tweens.append(tw)
	return tw

func _fx_done(node: Node) -> void:
	_fx.erase(node)
	if is_instance_valid(node):
		node.queue_free()

## Flies `text` from `from` to the middle of `target`, shrinking as it goes,
## then calls `landed`.
func _fly(text: String, role: StringName, from: Vector2, target: Control,
		landed: Callable) -> void:
	var l := _fx_label(text, role, 60, from)
	l.scale = Vector2(0.4, 0.4)
	var to := target.get_global_rect().get_center() - l.size * 0.5
	var tw := _fx_tween()
	tw.tween_property(l, "scale", Vector2(1.25, 1.25), 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.25)
	tw.set_parallel(true)
	tw.tween_property(l, "position", to, FX_FLY) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(l, "scale", Vector2(0.55, 0.55), FX_FLY) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.set_parallel(false)
	tw.tween_callback(func():
		_fx_done(l)
		landed.call())

## Keeps every stamp on its folder while the camera moves - closing sends you
## back to the floor, and a stamp left where the folder WAS floats off it.
func _follow_stamps() -> void:
	for n in _fx:
		# Over the floor, never over what is laid on top of it - the toolkit,
		# the calendar, the report.
		if is_instance_valid(n):
			(n as CanvasItem).visible = not _hud_dimmed and not _report_overlay.visible
		if is_instance_valid(n) and (n as Node).has_meta(&"chair"):
			var l := n as Label
			l.position = _chair_on_screen(int(l.get_meta(&"chair"))) - l.size * 0.5

## A stamp slapped onto a customer's folder, then faded out.
func _stamp(text: String, role: StringName, chair: int, tilt: float) -> void:
	var l := _fx_label(text, role, 64, _chair_on_screen(chair))
	l.set_meta(&"chair", chair)
	l.rotation_degrees = tilt
	l.scale = Vector2(2.2, 2.2)
	l.modulate.a = 0.0
	var tw := _fx_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "scale", Vector2.ONE, 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 1.0, 0.12)
	tw.set_parallel(false)
	tw.tween_interval(FX_STAMP)
	tw.tween_property(l, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func(): _fx_done(l))

## Rolls a top-bar number from what it shows to what the model says, then
## pulses the label in `role`'s colour - `shake` for a loss.
func _roll(label: Control, from: int, writer: Callable, done: Callable, role: StringName,
		shake: bool) -> void:
	var to: int = _shift.margin_banked if label == _banked_label else _shift.standing
	var tw := _fx_tween()
	tw.tween_method(func(v: float): writer.call(roundi(v)), float(from), float(to), FX_ROLL) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		done.call()
		writer.call(to))
	label.pivot_offset = label.size * 0.5
	label.add_theme_color_override("font_color", Palette.color(role))
	var pulse := _fx_tween()
	pulse.tween_property(label, "scale", Vector2(1.25, 1.25), 0.15)
	if shake:
		var x := label.position.x
		for k in range(4):
			pulse.tween_property(label, "position:x", x + (8.0 if k % 2 == 0 else -8.0), 0.05)
		pulse.tween_property(label, "position:x", x, 0.05)
	pulse.tween_property(label, "scale", Vector2.ONE, 0.45)
	pulse.tween_callback(func(): label.remove_theme_color_override("font_color"))

func _celebrate_close(chair: int, amount: int) -> void:
	var at := _chair_on_screen(chair)
	_stamp("SIGNED", &"margin", chair, -8.0)
	if amount <= 0:
		return
	_banked_rolling = true
	var from := _banked_shown
	_fly("+" + Format.money(amount), &"margin", at + Vector2(0, 90), _banked_label, func():
		_roll(_banked_label, from, _write_banked,
			func(): _banked_rolling = false, &"margin", false))

func _mourn_walkout(chair: int, lost: int) -> void:
	var at := _chair_on_screen(chair)
	_stamp("WALKED OUT", &"alert", chair, 8.0)
	if lost > 0:
		# What they took with them: dropped, not banked.
		var gone := _fx_label("-%s unsigned" % Format.money(lost), &"alert", 40,
			at + Vector2(0, 70))
		var tw := _fx_tween()
		tw.tween_interval(0.3)
		tw.set_parallel(true)
		tw.tween_property(gone, "position:y", gone.position.y + 90.0, 1.4)
		tw.tween_property(gone, "modulate:a", 0.0, 1.4).set_ease(Tween.EASE_IN)
		tw.set_parallel(false)
		tw.tween_callback(func(): _fx_done(gone))
	var cost := mini(_shift.cfg.standing_cost_per_walkout, _standing_shown - _shift.standing)
	if cost <= 0:
		return
	_standing_rolling = true
	var from := _standing_shown
	_fly("-%d standing" % cost, &"alert", at, _standing_label, func():
		_roll(_standing_label, from, _write_standing,
			func(): _standing_rolling = false, &"alert", true))

## "When a customer does a thing, there needs to be a notification about it."
## Whatever an action or a demand of theirs did (Shift._fx_since(), the entry's
## "fx") happens on screen, the way a signing does: money they add or cost you
## flies to what is unsigned on the floor, standing flies to the standing
## counter and rolls, a product they sweep is stamped and pops on its way to
## the discard, and their patience or Line moving rises off their folder.
func _show_what_they_did(entry: Dictionary) -> void:
	var fx: Dictionary = entry.get("fx", {})
	if fx.is_empty():
		return
	var chair: int = Shift.CHAIR_KEYS.find(str(entry.get("key", "")))
	if chair < 0 or chair >= _customer_cards.size():
		return
	var at := _chair_on_screen(chair)
	var money := int(fx.get("margin", 0))
	if money != 0:
		var role: StringName = &"margin" if money > 0 else &"alert"
		_fly(("+" if money > 0 else "") + Format.money(money), role, at + Vector2(0, 90),
			_at_risk_label, func(): _pulse(_at_risk_label, role, money < 0))
	var standing := int(fx.get("standing", 0))
	if standing != 0:
		var role: StringName = &"margin" if standing > 0 else &"alert"
		_standing_rolling = true
		var from := _standing_shown
		_fly("%+d standing" % standing, role, at, _standing_label, func():
			_roll(_standing_label, from, _write_standing,
				func(): _standing_rolling = false, role, standing < 0))
	var swept := int(fx.get("swept", -1))
	if swept >= 0:
		_stamp("SWEPT OFF!", &"alert", chair, -6.0)
		var node: CardFace3D = _nodes.get(swept)
		if node != null:
			var tw := _fx_tween()
			tw.tween_property(node, "scale", Vector3.ONE * 1.35, 0.15) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(node, "scale", Vector3.ONE, 0.45)
	var notes: Array[String] = []
	var patience := int(fx.get("patience", 0))
	if patience != 0:
		notes.append("%+d patience" % patience)
	var line := int(fx.get("line", 0))
	if line != 0:
		notes.append("Line %+d" % line)
	if bool(entry.get("floor_wide", false)):
		notes.append("WHOLE FLOOR: " + ", ".join(entry.get("descriptions", [])))
	if not notes.is_empty():
		_rise("\n".join(notes), &"alert" if patience < 0 or line > 0 \
			or bool(entry.get("floor_wide", false)) else &"margin", chair)

## Text that rises off a customer's folder and fades - something that happened
## to them, said where it happened.
func _rise(text: String, role: StringName, chair: int) -> void:
	var l := _fx_label(text, role, 34, _chair_on_screen(chair) + Vector2(0, -40))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tw := _fx_tween()
	tw.tween_interval(0.2)
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 110.0, 1.8) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 1.8).set_ease(Tween.EASE_IN)
	tw.set_parallel(false)
	tw.tween_callback(func(): _fx_done(l))

## The landing of an amount on a label that is not rolled - what is unsigned on
## the floor is rewritten every render - just a pulse in its colour.
func _pulse(label: Control, role: StringName, shake: bool) -> void:
	label.pivot_offset = label.size * 0.5
	label.add_theme_color_override("font_color", Palette.color(role))
	var tw := _fx_tween()
	tw.tween_property(label, "scale", Vector2(1.25, 1.25), 0.15)
	if shake:
		var x := label.position.x
		for k in range(4):
			tw.tween_property(label, "position:x", x + (8.0 if k % 2 == 0 else -8.0), 0.05)
		tw.tween_property(label, "position:x", x, 0.05)
	tw.tween_property(label, "scale", Vector2.ONE, 0.45)
	tw.tween_callback(func(): label.remove_theme_color_override("font_color"))

## Ends every effect now - a new shift, or a driver with no time to watch.
func _clear_fx() -> void:
	for tw in _fx_tweens:
		if tw != null and tw.is_valid():
			tw.kill()
	_fx_tweens.clear()
	for n in _fx:
		if is_instance_valid(n):
			n.queue_free()
	_fx.clear()
	_banked_rolling = false
	_standing_rolling = false

# --- rendering -------------------------------------------------------------

func _render() -> void:
	_tick_label.text = "tick %d/%d" % [_shift.tick, _shift.tick_budget]
	# Before the numbers are written: a deal signed or a customer lost since
	# the last render holds its number at the old value while it plays out.
	_notice_departures()
	if not _banked_rolling:
		_write_banked(_shift.margin_banked)
	_write_product_quota()
	# LIVE now, not the setup()-time snapshot it used to be enough to be - a
	# walkout can move this mid-shift, and the whole point of costing standing
	# immediately is for the player to be able to see it happen.
	if not _standing_rolling:
		_write_standing(_shift.standing)
	var risk: int = _shift.margin_at_risk()
	_at_risk_label.text = "%s unsigned on the floor" % Format.money(risk) \
		if risk > 0 else "nothing unsigned"

	# The clock's own counterpart to a customer's patience going red: few
	# ticks left costs every unsigned deal on the floor, not just one chair,
	# so this fires off the whole shift's clock rather than anyone's patience.
	var low_on_time: bool = _shift.ticks_running_low()
	_tick_label.add_theme_color_override("font_color",
		Palette.color(&"alert") if low_on_time else Palette.color(&"text"))
	# A one-shot pulse right on the transition, not a standing effect - the
	# red text alone already carries the ongoing warning; this is what makes
	# the MOMENT it happens hard to miss even with your eyes elsewhere.
	if low_on_time and not _tick_warning_flashed:
		_tick_warning_flashed = true
		_flash_tick_label()
	elif not low_on_time:
		_tick_warning_flashed = false
	if low_on_time and risk > 0:
		_at_risk_label.add_theme_color_override("font_color", Palette.color(&"alert"))
	else:
		_at_risk_label.remove_theme_color_override("font_color")

	_apply_framing()
	# Someone new in a chair the pointer was resting on is not someone it is
	# looking at - see _on_pad_entered().
	var now_seated: Array = _shift.chairs.duplicate()
	if _hovered >= 0 and _hovered < now_seated.size() \
			and _hovered < _seated_seen.size() \
			and now_seated[_hovered] != _seated_seen[_hovered]:
		_disarm_hover()
	_seated_seen = now_seated

	for i in range(_customer_cards.size()):
		# Keyed on being FRONTED rather than on being seated: the carousel
		# draws the two flankers small on the floor as well, and that is where
		# rank numerals stop surviving the SubViewport's downscale.
		var front: int = _front()
		_customer_cards[i].compact = i != front
		# A ShiftProfile (night) may run this shift with fewer chairs than the
		# scene was built for - the same "no customer here" state
		# CustomerCard3D.setup(null) already renders for a chair mid-refill,
		# not a chair this shift never had at all.
		var chair = _shown_in(i)
		_customer_cards[i].setup(chair, i == front, _shift.tick)

	_render_details()
	_render_hover_flip()
	_render_pull_picker()
	_render_waiting()
	# Both piles are face down, so a count is the only way to see how much of
	# the deck is left to draw and how much has already been spent.
	(_draw_tag.get_node(^"Lines/Label") as Label).text = "DRAW  %d" % _shift.draw.size()
	(_discard_tag.get_node(^"Lines/Label") as Label).text = \
		"DISCARD  %d" % _shift.discard.size()
	# What you said lasts a tick. Your hand is always up now, so there is always
	# somewhere for it to talk from - it is only put away under an overlay.
	_player_bubble.update_visibility(_shift.tick, SpeechBubble.PLAYER_TICKS)
	if _hud_dimmed:
		_player_bubble.hush()
	_reconcile()
	_drain_log()
	_place_tags()

## "Shows what customers are lined up so you know who's coming. If none are
## queued it would tell you how many ticks until someone is ready." Whether to
## keep working someone difficult or get them signed and out can turn on who
## is waiting to take their chair.
func _render_waiting() -> void:
	if _shift.waiting != _waiting_shown:
		_waiting_shown = _shift.waiting.duplicate()
		for row in _waiting_rows.get_children():
			if row != _waiting_row:
				_waiting_rows.remove_child(row)
				row.queue_free()
		for i in range(_waiting_shown.size()):
			_waiting_rows.add_child(_waiting_row_for(i, _waiting_shown[i]))
	var nobody := _shift.waiting.is_empty()
	_waiting_rows.visible = not nobody
	_next_arrival.visible = nobody
	if nobody:
		var n := _shift.next_arrival_in()
		_next_arrival.text = "Nobody waiting.\n" + ("Next customer in %d tick%s." \
			% [n, "" if n == 1 else "s"] if n >= 0 else "Nobody else is due before close.")
	# A panel keeps whatever size it was given when what is in it shrinks.
	# Asked for no height at all, it takes the least its rows need.
	_waiting_panel.size = Vector2(_waiting_panel.size.x, 0.0)

## One waiting customer's row: their place in the queue and their archetype,
## the first of them marked as next.
func _waiting_row_for(place: int, arch: CustomerArchetype) -> Control:
	var row := _waiting_row.duplicate() as Control
	row.unique_name_in_owner = false
	row.visible = true
	(row.get_node(^"Badge/Place") as Label).text = str(place + 1)
	(row.get_node(^"Archetype") as Label).text = arch.display_name
	(row.get_node(^"NextTag") as Control).visible = place == 0
	if place == 0:
		var badge := row.get_node(^"Badge") as PanelContainer
		var dot := badge.get_theme_stylebox(&"panel").duplicate() as StyleBoxFlat
		dot.bg_color = Palette.color(&"primary")
		badge.add_theme_stylebox_override(&"panel", dot)
	return row

## Every frame as well as on render: the carousel turns and the piles rise on
## tweens between renders, and a tag has to ride along with its card rather
## than jump to where the card will end up.
func _process(_delta: float) -> void:
	_place_tags()
	_release_pending_says()
	_follow_stamps()
	_release_holds()

func _place_tags() -> void:
	# The report and the deck viewer each cover the table, so its hints go with
	# it rather than floating over the top of either.
	_hint_layer.visible = _shift != null and not _hud_dimmed \
		and not _report_overlay.visible
	if not _hint_layer.visible:
		return
	for tag in _tags:
		tag.follow(_camera)

## The picker and the drag lock rise and fall together - both exist only to
## enforce "resolve this before anything else," so one flag (pending_pull)
## drives both rather than two separately-tracked bits of state that could
## drift out of sync with each other.
func _render_pull_picker() -> void:
	var pending: PendingPull = _shift.pending_pull
	_drag.card_drag_threshold = _LOCKED_DRAG_THRESHOLD if pending != null \
		else _normal_drag_threshold
	if pending != null:
		_pull_picker.show_pull(pending)
	else:
		_pull_picker.hide_pull()

## Grows the tick counter and settles it back over about a second - a Control,
## so this scales the Label itself.
func _flash_tick_label() -> void:
	_tick_label.pivot_offset = _tick_label.size / 2.0
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(_tick_label, "scale", Vector2(1.6, 1.6), 0.15) \
		.set_ease(Tween.EASE_OUT)
	tw.tween_property(_tick_label, "scale", Vector2.ONE, 0.65) \
		.set_ease(Tween.EASE_IN_OUT).set_delay(0.1)

## Everything at a desk that is not a card: the folder's back, the tablet, the
## empty table's note and its double-click-to-close, and CLOSE SOON.
##
## All three desks are refreshed, not just the one you are with. Two of them
## are hidden or occluded so it costs nothing worth counting, and it means
## nothing can come into view carrying what was true the last time you sat
## down.
func _render_details() -> void:
	var low_on_time: bool = _shift.ticks_running_low()
	for i in range(_seats.size()):
		# See _render()'s identical guard: a shift may run with fewer chairs
		# than the carousel was built for - the practice shift has one - and a
		# seat past the end is simply nobody.
		var c: Customer = _shown_in(i)
		_customer_details[i].show_customer(c)
		var at_this_seat: bool = i == _front()

		# The tablet is where you play a product, so it is on at the desk you
		# are sitting at and nowhere else - like the slot standing on it.
		# band_for lives on Shift, so the thresholds that decide the meter's
		# colour have exactly one definition, in the model.
		var band := ""
		if c != null and c.offer != null:
			band = _shift.band_for(c.line - c.offer.appeal)
		_tablets[i].switch_on(at_this_seat)
		_tablets[i].show_offer(c, band, _shift.cfg.appeal_meter_scale)
		_tablets[i].show_clock(ShiftHours.clock(_time_of_day, _shift.tick,
			_shift.tick_budget))

		# Double-tap-to-close: only the seat you are AT, only an empty table,
		# only when there is something unsigned still to close - exactly
		# close()'s own refusal condition, so the gesture can never do
		# anything close() itself would refuse.
		var can_close_empty: bool = at_this_seat and c != null \
			and c.offer == null and not c.unsigned.is_empty()
		(_chair_pads[i].get_node(^"CollisionShape3D") as CollisionShape3D).disabled \
			= not can_close_empty
		_close_hints[i].visible = can_close_empty
		# The empty table's note, and its "or double-click to close" half on
		# exactly the same condition as the pad that does the closing.
		_table_notes[i].wanted = at_this_seat and c != null and c.offer == null
		_table_notes[i].get_node(^"Lines/CloseRow").visible = can_close_empty

		# CLOSE SOON is NOT scoped to the seat you are at: a customer you are
		# not with can still have something unsigned at risk when the clock
		# runs short, and every folder is on screen regardless of which one
		# you are at.
		_close_soon_tags[i].wanted = c != null and not c.unsigned.is_empty() \
			and low_on_time

func _drain_log() -> void:
	for line in _shift.events.slice(_events_seen):
		_event_log.append_text(line + "\n")
	_events_seen = _shift.events.size()
	# What you said yourself, playing a card: the newest of it, in your own
	# bubble - FIRST. "If the player speaks first, have it appear a little
	# before the response from the customer": whatever they say back in the
	# same breath waits REPLY_DELAY to answer it. Like theirs, it is not for
	# the log.
	var you_spoke := _shift.player_lines.size() > _player_lines_seen
	if you_spoke:
		_player_bubble.say(_shift.player_lines[-1], _shift.tick)
	_player_lines_seen = _shift.player_lines.size()
	for entry in _shift.action_log.slice(_actions_seen):
		# What a customer SAYS goes in a speech bubble over their own card, and
		# not in here: "remove customer dialogue lines from the shift log." The
		# log is what happened; the bubble is who said what, where they sit. A
		# demand said out loud still reads as a person interrupting you - it
		# just does it on their folder rather than in a column of text.
		var said: String = str(entry.get("dialogue", ""))
		if said != "":
			_say_on_the_card(str(entry["key"]), said, REPLY_DELAY if you_spoke else 0.0)
		# Chatter is words and nothing else - taking a product, running short of
		# patience (see Shift._chatter()) - so it leaves nothing here at all.
		if bool(entry.get("chatter", false)):
			continue
		_show_what_they_did(entry)
		var color := Palette.hex(&"alert") if entry["floor_wide"] else Palette.hex(&"action")
		_event_log.append_text("[color=%s]>> %s (%s): %s - %s[/color]\n"
			% [color, entry["customer"], entry["key"], entry["name"],
				", ".join(entry["descriptions"])])
	_actions_seen = _shift.action_log.size()

## "All customer actions need to show on the screen, not just in the log" - a
## speech bubble on the card that said it, which is now the only place it
## shows. Keyed on the chair LETTER the entry itself carries: dialogue is only
## ever recorded the instant it is spoken, before anything could have vacated
## that chair since, so the letter still names the right card.
##
## `delay` holds it back to answer you rather than talk over you. A held line
## remembers who said it, and is dropped if someone else has the chair by the
## time it is due.
func _say_on_the_card(key: String, text: String, delay: float = 0.0) -> void:
	var chair: int = Shift.CHAIR_KEYS.find(key)
	if chair < 0 or chair >= _customer_cards.size():
		return
	if delay <= 0.0:
		_customer_cards[chair].say(text, _shift.tick)
		return
	_pending_says.append({"chair": chair, "text": text, "tick": _shift.tick,
		"who": _shift.chairs[chair] if chair < _shift.chairs.size() else null,
		"due": Time.get_ticks_msec() + int(delay * 1000.0)})

## Says every held line that is due - all of them with `now`, for a driver that
## has no time to wait.
func _release_pending_says(now: bool = false) -> void:
	if _pending_says.is_empty() or _shift == null:
		return
	var clock := Time.get_ticks_msec()
	var still: Array = []
	for p in _pending_says:
		if not now and clock < int(p["due"]):
			still.append(p)
			continue
		var chair: int = p["chair"]
		if chair < _shift.chairs.size() and _shift.chairs[chair] == p["who"]:
			_customer_cards[chair].say(p["text"], p["tick"])
	_pending_says = still

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
	_hovered = -1
	_peeked = -1
	_hover_held = -1
	_render_hover_flip()
	# The camera stays where it is - the overlay covers it - but the table itself
	# must not be left mid-negotiation underneath, with two thirds of the floor
	# hidden over a shift that is finished.
	for i in range(_seats.size()):
		_show_seat(i, true)

# --- dragging --------------------------------------------------------------

## The dragged card IS the current customer's own offer, sitting on their
## table already - as opposed to a hand card being played for the first time.
func _is_current_offer(card: CardFace3D) -> bool:
	if _shift == null or _shift.at == null:
		return false
	var c = _shift.chairs[int(_shift.at)]
	return c != null and c.offer != null and c.offer.instance.uid == card.uid

func _on_drag_started(card) -> void:
	_dragging = card as CardFace3D
	_refuse_drops_on_slots_you_are_not_at()
	if _is_current_offer(_dragging):
		_offer_drag_hints[int(_shift.at)].visible = true
		_drop_drag_hint.visible = true
		# DROP PRODUCT stands in for the permanent DISCARD tag, not alongside
		# it - both naming the same zone at once read as one message stepping
		# on the other. Hiding the anchor is what hides the tag.
		(_discard_zone.get_node(^"TagAnchor") as Node3D).visible = false
		_place_tags()
	# DragController's own _drag_card_start() just called remove_hovered() on
	# this card - its ROOT now tracks the pointer directly ("set card position
	# to under mouse"), on the assumption no local offset is needed once a drag
	# begins. Correct for a mouse: the cursor never occluded anything, so the
	# card should shrink back to normal size and track the pointer exactly,
	# with nothing hiding where it will actually land. Wrong for a fingertip,
	# which sits on the card's own center for the WHOLE drag unless something
	# keeps it clear - confirmed on a real device.
	#
	# So this reapplies the SAME hover state, but for touch only. Reapplying it
	# for a mouse too was tried and was wrong the other way: the card grew AND
	# stayed lifted for the whole drag, visibly detached from the drop-plane
	# position DragController was actually tracking underneath it - confirmed
	# on a real desktop. hover_pos_move is a local offset on the mesh relative
	# to whatever the root is doing, so on touch it composes correctly with the
	# root tracking the pointer and with the card's own drag rotation; on mouse
	# it has no business being there at all.
	# Hand only: nothing else is meant to be read while it is being dragged.
	# _on_hand_card_released already calls remove_hovered() on every release,
	# drag or not, so this needs no matching cleanup of its own.
	if _touch_check.call() and _hand_zone.cards.has(_dragging):
		_dragging.set_hovered()

func _on_drag_stopped(_card) -> void:
	_dragging = null
	for hint in _offer_drag_hints:
		hint.visible = false
	_drop_drag_hint.visible = false
	(_discard_zone.get_node(^"TagAnchor") as Node3D).visible = true
	# Letting go over a customer - offering them the product, most often - is
	# not looking at them. Whoever is under the pointer now stays face-front
	# until the pointer leaves them and comes back. A pad the pointer reached
	# during the drag already said so; otherwise the drop zones walled the pads
	# off, and the geometry has to say which one the pointer is over.
	_hover_held = _hovered if _hovered >= 0 else _pad_under(_pointer_at())
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

	# The offer already on the table, not a hand card being played for the
	# first time - bypass DropRouter entirely (it only knows hand cards) and
	# call the exact same commands the O and D keys call. Dropped
	# anywhere else (another customer, another chair) - refused, no model
	# call, and _reconcile() snaps it straight back since CardHomes still
	# says it belongs where it started.
	if _is_current_offer(face):
		var chair := int(_shift.at)
		if to_coll == _customer_zones[chair]:
			_on_offer()
		elif to_coll == _discard_zone:
			_on_drop()
		return

	var plan := DropRouter.plan(_shift, face.uid, _zone_name_of(to_coll))
	var command: StringName = plan["command"]

	if command == DropRouter.IGNORE:
		return
	if command == DropRouter.NONE:
		_event_log.append_text("[color=%s]%s[/color]\n" % [Palette.hex(&"alert"), plan["reason"]])
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
		_event_log.append_text("[color=%s]That card left your hand before you could play it.[/color]\n"
			% Palette.hex(&"alert"))
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
			# A freshly drawn card has no prior on-screen position to preserve
			# the way _move_card() preserves one for a card changing zones -
			# it never existed anywhere before. Fabricating one at the draw
			# pile's own spot, converted into home's local space, makes the
			# layout tween insert_card() is about to trigger read as the card
			# actually traveling from the pile rather than popping in at
			# hand's own local origin.
			if desired[uid]["zone"] == CardHomes.ZONE_HAND:
				node.position = home.to_local(_draw_zone.global_position)
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
	# Hand cards, and the offer sitting on whichever table you are CURRENTLY
	# standing at - see _on_drag_card_moved's offer-drag branch. Every other
	# placed product must not intercept the pointer aimed at the zone it sits
	# in (a seat you are not at, or one with nothing on it, offers no drag).
	var is_current_offer: bool = _shift != null and _shift.at != null \
		and zone == CardHomes.chair_zone(int(_shift.at))
	if zone == CardHomes.ZONE_HAND:
		node.enable_collision()
		node.hover_pos_move = HAND_HOVER_LIFT
	elif is_current_offer:
		node.enable_collision()
	else:
		node.disable_collision()
