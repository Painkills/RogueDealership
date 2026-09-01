extends Control

const FloorCardScene := preload("res://scenes/floor_card.tscn")
const HandCardScene := preload("res://scenes/hand_card.tscn")
const CustomerPanelScene := preload("res://scenes/customer_panel.tscn")

@onready var _tick_label: Label = %TickLabel
@onready var _banked_label: Label = %BankedLabel
@onready var _at_risk_label: Label = %AtRiskLabel
@onready var _floor_row: HBoxContainer = %FloorRow
@onready var _customer_slot: Control = %CustomerSlot
@onready var _empty_slot_label: Label = %EmptySlotLabel
@onready var _hand_row: HBoxContainer = %HandRow
@onready var _event_log: RichTextLabel = %EventLog
@onready var _report_overlay = %ReportOverlay
@onready var _background: ColorRect = %Background

var _shift: Shift
var _floor_cards: Array = []
var _customer_panel
var _events_seen: int = 0
var _actions_seen: int = 0

func _ready() -> void:
	_register_keyboard_actions()
	_background.color = Palette.color(&"bg")
	_start_new_shift()
	_report_overlay.restart_pressed.connect(_start_new_shift)

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
		_on_hand_card_pressed(index)

func _try_dig(index: int) -> void:
	if index < _shift.hand.size():
		_apply(_shift.dig(index))

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

	for c in _floor_cards:
		c.queue_free()
	_floor_cards.clear()
	for i in range(3):
		var fc := FloorCardScene.instantiate()
		_floor_row.add_child(fc)
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

func _on_chair_pressed(chair_index: int) -> void:
	_apply(_shift.approach(chair_index))

func _on_offer() -> void:
	_apply(_shift.offer())

func _on_close() -> void:
	_apply(_shift.close())

func _on_drop() -> void:
	_apply(_shift.drop_offer())

func _on_hand_card_pressed(index: int) -> void:
	_apply(_shift.play_card(index))

func _apply(res: Result) -> void:
	if not res.ok:
		_event_log.append_text("[color=red]%s[/color]\n" % res.msg)
	_render()
	if _shift.is_over():
		_show_report()

func _render() -> void:
	_tick_label.text = "tick %d/%d" % [_shift.tick, _shift.tick_budget]
	_banked_label.text = "banked %s / %s" \
		% [Format.money(_shift.margin_banked), Format.money(_shift.quota)]
	var risk: int = _shift.margin_at_risk()
	_at_risk_label.text = "%s unsigned on the floor" % Format.money(risk) \
		if risk > 0 else "nothing unsigned"

	for i in range(3):
		_floor_cards[i].setup(_shift.chairs[i], _shift.walk_up[i], i)

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

	for child in _hand_row.get_children():
		child.queue_free()
	for i in range(_shift.hand.size()):
		var hc := HandCardScene.instantiate()
		_hand_row.add_child(hc)
		hc.setup(_shift.hand[i])
		hc.index = i
		hc.pressed.connect(_on_hand_card_pressed.bind(i))

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
