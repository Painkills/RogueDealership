extends RefCounted
## Momentum: the next cards you play cost no ticks. What spends it, what earns it,
## what it cannot do. Made-up cards, products and perks throughout - nothing here
## knows what ships, only what the rules do.
var h: Harness

func _cfg(max_momentum: int = 3) -> ShiftConfig:
	var cfg: ShiftConfig = (load("res://data/shift_config.tres") as ShiftConfig).duplicate()
	cfg.patience_jitter = 0
	cfg.action_cadence_jitter_ticks = 0
	cfg.arrival_patience_min_fraction = 1.0
	cfg.shift_ticks = 99
	cfg.hand_size = 5
	cfg.momentum_max = max_momentum
	return cfg

func _shift(max_momentum: int = 3, perks: Array = []) -> Shift:
	var s := Shift.new(_cfg(max_momentum), load("res://data/interests/interest_pool.tres"),
		load("res://data/card_pool.tres"), load("res://data/archetype_pool.tres"), 5,
		[], null, 0, 1, 0, 0, null, 0, 1.0, 1.0, [], [], [], {}, perks)
	for i in range(s.chairs.size()):
		s.chairs[i] = null
	return s

func _arch(line: int = 20) -> CustomerArchetype:
	var a := CustomerArchetype.new()
	a.id = &"made_up"
	a.display_name = "Made-up"
	a.line = line
	a.patience = 99
	a.line_per_sale = 0
	return a

func _seat(s: Shift, chair: int, arch: CustomerArchetype) -> Customer:
	s._spawn(chair, arch)
	s.at = chair
	return s.chairs[chair]

## A support card that costs `ticks` and does `effects`.
func _card(ticks: int, effects: Array = []) -> CardInstance:
	var d := SupportCardDef.new()
	d.id = &"made_up_card"
	d.display_name = "Made-up Card"
	d.ticks = ticks
	d.needs_offer = false
	d.effects.assign(effects)
	return CardInstance.new(d, 900 + ticks)

func _product(ticks: int) -> CardInstance:
	var src: ProductCardDef
	for def in (load("res://data/card_pool.tres") as CardPool).cards:
		if def is ProductCardDef:
			src = def
			break
	var p := ProductCardDef.new()
	p.id = &"made_up_product"
	p.display_name = "Made-up Product"
	p.interest = src.interest
	p.margin = 1000
	p.ticks = ticks
	return CardInstance.new(p, 950 + ticks)

func _momentum(amount: int, per_sale: int = 0) -> GainMomentum:
	var e := GainMomentum.new()
	e.amount = amount
	e.per_sale = per_sale
	return e

## Plays `inst` from the hand and says how many ticks it cost.
func _spent(s: Shift, inst: CardInstance) -> int:
	s.hand.clear()
	s.hand.append(inst)
	var before := s.tick
	var res := s.play_card(0)
	h.check("it was played (%s)" % res.msg, res.ok)
	return s.tick - before

# ----------------------------------------------------------------- spending it
func test_momentum_makes_the_next_card_free_and_only_the_next() -> void:
	var s := _shift()
	_seat(s, 0, _arch())
	s.gain_momentum(1)
	h.eq("a charge is held", s.momentum, 1)
	h.eq("the preview says free", s.cost_of(_card(2)), 0)
	h.eq("and the card is", _spent(s, _card(2)), 0)
	h.eq("spending the charge", s.momentum, 0)
	h.eq("the one after pays in full", _spent(s, _card(2)), 2)
	h.eq("and the preview says so", s.cost_of(_card(2)), 2)

func test_each_charge_pays_for_one_card() -> void:
	var s := _shift()
	_seat(s, 0, _arch())
	s.gain_momentum(2)
	var costs := [_spent(s, _card(1)), _spent(s, _card(3)), _spent(s, _card(2))]
	h.eq("two free, then full price", costs, [0, 0, 2])

func test_a_card_that_costs_nothing_spends_none() -> void:
	var s := _shift()
	_seat(s, 0, _arch())
	s.gain_momentum(1)
	_spent(s, _card(0))
	h.eq("the charge is still there", s.momentum, 1)
	h.eq("for one that costs something", _spent(s, _card(1)), 0)

func test_a_product_put_down_spends_it_too() -> void:
	var s := _shift()
	_seat(s, 0, _arch(999))
	s.gain_momentum(1)
	h.eq("free", _spent(s, _product(3)), 0)
	h.eq("and spent", s.momentum, 0)
	s.drop_offer()
	h.eq("the next costs what it says", _spent(s, _product(3)), 3)

func test_digging_is_never_free() -> void:
	var s := _shift()
	_seat(s, 0, _arch())
	s.gain_momentum(2)
	s.hand.clear()
	s.hand.append(_card(1))
	var before := s.tick
	s.dig(0)
	h.eq("a dig costs its ticks", s.tick - before, s.cfg.dig_ticks)
	h.eq("and spends no charge", s.momentum, 2)

# ----------------------------------------------------------------- earning it
func test_a_card_that_earns_momentum_does_not_spend_its_own() -> void:
	var s := _shift()
	_seat(s, 0, _arch())
	h.eq("with none held it costs its ticks", _spent(s, _card(2, [_momentum(2)])), 2)
	h.eq("and leaves what it gave", s.momentum, 2)
	var t := _shift()
	_seat(t, 0, _arch())
	t.gain_momentum(1)
	h.eq("with one held it is the free one", _spent(t, _card(2, [_momentum(2)])), 0)
	h.eq("and still leaves what it gave", t.momentum, 2)

func test_momentum_never_passes_the_config() -> void:
	var s := _shift(2)
	_seat(s, 0, _arch())
	s.gain_momentum(1)
	s.gain_momentum(5)
	h.eq("two at most", s.momentum, 2)
	h.eq("and what it gained is what it kept", int(s.stat["momentum_gained"]), 2)

func test_momentum_grows_with_the_products_they_have_taken() -> void:
	var s := _shift(99)
	var c := _seat(s, 0, _arch())
	var e := _momentum(1, 2)
	e.apply(s._yours(c))
	h.eq("a first customer's first card: just the base", s.momentum, 1)
	for _i in range(3):
		c.unsigned.append({"margin": 0})
	e.apply(s._yours(c))
	h.eq("three products on, 1 + 2 each more", s.momentum, 1 + 1 + 2 * 3)

func test_what_they_do_never_gives_you_momentum() -> void:
	var s := _shift()
	var c := _seat(s, 0, _arch())
	_momentum(3).apply(s._context(c))
	h.eq("only your own cards do", s.momentum, 0)

# ----------------------------------------------------------- the dealership
func _perk(on_sale: int, at_open: int) -> DealershipUpgrade:
	var u := DealershipUpgrade.new()
	u.id = &"made_up_perk"
	u.momentum_on_sale = on_sale
	u.momentum_at_open = at_open
	return u

func test_a_perk_can_open_every_shift_with_momentum() -> void:
	h.eq("none without it", _shift().momentum, 0)
	h.eq("two with it", _shift(3, [_perk(0, 2)]).momentum, 2)
	h.eq("never more than the config holds", _shift(1, [_perk(0, 2)]).momentum, 1)

func test_a_perk_can_pay_momentum_for_every_sale() -> void:
	var s := _shift(3, [_perk(1, 0)])
	_seat(s, 0, _arch(0))
	_spent(s, _product(1))
	h.eq("nothing before the yes", s.momentum, 0)
	var res := s.offer()
	h.check("they said yes (%s)" % res.msg, res.ok)
	h.eq("and it paid a charge", s.momentum, 1)
	var plain := _shift()
	_seat(plain, 0, _arch(0))
	_spent(plain, _product(1))
	plain.offer()
	h.eq("without the perk it pays nothing", plain.momentum, 0)

# ----------------------------------------------------------------- the words
func test_it_says_what_it_gives() -> void:
	h.eq("one", _momentum(1).describe(), "Momentum: next card free")
	h.eq("several", _momentum(3).describe(), "Momentum: next 3 cards free")
	h.check("and what the products add", _momentum(1, 2).describe().contains("+2 per product taken"))

func test_a_flat_margin_percent_does_not_mention_patience() -> void:
	var flat := MarginPercent.new()
	flat.amount = 10
	flat.low_amount = 10
	h.eq("the same either way, so said once", flat.describe(), "+10% Margin")
	var pushed := MarginPercent.new()
	pushed.amount = 10
	pushed.low_amount = 40
	h.check("but a bigger one when they are worn down says so",
		pushed.describe().contains("under"))
