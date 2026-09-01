extends RefCounted
var h: Harness

func _shift() -> Shift:
	var cfg: ShiftConfig = load("res://data/shift_config.tres").duplicate()
	cfg.patience_jitter = 0
	cfg.prior_slip = 0.0
	return Shift.new(cfg,
		load("res://data/interests/interest_pool.tres"),
		load("res://data/card_pool.tres"),
		load("res://data/archetype_pool.tres"), 1, [&"easygoing"])

func test_report_dictionary_has_every_key_the_report_panel_reads() -> void:
	var s := _shift()
	var r := s.report()
	for key in ["margin_banked", "quota", "made_quota", "customers_seen",
			"customers_signed", "customers_walked", "offers", "sales",
			"close_rate", "failed_offers", "margin_conceded", "margin_padded",
			"margin_bonus", "margin_lost_to_walks", "margin_lost_to_closing"]:
		h.check("report has %s, which report_panel.gd reads" % key, r.has(key))

func test_format_money_matches_what_customer_panel_will_show() -> void:
	var s := _shift()
	s.at = 0
	s.last_customer = s.chairs[0]
	var c: Customer = s.chairs[0]
	c.line = 20
	c.ranks[&"reliability"] = 1
	s.hand.clear()
	s.hand.append(CardInstance.new(s.card_pool.by_id(&"vsc"), 900))
	s.place(0)
	s.offer()
	h.eq("the panel would show the sold margin correctly formatted",
		Format.money(c.unsigned[0]["margin"]), "$1,600")

func test_action_log_entries_carry_every_field_the_event_log_reads() -> void:
	var s := _shift2_karen()
	s.at = 0
	s.last_customer = s.chairs[0]
	for _i in range(5):
		s.dig(0)
	h.check("something fired", s.action_log.size() >= 1)
	var entry: Dictionary = s.action_log[0]
	for key in ["key", "customer", "name", "dialogue", "descriptions", "floor_wide"]:
		h.check("action_log entry has %s" % key, entry.has(key))

func _shift2_karen() -> Shift:
	var cfg: ShiftConfig = load("res://data/shift_config.tres").duplicate()
	cfg.patience_jitter = 0
	cfg.prior_slip = 0.0
	return Shift.new(cfg,
		load("res://data/interests/interest_pool.tres"),
		load("res://data/card_pool.tres"),
		load("res://data/archetype_pool.tres"), 1, [&"karen", &"easygoing"])

func test_a_products_category_and_interest_are_reachable_the_way_hand_card_reads_them() -> void:
	var pool: CardPool = load("res://data/card_pool.tres")
	var vsc := pool.by_id(&"vsc") as ProductCardDef
	h.check("interest is set", vsc.interest != null)
	h.check("category is reachable through interest",
		vsc.interest.category != null)
	h.eq("category display name is what HandCard prints",
		vsc.interest.category.display_name, "Vehicle")
