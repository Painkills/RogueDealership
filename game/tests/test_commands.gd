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

## The same formula Customer.appeal_for() uses, restated independently
## (rather than called into) so a test using it is still real coverage -
## appeal_step is a live balance knob (shift_config.tres).
func _appeal_for_rank(s: Shift, rank: int) -> int:
	return s.cfg.appeal_step * (9 - rank)

# ----------------------------------------------------------- place and offer
func test_placing_costs_a_tick_and_shows_only_a_band() -> void:
	var s := _shift([&"easygoing"])
	var c := _at(s)
	_rank(c, [&"status", &"power", &"reliability"])
	_hand(s, [&"vsc"])
	var r := s.place(0)
	h.check("placing is legal at any rank", r.ok)
	h.eq("it costs a tick", s.tick, 1)
	h.eq("appeal opens at the rank value", c.offer.appeal, _appeal_for_rank(s, 3))
	h.check("a band came back", r.data.has("band"))
	h.check("but not the rank", not c.known_ranks.has(&"reliability"))
	h.check("and not the Line", not c.known_line)
	h.check("and the offer is not revealed", not c.offer.revealed)

func test_offering_is_free_and_teaches_the_rank_but_never_the_line() -> void:
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
	h.check("and marks the offer as asked", c.offer.revealed)
	h.check("but never the Line", not c.known_line)
	h.eq("though the model still knows the true shortfall",
		int(r.data["short"]), 99 - _appeal_for_rank(s, 3))

func test_no_amount_of_offering_ever_teaches_the_line() -> void:
	## The fog has to survive repetition or it is a speed bump, not a rule:
	## offering is free, so "ask four times" would otherwise be a cheaper Read
	## the Room that also costs no card.
	var s := _shift([&"easygoing"])
	var c := _at(s)
	c.line = 99
	_rank(c, [&"status", &"power", &"reliability"])
	_hand(s, [&"vsc"])
	s.place(0)
	for _i in range(4):
		s.offer()
	h.eq("four asks landed", int(s.stat["offers"]), 4)
	h.check("and their Line is still fogged", not c.known_line)

func test_read_the_room_is_the_only_thing_that_lifts_the_fog() -> void:
	var s := _shift([&"easygoing"])
	var c := _at(s)
	_rank(c, [&"power"])
	_hand(s, [&"readroom"])
	h.check("fogged to begin with", not c.known_line)
	s.play_card(0)
	h.check("the read lifts it", c.known_line)
	h.check("and narrows nine interests to three", c.known_top_category != null)
	h.check("without naming the one", not c.known_ranks.has(&"power"))

func test_the_upgraded_room_read_names_their_number_one() -> void:
	## Until it did, upgrading Read the Room bought a second, identical copy of
	## the same effect for $1,100 and changed nothing observable.
	var s := _shift([&"easygoing"])
	var c := _at(s)
	_rank(c, [&"power"])
	_hand(s, [&"readroom"])
	s.hand[0].upgraded = true
	s.play_card(0)
	h.check("it still hands you the Line", c.known_line)
	h.eq("and names the one outright", int(c.known_ranks.get(&"power", 0)), 1)

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
	var appeal := _appeal_for_rank(s, 3)
	c.line = appeal
	_rank(c, [&"status", &"power", &"reliability"])
	_hand(s, [&"vsc"])
	s.place(0)
	s.offer()
	h.eq("appeal == Line sells", c.unsigned.size(), 1)

	var s2 := _shift([&"easygoing"])
	var c2 := _at(s2)
	c2.line = appeal + 1
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
	## The whole reason placing and offering are separate moves. Pad's own
	## effect amounts (appeal down, margin up) are a live balance knob - read
	## them off the card def instead of assuming today's -5/+400.
	var s := _shift([&"easygoing"])
	var c := _at(s)
	var pad := s.card_pool.by_id(&"pad") as SupportCardDef
	var pad_appeal := 0
	var pad_margin := 0
	for e in pad.effects:
		if e is ChangeAppeal:
			pad_appeal = e.amount
		elif e is ChangeMargin:
			pad_margin = e.amount
	var rank1_appeal := _appeal_for_rank(s, 1)
	c.line = rank1_appeal + pad_appeal   # clears only once padded down to it
	_rank(c, [&"reliability"])
	_hand(s, [&"vsc", &"pad"])
	s.place(0)
	s.play_card(0)
	h.eq("padded back to the bar", c.offer.appeal, c.line)
	s.offer()
	var vsc := s.card_pool.by_id(&"vsc")
	h.eq("sold at a padded price", c.unsigned_margin(), vsc.margin + pad_margin)

# ------------------------------------------------------------------- economy
func test_the_line_ramps_by_line_per_sale_on_every_sale() -> void:
	var s := _shift([&"easygoing"])
	var c := _at(s)
	var step: int = c.archetype.line_per_sale
	c.line = 20                             # low enough both sales clear regardless of step
	var line0: int = c.line
	_rank(c, [&"reliability", &"equity"])
	_hand(s, [&"vsc", &"gap"])
	s.place(0); s.offer()
	h.eq("Line ramps by line_per_sale", c.line, line0 + step)
	s.place(0); s.offer()
	h.eq("and again", c.line, line0 + step * 2)

func test_a_sale_refunds_patience_capped_at_max() -> void:
	var s := _shift([&"easygoing"])
	var c := _at(s)
	c.line = 20
	c.patience = 5
	_rank(c, [&"reliability"])
	_hand(s, [&"vsc"])
	s.place(0)          # -1 tick
	s.offer()           # +cfg.patience_per_sale refund
	h.eq("place burned, sale refunded", c.patience, 5 - 1 + s.cfg.patience_per_sale)

func test_margin_can_be_conceded_below_zero_and_banks_as_is() -> void:
	## The arithmetic is the deterrent, never a rule - three concessions on a
	## cheap product should be more than enough to push it underwater whatever
	## today's exact discount/price tuning is.
	var s := _shift([&"easygoing"])
	var c := _at(s)
	c.line = 99
	_rank(c, [&"status", &"power", &"convenience"])   # concierge, the cheapest product
	_hand(s, [&"concierge", &"discount", &"discount", &"discount"])
	s.place(0)
	s.play_card(0); s.play_card(0); s.play_card(0)
	h.check("margin went underwater", c.offer.margin < 0)
	c.line = 0
	s.offer()
	h.check("and a loss banks as a loss", c.unsigned_margin() < 0)

# -------------------------------------------------------------------- moving
func test_walking_the_floor_is_free() -> void:
	## The clock measures WORK, not distance. Checking on someone else and
	## coming back used to cost 2 of 24 ticks, which made "finish whoever you
	## are with and never look up" the cheapest play - a tax on the one decision
	## this game is supposed to be about.
	var s := _shift([&"easygoing", &"easygoing"])
	s.approach(0)
	h.eq("the first walk over is free", s.tick, 0)
	s.leave()
	h.eq("stepping out is free", s.tick, 0)
	s.approach(1)
	h.eq("changing your mind is free too", s.tick, 0)
	s.approach(2)
	s.leave()
	s.approach(0)
	h.eq("and it stays free however much you shop around", s.tick, 0)

func test_the_approach_charge_is_still_one_number_away() -> void:
	## approach_ticks survives at 0 rather than being deleted, so free movement
	## is a tuning decision and not a one-way door. What does NOT survive is the
	## old discount for walking back to last_customer: an asymmetry that made
	## returning cheaper than leaving was the shape of the tunnel vision, so if
	## the charge ever comes back it comes back uniform.
	var s := _shift([&"easygoing", &"easygoing"], {"approach_ticks": 1})
	s.approach(0)
	h.eq("the charge applies when the knob is turned up", s.tick, 1)
	s.leave()
	s.approach(0)
	h.eq("including the walk back to the same person", s.tick, 2)

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
	var vsc_margin: int = s.card_pool.by_id(&"vsc").margin
	s.place(0); s.offer()
	h.eq("agreeing banks nothing", s.margin_banked, 0)
	h.eq("it sits unsigned", c.unsigned_margin(), vsc_margin)
	var t := s.tick
	h.check("close is allowed", s.close().ok)
	h.eq("close banks it", s.margin_banked, vsc_margin)
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
	var agreed: int = c.unsigned_margin()
	h.check("both sales agreed", agreed > 0)
	c.patience = 1
	_hand(s, [&"explain"])
	s.dig(0)
	h.eq("gone", c.state, "walked")
	h.eq("nothing banked", s.margin_banked, 0)
	h.eq("counted as lost", s.lost_to_walks, agreed)

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
	c.demands_category = &"vehicle"
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
	# gap sold first (no prior sales, unmultiplied); vsc second, carrying
	# Karen's own combo multiplier for one prior sale.
	var expected: int = s.card_pool.by_id(&"gap").margin \
		+ roundi(s.card_pool.by_id(&"vsc").margin * (1.0 + c.combo_step))
	h.eq("banking both, the second sale carrying its combo multiplier",
		s.margin_banked, expected)

func test_the_karen_wont_settle_for_her_own_least_favorite_in_the_category() -> void:
	## "give them what they actually came in for" - her own pattern text. The
	## category lock used to accept ANY sale sharing a category with her real
	## number one, even her own least favorite thing in it - which is not what
	## the demand ever claimed to be about.
	var s := _shift([&"karen", &"easygoing"])
	var c := _at(s)
	_rank(c, [&"reliability", &"affordability", &"equity", &"value_retention",
		&"stability", &"convenience", &"status", &"security", &"power"])
	c.demands_category = &"vehicle"   # the category her real number one sits in
	c.line = 0                        # trivial for everyone, including rank 9
	_hand(s, [&"perf"])                # power - Vehicle, but her own rank 9
	s.place(0); s.offer()
	h.eq("even her least favorite sells at line 0", c.unsigned.size(), 1)
	h.check("but does not unlock her - it is not what she came for",
		not s.close().ok)
	_hand(s, [&"vsc"])                 # reliability - her actual number one
	s.place(0); s.offer()
	h.check("her real number one finally does", s.close().ok)
	# perf sold first (no prior sales, unmultiplied); vsc second, carrying
	# Karen's own combo multiplier for one prior sale.
	var expected: int = s.card_pool.by_id(&"perf").margin \
		+ roundi(s.card_pool.by_id(&"vsc").margin * (1.0 + c.combo_step))
	h.eq("banking both sales, the second carrying its combo multiplier",
		s.margin_banked, expected)

func test_the_karen_still_walks_when_her_patience_runs_out() -> void:
	var s := _shift([&"karen", &"easygoing"])
	var c := _at(s)
	c.demands_category = &"vehicle"
	c.line = 20
	_rank(c, [&"equity"])
	_hand(s, [&"gap"])
	s.place(0); s.offer()
	var gap_margin: int = s.card_pool.by_id(&"gap").margin
	h.eq("she agreed to something", c.unsigned_margin(), gap_margin)
	c.patience = 1
	_hand(s, [&"explain"])
	s.dig(0)
	h.eq("the lock does not make her immortal", c.state, "walked")
	h.eq("and it went with her", s.lost_to_walks, gap_margin)
