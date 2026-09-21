extends RefCounted
var h: Harness

func _shift(floor_ids: Array, overrides: Dictionary = {}) -> Shift:
	var cfg: ShiftConfig = (load("res://data/shift_config.tres") as ShiftConfig).duplicate()
	cfg.patience_jitter = 0
	cfg.action_cadence_jitter_ticks = 0
	cfg.prior_slip = 0.0
	cfg.arrival_patience_min_fraction = 1.0
	for k in overrides:
		cfg.set(k, overrides[k])
	return Shift.new(cfg,
		load("res://data/interests/interest_pool.tres"),
		load("res://data/card_pool.tres"),
		load("res://data/archetype_pool.tres"), 1, floor_ids)

func test_closing_time_forfeits_whatever_is_unsigned() -> void:
	var s := _shift([&"easygoing"], {"shift_ticks": 2})
	s.at = 0
	s.last_customer = s.chairs[0]
	var c: Customer = s.chairs[0]
	c.line = 20
	c.ranks[&"reliability"] = 1
	var vsc_margin: int = s.card_pool.by_id(&"vsc").margin
	s.hand.clear()
	s.hand.append(CardInstance.new(s.card_pool.by_id(&"vsc"), 901))
	s.place(0)                       # tick 1
	s.offer()
	h.eq("agreed but unsigned", c.unsigned_margin(), vsc_margin)
	s.hand.append(CardInstance.new(s.card_pool.by_id(&"explain"), 902))
	s.dig(0)                         # tick 2 - the bell
	h.check("the day ended", s.is_over())
	h.eq("nothing banked", s.margin_banked, 0)
	h.eq("reported lost at the bell",
		int(s.report()["margin_lost_to_closing"]), vsc_margin)

func test_the_report_carries_every_key_the_ui_will_need() -> void:
	var s := _shift([&"easygoing"])
	var r: Dictionary = s.report()
	for key in ["margin_banked", "quota", "made_quota", "standing_delta",
			"standing_lost_to_walkouts", "ticks", "tick_budget", "customers_seen",
			"customers_signed", "customers_walked", "sales", "offers",
			"failed_offers", "close_rate", "margin_conceded", "margin_padded",
			"margin_bonus", "margin_lost_to_walks", "margin_lost_to_closing",
			"actions_fired", "digs", "approaches", "ticks_cards", "ticks_place",
			"ticks_digs", "ticks_approach", "sale_streak_end", "sale_streak_events",
			"peak_combo_multiplier"]:
		h.check("report has %s" % key, r.has(key))

func test_standing_delta_matches_the_scale_configured() -> void:
	## Exact 50% steps with both scales set to 100, so the formula's shape is
	## checked without any rounding-tie ambiguity.
	var s := _shift([&"easygoing"], {"quota": 1000, "standing_damage_scale": 100.0,
		"standing_heal_scale": 100.0})
	s.margin_banked = 500
	h.eq("a 50% shortfall costs half the scale", int(s.report()["standing_delta"]), -50)
	s.margin_banked = 1000
	h.eq("landing exactly on quota is a wash", int(s.report()["standing_delta"]), 0)
	s.margin_banked = 1500
	h.eq("a 50% overage heals half the scale", int(s.report()["standing_delta"]), 50)

func test_walkouts_cost_standing_on_their_own() -> void:
	## Independent of the quota-delta - letting people leave threatens the job
	## by itself, so this is checked with a quota already comfortably beaten,
	## where a purely quota-driven formula would otherwise be healing.
	var s := _shift([&"easygoing", &"easygoing", &"easygoing"],
		{"quota": 100, "standing_cost_per_walkout": 8, "standing_heal_scale": 0.0})
	s.margin_banked = 9999   # beats quota hugely; heal_scale=0 keeps that term at 0
	h.eq("no walkouts yet, no cost", int(s.report()["standing_lost_to_walkouts"]), 0)
	h.eq("and the combined delta is just the (zeroed) quota term",
		int(s.report()["standing_delta"]), 0)

	s.chairs[0].patience = 0
	s.chairs[1].patience = 0
	s._settle_patience()
	h.eq("two walked", int(s.report()["customers_walked"]), 2)
	h.eq("costing twice the per-walkout rate",
		int(s.report()["standing_lost_to_walkouts"]), 16)
	h.eq("which is the WHOLE combined delta here, quota term zeroed out",
		int(s.report()["standing_delta"]), -16)

func test_a_banked_shift_reports_it_made_quota() -> void:
	var s := _shift([&"easygoing"], {"quota": 1000})
	s.at = 0
	s.last_customer = s.chairs[0]
	var c: Customer = s.chairs[0]
	c.line = 20
	c.ranks[&"reliability"] = 1
	var vsc_margin: int = s.card_pool.by_id(&"vsc").margin
	s.hand.clear()
	s.hand.append(CardInstance.new(s.card_pool.by_id(&"vsc"), 901))
	s.place(0)
	s.offer()
	s.close()
	var r: Dictionary = s.report()
	h.eq("banked", int(r["margin_banked"]), vsc_margin)
	h.check("made quota", bool(r["made_quota"]))
	h.eq("one signed", int(r["customers_signed"]), 1)
	h.eq("one sale in one offer", int(r["sales"]), 1)
	h.eq("close rate is 100%", float(r["close_rate"]), 1.0)
