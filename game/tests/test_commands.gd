extends RefCounted
var h: Harness

const NINE := [&"reliability", &"security", &"power", &"affordability",
	&"equity", &"value_retention", &"stability", &"convenience", &"status"]

func _shift(floor_ids: Array, overrides: Dictionary = {}) -> Shift:
	var cfg: ShiftConfig = (load("res://data/shift_config.tres") as ShiftConfig).duplicate()
	cfg.patience_jitter = 0
	cfg.action_cadence_jitter_ticks = 0
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

## _hand()'s counterpart for the draw pile - id order becomes draw[0], [1], ...
## so a pull test can state "the top N cards" as a plain list.
func _set_draw(s: Shift, ids: Array) -> void:
	s.draw.clear()
	var uid := 800
	for id in ids:
		s.draw.append(CardInstance.new(s.card_pool.by_id(id), uid))
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

## Hand position is not stable once _draw_up() refills behind you - a freshly
## drawn card lands at index 0 (see Shift._draw_up()), pushing whatever a test
## explicitly set up further back by exactly one slot per refill. Scan for the
## card by id instead of assuming it stays wherever _hand() first put it.
func _index_of(s: Shift, id: StringName) -> int:
	for i in range(s.hand.size()):
		if s.hand[i].card.id == id:
			return i
	return -1

## A ProductCardDef built at test time rather than authored as a .tres -
## effects/upgraded_effects now live on every card, but no shipped product
## uses them yet, so this is the only way to cover Shift.place()'s new loop
## without mutating a real, shared card resource. Interest/margin borrowed
## (read, never mutated) from a real product, so _rank()/appeal_for() still
## work exactly as they do for a real card.
func _synthetic_product(s: Shift, effects: Array[Effect],
		upgraded_effects: Array[Effect] = []) -> ProductCardDef:
	var base := s.card_pool.by_id(&"vsc") as ProductCardDef
	var def := ProductCardDef.new()
	def.interest = base.interest
	def.margin = base.margin
	def.id = &"synthetic_product"
	def.display_name = "Synthetic Product"
	def.effects = effects
	def.upgraded_effects = upgraded_effects
	return def

# ----------------------------------------------------------- place and offer
func test_placing_costs_a_tick_and_shows_where_it_ranks_and_only_a_band() -> void:
	var s := _shift([&"easygoing"])
	var c := _at(s)
	_rank(c, [&"status", &"power", &"reliability"])
	_hand(s, [&"vsc"])
	var r := s.place(0)
	h.check("placing is legal at any rank", r.ok)
	h.eq("it costs a tick", s.tick, 1)
	h.eq("appeal opens at the rank value", c.offer.appeal, _appeal_for_rank(s, 3))
	h.check("a band came back", r.data.has("band"))
	h.eq("and where it ranks, on the grid at once", c.known_ranks.get(&"reliability", -1), 3)
	h.eq("and in the result", r.data.get("rank", -1), 3)
	h.check("but not the Line", not c.known_line)

func test_placing_a_product_applies_its_own_effects() -> void:
	var s := _shift([&"easygoing"])
	var c := _at(s)
	var e := ChangeAppeal.new()
	e.amount = 6
	var def := _synthetic_product(s, [e])
	_rank(c, [def.interest.id])
	s.hand.clear()
	s.hand.append(CardInstance.new(def, 999))
	var appeal_before: int = c.appeal_for(def.interest.id)
	var r := s.place(0)
	h.check("placing is still legal", r.ok)
	h.eq("the product's own effect lifted the offer's appeal",
		c.offer.appeal, appeal_before + 6)

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
	var refused := s2.offer()
	h.check("one short cannot be offered", not refused.ok)
	h.eq("so nothing sold", c2.unsigned.size(), 0)
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
	s.play_card(_index_of(s, &"explain"))
	s.play_card(_index_of(s, &"explain"))
	h.check("appeal is over the bar", c.offer.appeal >= c.line)
	h.eq("and nothing is agreed", c.unsigned.size(), 0)
	h.eq("each support card play reached the shift log",
		s.action_log.size(), 2)
	h.eq("named for the card, not a demand or an objection",
		s.action_log[0]["name"], s.card_pool.by_id(&"explain").display_name)
	s.offer()
	h.eq("until you ask", c.unsigned.size(), 1)

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

func test_a_shift_opens_with_you_sat_at_a_and_nothing_moves_you_off_it() -> void:
	## "Start shift seated at A... Don't take me away from a seat even if they
	## leave." Not _at(): this is the shift as it opens.
	var s := _shift([&"easygoing", &"easygoing"])
	h.eq("opens sat at A", s.at, 0)
	h.check("with someone there", s.chairs[0] != null)
	s.chairs[0].patience = 0
	s._settle_patience()
	h.check("they walk out", s.chairs[0] == null or s.chairs[0].state != "floor" or s.waiting.size() >= 0)
	h.eq("and you are still at A, not out on a floor", s.at, 0)
	var c = _at(s)
	_hand(s, [&"vsc"])
	c = s.chairs[0]
	if c != null:
		c.line = 0
		s.place(0)
		s.offer()
		s.close()
		h.eq("signing the next one leaves you there too", s.at, 0)

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
	h.eq("and you are still sat there - nothing moves you off a seat", s.at, 0)
	h.check("so the next to sit down finds you already at it",
		s.chairs[0] == null or s.at == 0)

func test_close_with_nothing_sold_is_refused() -> void:
	## Closing empty used to be a free "give up on this one" button - the only
	## way to shed a customer you will not sell to is now to let their patience
	## run out (which costs standing when they walk). A future effect/card can
	## grant a one-time bypass ("strike") without this refusal itself changing.
	var s := _shift([&"easygoing", &"easygoing"])
	var c := _at(s)
	h.check("nothing to sign, so closing is refused", not s.close().ok)
	h.eq("banks nothing", s.margin_banked, 0)
	h.eq("they are still sitting there", s.chairs[0], c)

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
	h.eq("a refused card never reaches the log", s.action_log.size(), 0)
	h.check("small talk needs no offer", s.play_card(1).ok)
	h.eq("a played one does", s.action_log.size(), 1)

func test_nothing_can_be_played_from_the_floor() -> void:
	var s := _shift([&"easygoing"])
	s.at = null
	_hand(s, [&"smalltalk"])
	h.check("cards need a customer", not s.play_card(0).ok)
	h.check("so does offering", not s.offer().ok)
	h.check("and closing", not s.close().ok)
	h.eq("costs nothing", s.tick, 0)

func test_pulling_with_no_match_leaves_nothing_pending_and_the_pile_untouched() -> void:
	var s := _shift([&"easygoing"])
	_set_draw(s, [&"vsc", &"gap", &"theft"])
	s._start_pull(3, &"support")
	h.check("nothing pending - there was nothing to show",
		s.pending_pull == null)
	h.eq("the pile is exactly as it was", s.draw.size(), 3)

func _give_discard(s: Shift, ids: Array) -> void:
	s.discard.clear()
	var uid := 700
	for id in ids:
		s.discard.append(CardInstance.new(s.card_pool.by_id(id), uid))
		uid += 1

func test_a_pull_the_draw_pile_cannot_fill_shuffles_the_discard_in_first() -> void:
	var s := _shift([&"easygoing"])
	_hand(s, [&"vsc"])
	_set_draw(s, [&"gap"])
	_give_discard(s, [&"smalltalk", &"pad", &"theft", &"appearance"])
	var laps: int = s.reshuffles
	s._start_pull(3, &"any")
	h.eq("the discard was shuffled back in", s.reshuffles, laps + 1)
	h.check("so there are three to choose from", s.pending_pull != null
		and s.pending_pull.revealed.size() == 3)
	h.check("and the discard is empty", s.discard.is_empty())
	h.eq("no card was lost: three revealed, the rest still to draw",
		s.pending_pull.revealed.size() + s.draw.size(), 5)

func test_a_pull_the_draw_pile_can_fill_leaves_the_discard_alone() -> void:
	var s := _shift([&"easygoing"])
	_hand(s, [&"vsc"])
	_set_draw(s, [&"gap", &"smalltalk", &"pad", &"theft"])
	_give_discard(s, [&"appearance", &"flex"])
	var laps: int = s.reshuffles
	s._start_pull(3, &"any")
	h.eq("no shuffle", s.reshuffles, laps)
	h.eq("the discard stays where it is", s.discard.size(), 2)
	h.eq("the top three, as they lay", s.pending_pull.revealed.map(func(i): return i.card.id),
		[&"gap", &"smalltalk", &"pad"])

func test_a_short_pull_with_nothing_to_shuffle_shows_what_there_is() -> void:
	var s := _shift([&"easygoing"])
	_hand(s, [&"vsc"])
	_set_draw(s, [&"gap", &"smalltalk"])
	s.discard.clear()
	var laps: int = s.reshuffles
	s._start_pull(3, &"any")
	h.eq("nothing to shuffle, so none", s.reshuffles, laps)
	h.eq("two is all there is", s.pending_pull.revealed.size(), 2)

func test_a_pull_for_one_kind_shuffles_when_the_pile_has_too_few_of_it() -> void:
	var s := _shift([&"easygoing"])
	_hand(s, [&"vsc"])
	_set_draw(s, [&"gap", &"smalltalk", &"pad"])
	_give_discard(s, [&"theft", &"appearance", &"flex"])
	var laps: int = s.reshuffles
	s._start_pull(3, &"product")
	h.eq("one product was not three: the discard went in", s.reshuffles, laps + 1)
	h.check("and every card revealed is a product",
		s.pending_pull != null and s.pending_pull.revealed.all(func(i): return i.is_product()))

func test_hand_does_not_refill_while_a_pull_is_pending() -> void:
	var s := _shift([&"easygoing"])
	_hand(s, [&"vsc"])
	_set_draw(s, [&"gap", &"smalltalk", &"pad", &"theft"])
	s._start_pull(2, &"any")
	var before: int = s.hand.size()
	s._draw_up()
	h.eq("hand did not grow - the pull owns the next slot",
		s.hand.size(), before)

func test_choosing_puts_the_pick_in_hand_and_returns_the_rest_in_place() -> void:
	var s := _shift([&"easygoing"])
	_hand(s, [&"vsc"])
	_set_draw(s, [&"gap", &"smalltalk", &"pad", &"theft", &"appearance"])
	s._start_pull(3, &"any")                 # reveals gap, smalltalk, pad
	var r := s.choose_pull(1)                # take smalltalk (the middle one)
	h.check("choosing is legal", r.ok)
	var got_it := false
	for c in s.hand:
		if c.card.id == &"smalltalk":
			got_it = true
	h.check("the chosen card is in hand", got_it)
	h.check("no pending pull left", s.pending_pull == null)
	h.eq("the pile is back to original size minus the one kept",
		s.draw.size(), 4)
	h.eq("gap and pad returned to their OWN original slots, in order",
		[s.draw[0].card.id, s.draw[1].card.id, s.draw[2].card.id,
			s.draw[3].card.id],
		[&"gap", &"pad", &"theft", &"appearance"])

func test_canceling_returns_every_revealed_card_to_its_own_slot() -> void:
	## Hand starts FULL, not short a card: cancel_pull() calls _draw_up() to
	## refill whatever slot the pull would have filled, and a hand already at
	## cfg.hand_size means that call is a no-op - keeping this test's own
	## focus on the restore, not on how many cards _draw_up() happens to pull.
	var s := _shift([&"easygoing"])
	_hand(s, [&"vsc", &"vsc", &"vsc", &"vsc", &"vsc"])
	_set_draw(s, [&"gap", &"smalltalk", &"pad", &"theft", &"appearance"])
	s._start_pull(3, &"any")
	var r := s.cancel_pull()
	h.check("canceling is legal", r.ok)
	h.check("no pending pull left", s.pending_pull == null)
	h.eq("the pile is exactly as it was",
		[s.draw[0].card.id, s.draw[1].card.id, s.draw[2].card.id,
			s.draw[3].card.id, s.draw[4].card.id],
		[&"gap", &"smalltalk", &"pad", &"theft", &"appearance"])

func test_choosing_or_canceling_with_nothing_pending_is_refused() -> void:
	var s := _shift([&"easygoing"])
	h.check("choosing refused", not s.choose_pull(0).ok)
	h.check("canceling refused", not s.cancel_pull().ok)

func test_choosing_an_out_of_range_index_is_refused_and_leaves_the_pull_intact() -> void:
	var s := _shift([&"easygoing"])
	_set_draw(s, [&"vsc", &"gap", &"theft"])
	s._start_pull(2, &"any")
	var r := s.choose_pull(5)
	h.check("refused", not r.ok)
	h.check("the pull is still pending", s.pending_pull != null)

func test_no_command_goes_ahead_while_a_pull_waits_on_your_choice() -> void:
	# A second card played over a pending pull would stage another on top of it
	# and the first one's revealed cards would be gone from the deck for good -
	# so the rule is the model's, not just the view's input lock.
	var s := _shift([&"easygoing"])
	_at(s)
	# Something on the table and a support card to play on it, so that each
	# command below WOULD go ahead were it not for the pull.
	_hand(s, [&"smalltalk", &"vsc"])
	h.check("a product goes on the table", s.place(1).ok)
	var support := -1
	for i in range(s.hand.size()):
		if not s.hand[i].is_product():
			support = i
	h.check("and there is a support card to play on it", support >= 0)
	_set_draw(s, [&"vsc", &"gap", &"theft"])
	s._start_pull(2, &"any")
	var staged: PendingPull = s.pending_pull
	var held: int = staged.revealed.size()
	var hand_before: int = s.hand.size()
	var tick_before: int = s.tick
	h.check("playing a card is refused", not s.play_card(support).ok)
	h.check("digging is refused", not s.dig(0).ok)
	h.check("offering is refused", not s.offer().ok)
	h.check("closing is refused", not s.close().ok)
	h.check("dropping is refused", not s.drop_offer().ok)
	h.check("the same pull is still the one waiting", s.pending_pull == staged)
	h.eq("none of what it revealed went anywhere", staged.revealed.size(), held)
	h.eq("nothing left the hand", s.hand.size(), hand_before)
	h.eq("no time passed", s.tick, tick_before)
	h.check("choosing still works", s.choose_pull(0).ok)
	h.check("and then the commands do again", s.dig(0).ok)
