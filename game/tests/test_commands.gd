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

# ----------------------------------------------------------- place and offer
func test_placing_costs_a_tick_and_shows_only_a_band() -> void:
	var s := _shift([&"easygoing"])
	var c := _at(s)
	_rank(c, [&"status", &"power", &"reliability"])
	_hand(s, [&"vsc"])
	var r := s.place(0)
	h.check("placing is legal at any rank", r.ok)
	h.eq("it costs a tick", s.tick, 1)
	h.eq("appeal opens at the rank value", c.offer.appeal, 30)
	h.check("a band came back", r.data.has("band"))
	h.check("but not the rank", not c.known_ranks.has(&"reliability"))
	h.check("and not the Line", not c.known_line)
	h.check("and the offer is not revealed", not c.offer.revealed)

func test_offering_is_free_and_reveals_everything() -> void:
	var s := _shift([&"easygoing"])
	var c := _at(s)
	c.line = 99
	_rank(c, [&"status", &"power", &"reliability"])
	_hand(s, [&"vsc"])
	s.place(0)
	var t := s.tick
	var r := s.offer()
	h.eq("offering costs no ticks", s.tick, t)
	h.check("it teaches you the rank", c.known_ranks.has(&"reliability"))
	h.check("and the Line", c.known_line)
	h.eq("and reports the shortfall", int(r.data["short"]), 69)

func test_a_short_offer_costs_one_patience_and_nothing_else() -> void:
	var s := _shift([&"easygoing", &"easygoing"])
	var c := _at(s)
	c.line = 99
	_rank(c, [&"status", &"power", &"reliability"])
	_hand(s, [&"vsc"])
	s.place(0)
	var p: int = c.patience
	var b: int = s.chairs[1].patience
	s.offer()
	h.eq("they bruise a little", c.patience, p - 1)
	h.eq("and nobody else pays", s.chairs[1].patience, b)

func test_accept_fires_exactly_at_the_line_not_above() -> void:
	var s := _shift([&"easygoing"])
	var c := _at(s)
	c.line = 30
	_rank(c, [&"status", &"power", &"reliability"])
	_hand(s, [&"vsc"])
	s.place(0)
	s.offer()
	h.eq("appeal == Line sells", c.unsigned.size(), 1)

	var s2 := _shift([&"easygoing"])
	var c2 := _at(s2)
	c2.line = 31
	_rank(c2, [&"status", &"power", &"reliability"])
	_hand(s2, [&"vsc"])
	s2.place(0)
	s2.offer()
	h.eq("one short does not sell", c2.unsigned.size(), 0)
	h.check("and it stays on the table", c2.offer != null)

func test_support_cards_alone_never_close_a_sale() -> void:
	## Acceptance happens on OFFER and nowhere else - the whole point of the
	## two-step.
	var s := _shift([&"easygoing"])
	var c := _at(s)
	c.line = 30
	_rank(c, [&"status", &"power", &"reliability"])
	_hand(s, [&"vsc", &"explain", &"explain"])
	s.place(0)
	s.play_card(0)
	s.play_card(0)
	h.check("appeal is over the bar", c.offer.appeal >= c.line)
	h.eq("and nothing is agreed", c.unsigned.size(), 0)
	s.offer()
	h.eq("until you ask", c.unsigned.size(), 1)

func test_pad_works_on_a_product_that_would_have_closed_cold() -> void:
	## The whole reason placing and offering are separate moves.
	var s := _shift([&"easygoing"])
	var c := _at(s)
	c.line = 35
	_rank(c, [&"reliability"])              # appeal 40, clears by 5
	_hand(s, [&"vsc", &"pad"])
	s.place(0)
	s.play_card(0)
	h.eq("padded back to the bar", c.offer.appeal, 35)
	s.offer()
	h.eq("sold at a padded price", c.unsigned_margin(), 2000)

# ------------------------------------------------------------------- economy
func test_the_line_ramps_three_per_sale() -> void:
	var s := _shift([&"easygoing"])
	var c := _at(s)
	c.line = 20
	_rank(c, [&"reliability", &"equity"])
	_hand(s, [&"vsc", &"gap"])
	s.place(0); s.offer()
	h.eq("Line ramps +3", c.line, 23)
	s.place(0); s.offer()
	h.eq("and again", c.line, 26)

func test_a_sale_refunds_patience_capped_at_max() -> void:
	var s := _shift([&"easygoing"])
	var c := _at(s)
	c.line = 20
	c.patience = 5
	_rank(c, [&"reliability"])
	_hand(s, [&"vsc"])
	s.place(0)          # -1 tick
	s.offer()           # +3 refund
	h.eq("place burned, sale refunded", c.patience, 5 - 1 + 3)

func test_margin_can_be_conceded_below_zero_and_banks_as_is() -> void:
	## The arithmetic is the deterrent, never a rule.
	var s := _shift([&"easygoing"])
	var c := _at(s)
	c.line = 99
	_rank(c, [&"status", &"power", &"convenience"])   # concierge $600
	_hand(s, [&"concierge", &"discount", &"discount", &"discount"])
	s.place(0)
	s.play_card(0); s.play_card(0); s.play_card(0)
	h.eq("margin went underwater", c.offer.margin, 600 - 900)
	c.line = 0
	s.offer()
	h.eq("and a loss banks as a loss", c.unsigned_margin(), -300)

# -------------------------------------------------------------------- moving
func test_going_back_to_the_same_customer_is_free() -> void:
	var s := _shift([&"easygoing", &"easygoing"])
	s.approach(0)
	h.eq("the first walk over costs a tick", s.tick, 1)
	s.leave()
	h.eq("stepping out is free", s.tick, 1)
	s.approach(0)
	h.eq("going back is free", s.tick, 1)
	s.leave()
	s.approach(1)
	h.eq("changing your mind costs a tick", s.tick, 2)

func test_approaching_who_you_are_already_with_is_refused() -> void:
	var s := _shift([&"easygoing", &"easygoing"])
	s.approach(0)
	var t := s.tick
	h.check("refused", not s.approach(0).ok)
	h.eq("and costs nothing", s.tick, t)

# ------------------------------------------------------------- banking
func test_close_is_the_only_thing_that_banks() -> void:
	var s := _shift([&"easygoing", &"easygoing"])
	var c := _at(s)
	c.line = 20
	_rank(c, [&"reliability"])
	_hand(s, [&"vsc"])
	s.place(0); s.offer()
	h.eq("agreeing banks nothing", s.margin_banked, 0)
	h.eq("it sits unsigned", c.unsigned_margin(), 1600)
	var t := s.tick
	h.check("close is allowed", s.close().ok)
	h.eq("close banks it", s.margin_banked, 1600)
	h.eq("closing is free", s.tick, t)
	h.eq("they are gone", c.state, "signed")
	h.eq("the chair is empty", s.chairs[0], null)
	h.eq("and you are back on the floor", s.at, null)

func test_close_with_nothing_sold_is_legal_and_banks_zero() -> void:
	var s := _shift([&"easygoing", &"easygoing"])
	_at(s)
	h.check("dismissing an unsold customer is allowed", s.close().ok)
	h.eq("banks nothing", s.margin_banked, 0)
	h.eq("chair freed", s.chairs[0], null)

func test_walking_forfeits_the_entire_unsigned_deal() -> void:
	var s := _shift([&"easygoing", &"easygoing"])
	var c := _at(s)
	c.line = 20
	_rank(c, [&"reliability", &"equity"])
	_hand(s, [&"vsc", &"gap"])
	s.place(0); s.offer()
	s.place(0); s.offer()
	h.eq("$3,000 agreed", c.unsigned_margin(), 3000)
	c.patience = 1
	_hand(s, [&"explain"])
	s.dig(0)
	h.eq("gone", c.state, "walked")
	h.eq("nothing banked", s.margin_banked, 0)
	h.eq("counted as lost", s.lost_to_walks, 3000)

# ----------------------------------------------------------------- refusals
func test_only_one_offer_on_the_table() -> void:
	var s := _shift([&"easygoing"])
	var c := _at(s)
	c.line = 99
	_rank(c, [&"status", &"power", &"reliability"])
	_hand(s, [&"vsc", &"gap"])
	s.place(0)
	var t := s.tick
	h.check("a second product is refused", not s.place(0).ok)
	h.eq("and costs nothing", s.tick, t)
	h.eq("the first is untouched", c.offer.product.id, &"vsc")

func test_dropping_is_free_and_loses_the_concessions() -> void:
	var s := _shift([&"easygoing"])
	var c := _at(s)
	c.line = 99
	_rank(c, [&"status", &"power", &"reliability"])
	_hand(s, [&"vsc", &"discount"])
	s.place(0)
	s.play_card(0)
	var t := s.tick
	s.drop_offer()
	h.eq("dropping is free", s.tick, t)
	h.eq("nothing on the table", c.offer, null)

func test_a_product_they_already_bought_cannot_be_placed_again() -> void:
	var s := _shift([&"easygoing"])
	var c := _at(s)
	c.line = 20
	_rank(c, [&"reliability"])
	_hand(s, [&"vsc"])
	s.place(0); s.offer()
	_hand(s, [&"vsc"])
	var t := s.tick
	h.check("no double-dipping", not s.place(0).ok)
	h.eq("and it costs nothing", s.tick, t)

func test_support_cards_need_something_on_the_table() -> void:
	var s := _shift([&"easygoing"])
	_at(s)
	_hand(s, [&"discount", &"smalltalk"])
	h.check("a discount on nothing is refused", not s.play_card(0).ok)
	h.check("small talk needs no offer", s.play_card(1).ok)

func test_nothing_can_be_played_from_the_floor() -> void:
	var s := _shift([&"easygoing"])
	s.at = null
	_hand(s, [&"smalltalk"])
	h.check("cards need a customer", not s.play_card(0).ok)
	h.check("so does offering", not s.offer().ok)
	h.check("and closing", not s.close().ok)
	h.eq("costs nothing", s.tick, 0)

# -------------------------------------------------------------- the Karen
func test_the_karen_will_not_sign_without_what_she_came_for() -> void:
	var s := _shift([&"karen", &"easygoing"])
	var c := _at(s)
	_rank(c, [&"reliability"])
	c.demands = &"vehicle"
	c.line = 20
	h.check("she refuses to sign", not s.close().ok)
	h.eq("nothing banked", s.margin_banked, 0)
	h.eq("and she is still sitting there", s.chairs[0], c)
	_hand(s, [&"gap"])
	s.place(0); s.offer()               # Deal, not what she wants
	h.check("wrong category does not unlock her", not s.close().ok)
	_hand(s, [&"vsc"])
	s.place(0); s.offer()               # Vehicle
	h.check("now she signs", s.close().ok)
	h.eq("banking both", s.margin_banked, 1400 + 1600)

func test_the_karen_still_walks_when_her_patience_runs_out() -> void:
	var s := _shift([&"karen", &"easygoing"])
	var c := _at(s)
	c.demands = &"vehicle"
	c.line = 20
	_rank(c, [&"equity"])
	_hand(s, [&"gap"])
	s.place(0); s.offer()
	h.eq("she agreed to something", c.unsigned_margin(), 1400)
	c.patience = 1
	_hand(s, [&"explain"])
	s.dig(0)
	h.eq("the lock does not make her immortal", c.state, "walked")
	h.eq("and it went with her", s.lost_to_walks, 1400)
