extends RefCounted
## The verbs behind Mind Games, Insistence, Risky Business, Meet and Greet and
## Everyone's Taking It!, and the Retire keyword. Made-up cards and customers
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

func _shift() -> Shift:
	var s := Shift.new(_cfg(), load("res://data/interests/interest_pool.tres"),
		load("res://data/card_pool.tres"), load("res://data/archetype_pool.tres"), 5)
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
	return a

func _products() -> Array:
	var out := []
	for def in (load("res://data/card_pool.tres") as CardPool).cards:
		if def is ProductCardDef:
			out.append(def)
	return out

func _card(effects: Array, needs_offer: bool = true) -> SupportCardDef:
	var d := SupportCardDef.new()
	d.id = &"made_up_card"
	d.display_name = "Made-up Card"
	d.ticks = 1
	d.needs_offer = needs_offer
	d.effects.assign(effects)
	return d

func _seat(s: Shift, chair: int, arch: CustomerArchetype) -> Customer:
	s._spawn(chair, arch)
	return s.chairs[chair]

## Puts the pool's `which`-th product on `chair`'s table.
func _place(s: Shift, chair: int, which: int = 0) -> void:
	s.at = chair
	s.hand.clear()
	s.hand.append(CardInstance.new(_products()[which], 800 + chair * 10 + which))
	s.place(0)

func _play(s: Shift, def: CardDef, uid: int = 900) -> Result:
	s.hand.clear()
	s.hand.append(CardInstance.new(def, uid))
	return s.play_card(0)

# ---------------------------------------------------------------- WaiveLine
func test_a_waived_line_is_0_for_the_next_product_only() -> void:
	var s := _shift()
	var c := _seat(s, 0, _arch(30))
	s.at = 0
	var waive := WaiveLine.new()
	waive.amount = 1
	_play(s, _card([waive], false))
	h.eq("nothing on the table yet: the Line stands", c.line, 30)
	_place(s, 0)
	h.eq("the next product faces a Line of 0", c.line, 0)
	h.check("so they would take it", s.offer_refusal(c) == "")
	s.drop_offer()
	h.eq("off the table, the Line is back", c.line, 30)
	_place(s, 0, 1)
	h.eq("and the product after it faces the real one", c.line, 30)

func test_two_waivers_last_two_products() -> void:
	var s := _shift()
	var c := _seat(s, 0, _arch(30))
	s.at = 0
	var waive := WaiveLine.new()
	waive.amount = 2
	_play(s, _card([waive], false))
	for which in range(2):
		_place(s, 0, which)
		h.eq("product %d faces 0" % which, c.line, 0)
		s.drop_offer()
	_place(s, 0, 2)
	h.eq("the third does not", c.line, 30)

func test_what_moves_the_line_while_it_is_waived_is_kept() -> void:
	var s := _shift()
	var c := _seat(s, 0, _arch(30))
	s.at = 0
	var waive := WaiveLine.new()
	waive.amount = 1
	_play(s, _card([waive], false))
	_place(s, 0)
	c.line += 4
	s.drop_offer()
	h.eq("the +4 lands on the real Line", c.line, 34)

func test_a_sale_on_a_waived_line_brings_the_line_back_with_its_rise() -> void:
	var s := _shift()
	var arch := _arch(30)
	arch.line_per_sale = 5
	var c := _seat(s, 0, arch)
	s.at = 0
	var waive := WaiveLine.new()
	waive.amount = 1
	_play(s, _card([waive], false))
	_place(s, 0)
	var res := s.offer()
	h.check("sold at a Line of 0 (%s)" % res.msg, res.ok and c.offer == null)
	h.eq("the real Line comes back, risen by the sale", c.line, 35)

# --------------------------------------------------------- PatienceToAppeal
func test_insistence_turns_half_their_patience_into_appeal() -> void:
	var s := _shift()
	var c := _seat(s, 0, _arch(90))
	_place(s, 0)
	c.patience = 21
	var appeal: int = c.offer.appeal
	var e := PatienceToAppeal.new()
	e.amount = 50
	e.apply(s._yours(c))
	h.eq("half of 21, rounded down, comes off", c.patience, 11)
	h.eq("and goes on as appeal", c.offer.appeal, appeal + 10)

func test_insistence_with_nothing_on_the_table_takes_nothing() -> void:
	var s := _shift()
	var c := _seat(s, 0, _arch(90))
	c.patience = 20
	var e := PatienceToAppeal.new()
	e.amount = 50
	e.apply(s._yours(c))
	h.eq("patience untouched", c.patience, 20)

func test_the_forecast_sees_what_insistence_takes() -> void:
	var s := _shift()
	var c := _seat(s, 0, _arch(90))
	_place(s, 0)
	c.patience = 20
	var e := PatienceToAppeal.new()
	e.amount = 50
	var card := CardInstance.new(_card([e]), 950)
	var f: Dictionary = s.forecast(1, 0, card)
	h.eq("10 taken and a tick drained", int(f["chairs"][0]["patience_after"]), 9)

# ------------------------------------------------------------ MarginPercent
func test_risky_business_adds_a_share_of_the_margin() -> void:
	var s := _shift()
	var c := _seat(s, 0, _arch(90))
	_place(s, 0)
	c.offer.margin = 1000
	c.patience = c.max_patience
	var e := MarginPercent.new()
	e.amount = 25
	e.low_amount = 50
	e.low_below = 0.2
	e.apply(s._yours(c))
	h.eq("+25% while they are patient", c.offer.margin, 1250)
	c.offer.margin = 1000
	c.patience = int(c.max_patience * 0.2) - 1
	e.apply(s._yours(c))
	h.eq("+50% under a fifth of their patience", c.offer.margin, 1500)

# ------------------------------------------------------- StandingPerCustomer
func test_meet_and_greet_pays_standing_for_everyone_on_the_floor() -> void:
	var s := _shift()
	_seat(s, 0, _arch())
	_seat(s, 1, _arch())
	s.at = 0
	s.standing = 50
	var e := StandingPerCustomer.new()
	e.amount = 3
	e.apply(s._yours(s.chairs[0]))
	h.eq("two customers, +6", s.standing, 56)
	s.standing = s.cfg.standing_start - 1
	e.apply(s._yours(s.chairs[0]))
	h.eq("never past where it starts", s.standing, s.cfg.standing_start)

# ------------------------------------------------------- MeetLineFloorWide
func test_everyone_s_taking_it_brings_every_table_up_to_its_line() -> void:
	var s := _shift()
	var a := _seat(s, 0, _arch(40))
	var b := _seat(s, 1, _arch(60))
	var empty := _seat(s, 2, _arch(50))
	_place(s, 0)
	_place(s, 1, 1)
	a.offer.appeal = 10
	b.offer.appeal = 70
	s.at = 0
	var e := MeetLineFloorWide.new()
	e.apply(s._yours(a))
	h.eq("one short comes up to its Line", a.offer.appeal, 40)
	h.eq("one past it keeps what it has", b.offer.appeal, 70)
	h.check("an empty table stays empty", empty.offer == null)
	h.check("and it counts as floor-wide", s._is_floor_wide(e))

# -------------------------------------------------------------------- Retire
func test_a_retiring_card_leaves_the_deck_for_the_shift() -> void:
	var s := _shift()
	_seat(s, 0, _arch())
	s.at = 0
	var def := _card([], false)
	def.retires = true
	var res := _play(s, def, 960)
	h.check("it is played (%s)" % res.msg, res.ok)
	var where := s.exhausted.filter(func(i): return i.uid == 960)
	h.eq("out of the deck", where.size(), 1)
	h.check("not in the discard, the draw or the hand",
		(s.discard + s.draw + s.hand).all(func(i): return i.uid != 960))
	h.check("and its face says so (%s)" % CardText.body(where[0]),
		CardText.body(where[0]).contains("Retire"))

func test_a_card_that_does_not_retire_goes_to_the_discard() -> void:
	var s := _shift()
	_seat(s, 0, _arch())
	s.at = 0
	_play(s, _card([], false), 961)
	h.check("in the discard", s.discard.any(func(i): return i.uid == 961))
