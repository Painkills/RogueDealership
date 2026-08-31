extends RefCounted
var h: Harness

const NINE := [&"reliability", &"security", &"power", &"affordability",
	&"equity", &"value_retention", &"stability", &"convenience", &"status"]

func _shift(floor_ids: Array, overrides: Dictionary = {}) -> Shift:
	var cfg: ShiftConfig = (load("res://data/shift_config.tres") as ShiftConfig).duplicate()
	cfg.patience_jitter = 0
	cfg.prior_slip = 0.0
	cfg.arrival_patience_min_fraction = 1.0
	for k in overrides:
		cfg.set(k, overrides[k])
	return Shift.new(cfg,
		load("res://data/interests/interest_pool.tres"),
		load("res://data/card_pool.tres"),
		load("res://data/archetype_pool.tres"), 1, floor_ids)

func _rank(c: Customer, order: Array) -> void:
	var rest := []
	for i in NINE:
		if not order.has(i):
			rest.append(i)
	var n := 1
	for iid in order + rest:
		c.ranks[iid] = n
		n += 1

func _hand(s: Shift, ids: Array) -> void:
	s.hand.clear()
	var uid := 900
	for id in ids:
		s.hand.append(CardInstance.new(s.card_pool.by_id(id), uid))
		uid += 1

func _at(s: Shift, chair: int = 0) -> Customer:
	s.at = chair
	s.last_customer = s.chairs[chair]
	return s.chairs[chair]

# ------------------------------------------------------------- Budget Hawk
func test_budget_hawk_gets_harder_every_time_you_ask_and_miss() -> void:
	var s := _shift([&"hawk"])
	var c := _at(s)
	_rank(c, [&"status", &"power", &"reliability"])   # appeal 30 vs her 40
	var start: int = c.line
	_hand(s, [&"vsc"])
	s.place(0)
	s.offer()
	h.eq("a short offer makes her harder", c.line, start + 5)
	s.offer()
	h.eq("and it stacks", c.line, start + 10)

func test_budget_hawk_does_not_punish_an_offer_that_clears() -> void:
	var s := _shift([&"hawk"])
	var c := _at(s)
	_rank(c, [&"reliability"])                        # appeal 40 == her 40
	_hand(s, [&"vsc"])
	s.place(0)
	s.offer()
	h.eq("it sold", c.unsigned.size(), 1)
	h.eq("only the normal ramp applied", c.line, 40 + 3)

# -------------------------------------------------------------- Tire Kicker
func test_tire_kicker_bleeds_every_four_ticks() -> void:
	var s := _shift([&"kicker", &"easygoing"])
	var c := _at(s)
	var start: int = c.patience
	for _i in range(3):
		s.dig(0)
	h.eq("three ticks, three patience", c.patience, start - 3)
	s.dig(0)
	h.eq("on the fourth he loses two more", c.patience, start - 4 - 2)

# ---------------------------------------------------------- Tech Enthusiast
func test_tech_enthusiast_pays_a_premium_for_a_bullseye() -> void:
	var s := _shift([&"tech"])
	var c := _at(s)
	c.line = 30
	_rank(c, [&"reliability"])                        # his 1st
	_hand(s, [&"vsc"])
	s.place(0); s.offer()
	h.eq("bullseye banks the premium", c.unsigned_margin(), 1600 + 300)

	var s2 := _shift([&"tech"])
	var c2 := _at(s2)
	c2.line = 30
	_rank(c2, [&"status", &"power", &"reliability"])  # his 3rd
	_hand(s2, [&"vsc"])
	s2.place(0); s2.offer()
	h.eq("third place is just a sale", c2.unsigned_margin(), 1600)

func test_the_bullseye_premium_is_counted_in_the_stats() -> void:
	var s := _shift([&"tech"])
	var c := _at(s)
	c.line = 30
	_rank(c, [&"reliability"])
	_hand(s, [&"vsc"])
	s.place(0); s.offer()
	h.eq("the bonus is tracked", int(s.stat["margin_bonus"]), 300)

# ------------------------------------------------------------- Family First
func test_family_first_bleeds_when_you_fish_below_her_top_five() -> void:
	var s := _shift([&"family"])
	var c := _at(s)
	_rank(c, [&"reliability", &"stability", &"equity", &"security",
		&"affordability", &"convenience"])            # convenience 6th
	_hand(s, [&"concierge"])
	s.place(0)
	var p: int = c.patience
	s.offer()
	h.eq("fishing costs 4 on top of the failed offer", c.patience, p - 1 - 4)

func test_family_first_does_not_mind_a_miss_inside_her_top_five() -> void:
	var s := _shift([&"family"])
	var c := _at(s)
	_rank(c, [&"reliability", &"stability", &"equity", &"security",
		&"affordability"])                            # affordability 5th
	_hand(s, [&"flex"])
	s.place(0)
	var p: int = c.patience
	s.offer()
	h.eq("a miss she cared about costs only the offer", c.patience, p - 1)

func test_family_first_never_gets_harder_across_four_sales() -> void:
	var s := _shift([&"family"])
	var c := _at(s)
	c.line = 20
	_rank(c, [&"reliability", &"equity", &"stability", &"security"])
	var start: int = c.line
	_hand(s, [&"vsc", &"gap", &"ppp", &"theft"])
	for _i in range(4):
		s.place(0); s.offer()
	h.eq("four sales landed", c.unsigned.size(), 4)
	h.eq("and she wants exactly what she wanted", c.line, start)

# ----------------------------------------------------------------- The Karen
func test_the_karen_drains_everyone_but_herself() -> void:
	var s := _shift([&"karen", &"easygoing", &"easygoing"])
	_at(s)
	var hers: int = s.chairs[0].patience
	var theirs: int = s.chairs[1].patience
	for _i in range(5):
		s.dig(0)
	h.eq("she pays only the clock", s.chairs[0].patience, hers - 5)
	h.eq("everyone else pays the clock and her",
		s.chairs[1].patience, theirs - 5 - 1)
	h.eq("and so does C", s.chairs[2].patience, theirs - 5 - 1)

# ------------------------------------------------------------------- quiet
func test_the_quiet_archetypes_never_do_anything() -> void:
	for id in [&"easygoing", &"laydown"]:
		var s := _shift([id, id])
		var c := _at(s)
		c.line = 99
		_rank(c, [&"status", &"power", &"reliability"])
		_hand(s, [&"vsc"])
		s.place(0)
		s.offer()
		s.offer()
		for _i in range(3):
			s.dig(0)
		h.eq("%s does nothing to you" % id, s.action_log.size(), 0)

# ----------------------------------------------------------- announcements
func test_a_fired_action_is_announced_with_its_effect_text() -> void:
	var s := _shift([&"karen", &"easygoing"])
	_at(s)
	for _i in range(5):
		s.dig(0)
	h.check("something was announced", s.action_log.size() >= 1)
	var entry: Dictionary = s.action_log[0]
	h.check("it names the customer", str(entry["customer"]) != "")
	h.check("it carries dialogue", str(entry["dialogue"]) != "")
	h.check("it is flagged floor-wide", bool(entry["floor_wide"]))
	h.check("and it describes the effect",
		str(entry["descriptions"]).to_lower().contains("everyone else"))

func test_a_self_only_action_is_not_flagged_floor_wide() -> void:
	var s := _shift([&"kicker", &"easygoing"])
	_at(s)
	for _i in range(4):
		s.dig(0)
	h.check("the kicker acted", s.action_log.size() >= 1)
	h.check("but not on the whole floor",
		not bool(s.action_log[0]["floor_wide"]))

func test_actions_fired_is_counted() -> void:
	var s := _shift([&"karen", &"easygoing"])
	_at(s)
	for _i in range(5):
		s.dig(0)
	h.check("the counter moved", int(s.stat["actions_fired"]) >= 1)
