extends RefCounted
## The effects behind Good Will, Plus Service Fee, the coffee and Think on it, and
## playing on somebody you are not standing with. Made-up cards and customers
## throughout: nothing here knows what ships, only what the rules do.
var h: Harness

func _cfg() -> ShiftConfig:
	var cfg: ShiftConfig = (load("res://data/shift_config.tres") as ShiftConfig).duplicate()
	cfg.patience_jitter = 0
	cfg.action_cadence_jitter_ticks = 0
	cfg.arrival_patience_min_fraction = 1.0
	cfg.shift_ticks = 99
	cfg.hand_size = 5
	return cfg

func _shift(seed_value: int = 5) -> Shift:
	var s := Shift.new(_cfg(), load("res://data/interests/interest_pool.tres"),
		load("res://data/card_pool.tres"), load("res://data/archetype_pool.tres"), seed_value)
	for i in range(s.chairs.size()):
		s.chairs[i] = null
	return s

func _arch(line: int = 20, patience: int = 99) -> CustomerArchetype:
	var a := CustomerArchetype.new()
	a.id = &"made_up"
	a.display_name = "Made-up"
	a.line = line
	a.patience = patience
	a.line_per_sale = 0
	a.combo_weight = 2.0
	return a

func _products() -> Array:
	var out := []
	for def in (load("res://data/card_pool.tres") as CardPool).cards:
		if def is ProductCardDef:
			out.append(def)
	return out

## A support card of made-up effects.
func _card(effects: Array, needs_offer: bool = true, ticks: int = 1) -> SupportCardDef:
	var d := SupportCardDef.new()
	d.id = &"made_up_card"
	d.display_name = "Made-up Card"
	d.ticks = ticks
	d.needs_offer = needs_offer
	d.effects.assign(effects)
	return d

func _lingering(inner: Effect, ticks: int, stacks: bool = true) -> Linger:
	var l := Linger.new()
	l.inner = inner
	l.ticks = ticks
	l.stacks = stacks
	return l

func _patience(amount: int) -> ChangePatience:
	var e := ChangePatience.new()
	e.amount = amount
	return e

func _appeal(amount: int) -> ChangeAppeal:
	var e := ChangeAppeal.new()
	e.amount = amount
	return e

## Seats a customer in `chair` and puts a product from the pool on their table.
func _seat(s: Shift, chair: int, arch: CustomerArchetype, with_offer: bool = true) -> Customer:
	s._spawn(chair, arch)
	var c: Customer = s.chairs[chair]
	if with_offer:
		s.at = chair
		s.hand.clear()
		s.hand.append(CardInstance.new(_products()[0], 800 + chair))
		s.place(0)
	return c

func _hold(s: Shift, def: CardDef, uid: int = 900) -> int:
	s.hand.clear()
	s.hand.append(CardInstance.new(def, uid))
	return 0

# ----------------------------------------------------------------- Good Will
func test_good_will_turns_every_point_over_the_line_into_money() -> void:
	var s := _shift()
	var c := _seat(s, 0, _arch(20))
	c.offer.appeal = 27
	var margin: int = c.offer.margin
	var e := ConvertSurplusAppeal.new()
	e.amount = 20
	e.apply(s._yours(c))
	h.eq("appeal comes down to exactly the Line", c.offer.appeal, c.line)
	h.eq("and the 7 points are paid, $20 each", c.offer.margin, margin + 140)

func test_good_will_does_nothing_at_or_under_the_line() -> void:
	var s := _shift()
	var c := _seat(s, 0, _arch(20))
	var e := ConvertSurplusAppeal.new()
	e.amount = 20
	for appeal in [20, 12]:
		c.offer.appeal = appeal
		var margin: int = c.offer.margin
		e.apply(s._yours(c))
		h.eq("appeal %d is left alone" % appeal, c.offer.appeal, appeal)
		h.eq("and so is the margin", c.offer.margin, margin)

func test_what_good_will_pays_is_multiplied_by_the_combo_like_the_rest() -> void:
	var s := _shift()
	var arch := _arch(0)
	var c := _seat(s, 0, arch)
	c.sales = 2
	c.offer.appeal = 10
	c.offer.margin = 1000
	var e := ConvertSurplusAppeal.new()
	e.amount = 20
	e.apply(s._yours(c))
	h.eq("10 points, $200 on the offer", c.offer.margin, 1200)
	var sale := s._settle(c)
	h.eq("and the combo (x2 on the third product) multiplies all of it", sale["margin"], 2400)

# ---------------------------------------------------------- Plus Service Fee
func test_the_service_fee_is_per_product_already_taken() -> void:
	var s := _shift()
	var c := _seat(s, 0, _arch(0))
	var e := MarginPerProductTaken.new()
	e.amount = 100
	var margin: int = c.offer.margin
	e.apply(s._yours(c))
	h.eq("nothing on a first product", c.offer.margin, margin)
	c.unsigned.append({"product": _products()[1], "margin": 500})
	e.apply(s._yours(c))
	h.eq("$100 with one taken", c.offer.margin, margin + 100)
	for i in range(8):
		c.unsigned.append({"product": _products()[1], "margin": 0})
	var before: int = c.offer.margin
	e.apply(s._yours(c))
	h.eq("$900 with all nine taken", c.offer.margin - before, 900)

func test_the_service_fee_scales_with_the_combo() -> void:
	var s := _shift()
	var c := _seat(s, 0, _arch(0))
	c.unsigned.append({"product": _products()[1], "margin": 500})
	c.sales = 1
	c.offer.margin = 1000
	var e := MarginPerProductTaken.new()
	e.amount = 100
	e.apply(s._yours(c))
	var sale := s._settle(c)
	h.eq("the $100 is in the margin the combo (x1.5) multiplies", sale["margin"], 1650)

# -------------------------------------------------------------------- Linger
func test_a_lingering_effect_happens_once_a_tick_after_the_card_for_its_ticks() -> void:
	var s := _shift()
	var c := _seat(s, 0, _arch(20, 40), false)
	c.patience = 10
	s.at = 0
	var card := _card([_lingering(_patience(5), 3)], false)
	_hold(s, card)
	s.play_card(0)
	# The card costs a tick, and patience drains one a tick: it has not started.
	h.eq("not on the tick the card costs (patience %d)" % c.patience, c.patience, 9)
	s._burn(1, "cards")
	h.eq("the first tick: -1 and +5", c.patience, 13)
	s._burn(1, "cards")
	h.eq("the second", c.patience, 17)
	s._burn(1, "cards")
	h.eq("the third", c.patience, 21)
	h.check("and then it is gone", c.lingering.is_empty())
	s._burn(1, "cards")
	h.eq("so the fourth tick only takes", c.patience, 20)

func test_a_lingering_effect_goes_on_while_you_work_somebody_else() -> void:
	var s := _shift()
	var a := _seat(s, 0, _arch(20, 40), false)
	var b := _seat(s, 1, _arch(20, 40), false)
	a.patience = 10
	s.at = 0
	_hold(s, _card([_lingering(_patience(5), 2)], false))
	s.play_card(0)
	s.approach(1)
	s._burn(2, "cards")
	h.check("patience rose on the one you left, not only the one you stand at (%d)" % a.patience,
		a.patience > 10 - 3)
	h.check("and the customer you are with is only draining (%d)" % b.patience, b.patience < b.max_patience)

func test_a_lingering_effect_goes_on_whatever_else_you_play_on_them() -> void:
	## "Remove the breaking of the over time effect": nothing you play cancels it.
	var s := _shift()
	var c := _seat(s, 0, _arch(60, 99))
	var appeal: int = c.offer.appeal
	_hold(s, _card([_lingering(_appeal(2), 4, false)]))
	s.play_card(0)
	h.eq("the card itself adds nothing yet", c.offer.appeal, appeal)
	s._burn(1, "cards")
	h.eq("one tick: +2", c.offer.appeal, appeal + 2)
	_hold(s, _card([_appeal(1)]), 901)
	s.play_card(0)
	h.eq("another card on them adds its own +1 and the +2 a tick carries on",
		c.offer.appeal, appeal + 2 + 1 + 2)
	h.eq("still working", c.lingering.size(), 1)
	s._burn(2, "cards")
	h.check("until it has run its ticks (%d from %d)" % [c.offer.appeal, appeal],
		c.offer.appeal >= appeal + 2 + 1 + 2 + 2)

func test_a_lingering_effect_that_does_not_stack_only_starts_over() -> void:
	var s := _shift()
	var c := _seat(s, 0, _arch(60, 99))
	var appeal: int = c.offer.appeal
	var think := _card([_lingering(_appeal(2), 4, false)])
	_hold(s, think)
	s.play_card(0)
	s._burn(2, "cards")
	h.eq("two ticks in: +4", c.offer.appeal, appeal + 4)
	s.hand.append(CardInstance.new(think, 902))
	s.play_card(s.hand.size() - 1)
	h.eq("played again, there is still only one of it", c.lingering.size(), 1)
	h.eq("started over: four ticks to go", int(c.lingering[0]["ticks_left"]), 4)
	s._burn(1, "cards")
	h.eq("so +2 a tick, not +4", c.offer.appeal, appeal + 4 + 2)

func test_a_lingering_effect_that_stacks_runs_twice_when_played_twice() -> void:
	var s := _shift()
	var c := _seat(s, 0, _arch(60, 99))
	var card := _card([_lingering(_appeal(2), 4)])
	_hold(s, card)
	s.play_card(0)
	s.hand.append(CardInstance.new(card, 903))
	s.play_card(s.hand.size() - 1)
	h.eq("two of it at once", c.lingering.size(), 2)

func test_a_lingering_effect_for_a_product_that_is_gone_does_nothing() -> void:
	var s := _shift()
	var c := _seat(s, 0, _arch(60, 99))
	_hold(s, _card([_lingering(_appeal(2), 4, false)]))
	s.play_card(0)
	s.drop_offer()
	s._burn(3, "cards")
	h.check("no offer, so nothing to give appeal to - and no error", c.offer == null)

func test_a_lingering_effect_describes_itself() -> void:
	var l := _lingering(_patience(2), 4)
	h.check("what it does and for how long (%s)" % l.describe(),
		l.describe().contains("+2") and l.describe().contains("4 ticks"))
	var t := _lingering(_appeal(2), 4, false)
	h.eq("and nothing about stacking - the card does not need to say it (%s)" % t.describe(),
		t.describe(), l.describe())

# ------------------------------------------------- play on somebody you are not with
func test_a_product_can_be_put_in_front_of_somebody_you_are_not_standing_with() -> void:
	var s := _shift()
	var here := _seat(s, 0, _arch(20), false)
	var away := _seat(s, 1, _arch(20), false)
	s.at = 0
	s.hand.clear()
	s.hand.append(CardInstance.new(_products()[0], 801))
	var res := s.play_card(0, 1)
	h.check("it is placed (%s)" % res.msg, res.ok)
	h.check("on their table", away.offer != null and here.offer == null)
	h.eq("and you have not moved", s.at, 0)

func test_a_patience_card_can_be_played_on_somebody_you_are_not_standing_with() -> void:
	var s := _shift()
	_seat(s, 0, _arch(20, 40), false)
	var away := _seat(s, 1, _arch(20, 40), false)
	s.at = 0
	away.patience = 10
	_hold(s, _card([_patience(5)], false))
	var res := s.play_card(0, 1)
	h.check("it is played (%s)" % res.msg, res.ok)
	h.check("on them (%d)" % away.patience, away.patience > 10)
	h.eq("and you have not moved", s.at, 0)

func test_other_cards_still_need_you_to_walk_over() -> void:
	var s := _shift()
	_seat(s, 0, _arch(20), false)
	var away := _seat(s, 1, _arch(20))
	s.at = 0
	_hold(s, _card([_appeal(4)]))
	var res := s.play_card(0, 1)
	h.check("an appeal card is refused (%s)" % res.msg, not res.ok)
	h.check("and says to go and stand with them", res.msg.contains("stand with"))
	h.eq("nothing was played", s.hand.size(), 1)

func test_playing_away_refuses_an_empty_chair_in_the_models_own_words() -> void:
	var s := _shift()
	_seat(s, 0, _arch(20), false)
	s.at = 0
	s.hand.clear()
	s.hand.append(CardInstance.new(_products()[0], 801))
	var res := s.play_card(0, 2)
	h.check("nobody there (%s)" % res.msg, not res.ok and res.msg.contains("Nobody"))

func test_what_counts_as_a_patience_card() -> void:
	h.check("one that gives patience", _card([_patience(3)], false).is_patience_card())
	var floor_wide := ChangePatienceFloor.new()
	floor_wide.amount = 3
	h.check("a floor-wide one", _card([floor_wide], false).is_patience_card())
	h.check("one that gives it over time", _card([_lingering(_patience(2), 4)], false).is_patience_card())
	h.check("not one that also does something else",
		not _card([_patience(3), _appeal(2)], false).is_patience_card())
	h.check("not one that takes it away", not _card([_patience(-3)], false).is_patience_card())
	h.check("not one that does nothing", not _card([], false).is_patience_card())
	h.check("and not an appeal card", not _card([_appeal(4)]).is_patience_card())

# ---------------------------------------------------------------- the swivel
func test_the_table_always_turns_the_short_way() -> void:
	var worst := 0.0
	for from_seat in range(3):
		for to_seat in range(3):
			var now := -deg_to_rad(120.0 * from_seat)
			var there := CarouselTurn.nearest(now, -deg_to_rad(120.0 * to_seat))
			worst = maxf(worst, absf(there - now))
			h.check("seat %d to seat %d lands on that seat" % [from_seat, to_seat],
				absf(angle_difference(there, -deg_to_rad(120.0 * to_seat))) < 0.0001)
	h.check("never more than a third of a turn (%.0f degrees)" % rad_to_deg(worst),
		worst <= deg_to_rad(120.0) + 0.0001)
	h.eq("from the last seat to the first, one step on", snappedf(
		CarouselTurn.nearest(-deg_to_rad(240.0), 0.0), 0.0001), snappedf(-deg_to_rad(360.0), 0.0001))

# ------------------------------------------- numbers shown are the totals
func _perked_shift(bonus: int) -> Shift:
	var s := _shift()
	var u := DealershipUpgrade.new()
	u.appeal_per_card = bonus
	s.dealership.append(u)
	return s

func test_the_appeal_a_card_shows_includes_what_the_dealership_adds() -> void:
	var s := _perked_shift(2)
	_seat(s, 0, _arch(40))
	_hold(s, _card([_appeal(2)]))
	s.play_card(0)
	h.eq("+2 and the perk's +2 shown as one +4", int(s.action_log.back()["fx"]["appeal"]), 4)

func test_each_tick_of_a_slow_card_shows_its_total_too() -> void:
	var s := _perked_shift(2)
	var c := _seat(s, 0, _arch(40))
	_hold(s, _card([_lingering(_appeal(2), 3)]))
	s.play_card(0)
	s._tick_lingering(c)
	s._tick_lingering(c)
	h.eq("each tick shows +4", int(s.action_log.back()["fx"]["appeal"]), 4)

# ----------------------------------- a customer patience cards count double for
func test_patience_cards_count_by_the_scale_of_who_they_are_played_on() -> void:
	var s := _shift()
	var arch := _arch(40, 20)
	arch.patience_card_scale = 2.0
	var c := _seat(s, 0, arch)
	c.patience = 10
	_hold(s, _card([_patience(3)]))
	s.play_card(0)
	h.eq("+3 counts as +6 (and a tick of patience is spent playing it)", c.patience, 15)
	_hold(s, _card([_patience(-4)]))
	s.play_card(0)
	h.eq("a loss is not scaled", c.patience, 10)

func test_over_time_patience_is_scaled_every_tick() -> void:
	var s := _shift()
	var arch := _arch(40, 50)
	arch.patience_card_scale = 2.0
	var c := _seat(s, 0, arch)
	c.patience = 10
	_hold(s, _card([_lingering(_patience(2), 3)]))
	s.play_card(0)
	s._tick_lingering(c)
	h.eq("a tick of +2 is +4", c.patience, 13)

func test_a_customer_with_no_scale_gets_the_card_as_written() -> void:
	var s := _shift()
	var c := _seat(s, 0, _arch(40, 20))
	c.patience = 10
	_hold(s, _card([_patience(3)]))
	s.play_card(0)
	h.eq("+3 is +3", c.patience, 12)
