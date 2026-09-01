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
	_background.color = Palette.color(&"bg")
	_start_new_shift()
	_report_overlay.restart_pressed.connect(_start_new_shift)

func _start_new_shift() -> void:
	var cfg: ShiftConfig = load("res://data/shift_config.tres")
	var interests: InterestPool = load("res://data/interests/interest_pool.tres")
	var cards: CardPool = load("res://data/card_pool.tres")
	var archetypes: ArchetypePool = load("res://data/archetype_pool.tres")
	_shift = Shift.new(cfg, interests, cards, archetypes, randi(), [])
	_events_seen = 0
	_actions_seen = 0
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

func _apply(_res: Result) -> void:
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
