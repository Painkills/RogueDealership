extends RefCounted
## Patience as the block in front of your standing: who walks at zero and who
## stays and complains, what complaining costs, a faster clock, the happy margin,
## and the new triggers that hit patience. Made-up archetypes and cards only.
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

func _arch(complains: bool = false, per_point: int = 1) -> CustomerArchetype:
	var a := CustomerArchetype.new()
	a.id = &"made_up"
	a.display_name = "Made-up"
	a.line = 0
	a.patience = 30
	a.line_per_sale = 0
	a.complains = complains
	a.complaint_per_point = per_point
	return a

func _seat(s: Shift, chair: int, arch: CustomerArchetype) -> Customer:
	s._spawn(chair, arch)
	s.at = chair
	return s.chairs[chair]

func _products() -> Array:
	return (load("res://data/card_pool.tres") as CardPool).cards.filter(
		func(c): return c is ProductCardDef)

func _place(s: Shift, chair: int) -> void:
	s.at = chair
	s.hand.clear()
	s.hand.append(CardInstance.new(_products()[0], 800 + chair))
	s.place(0)

func _patience_hit(amount: int) -> Array[Effect]:
	var e := ChangePatience.new()
	e.amount = amount
	var out: Array[Effect] = [e]
	return out

func _action(id: StringName, trigger: Trigger, effects: Array[Effect]) -> CustomerAction:
	var a := CustomerAction.new()
	a.id = id
	a.display_name = String(id)
	a.trigger = trigger
	a.effects = effects
	return a

# ------------------------------------------------------------- at zero
func test_a_walker_walks_at_zero_for_the_configs_cost() -> void:
	var s := _shift()
	var c := _seat(s, 0, _arch())
	c.patience = 1
	var before := s.standing
	s._burn(1, "wait")
	h.eq("gone", c.state, "walked")
	h.eq("for the config's walkout cost", before - s.standing, s.cfg.standing_cost_per_walkout)

func test_a_complainer_stays_and_every_point_past_zero_costs_standing() -> void:
	var s := _shift()
	var c := _seat(s, 0, _arch(true, 2))
	c.patience = 1
	var before := s.standing
	s._burn(1, "wait")
	h.check("still there at zero", s.chairs[0] == c and c.patience == 0)
	h.eq("nothing yet - they only just ran out", s.standing, before)
	s._burn(3, "wait")
	h.eq("three ticks past zero, 2 each", before - s.standing, 6)
	h.eq("and patience stays at zero", c.patience, 0)
	h.check("the screen is told (%s)" % str(s.events.back()), s.events.back().contains("complains"))

func test_a_hit_past_zero_costs_standing_too() -> void:
	var s := _shift()
	var c := _seat(s, 0, _arch(true, 1))
	c.patience = 2
	var before := s.standing
	c.add_patience(-7)
	s._settle_patience()
	h.eq("the 5 past zero", before - s.standing, 5)

func test_raising_their_patience_stops_the_complaining() -> void:
	var s := _shift()
	var c := _seat(s, 0, _arch(true, 1))
	c.patience = 0
	c.add_patience(4)
	var before := s.standing
	s._burn(3, "wait")
	h.eq("three ticks of patience to spend first", s.standing, before)
	h.eq("and none left", c.patience, 1)

# ------------------------------------------------------------- the clock
func test_an_impatient_customer_loses_patience_faster() -> void:
	var s := _shift()
	var calm := _seat(s, 0, _arch())
	var quick_arch := _arch()
	quick_arch.drain_per_tick = 2
	var quick := _seat(s, 1, quick_arch)
	var calm_before := calm.patience
	var quick_before := quick.patience
	s._burn(3, "wait")
	h.eq("1 a tick", calm_before - calm.patience, 3)
	h.eq("2 a tick", quick_before - quick.patience, 6)
	var f := s.forecast(2)
	h.eq("and the preview knows it", int(f["chairs"][1]["patience_after"]), quick.patience - 4)

func test_the_preview_says_what_a_complainer_will_cost() -> void:
	var s := _shift()
	var c := _seat(s, 0, _arch(true, 2))
	c.patience = 1
	var f: Dictionary = s.forecast(4)["chairs"][0]
	h.check("not a walkout", not bool(f["walks"]))
	h.eq("3 past zero, 2 each", int(f["complains"]), 6)
	h.check("and a walker would walk", bool(_walker_forecast()["walks"]))

func _walker_forecast() -> Dictionary:
	var s := _shift()
	var c := _seat(s, 0, _arch())
	c.patience = 1
	return s.forecast(4)["chairs"][0]

# ------------------------------------------------------------- happy margin
func test_a_happy_customer_pays_more_and_an_unhappy_one_does_not() -> void:
	for happy in [true, false]:
		var s := _shift()
		var a := _arch()
		a.happy_margin_scale = 1.5
		a.happy_above = 0.5
		var c := _seat(s, 0, a)
		_place(s, 0)
		c.offer.margin = 1000
		c.patience = c.max_patience if happy else c.max_patience / 2
		var sale := s._settle(c)
		h.eq("%s: margin" % ("above half" if happy else "at half"), int(sale["margin"]),
			1500 if happy else 1000)

# ------------------------------------------------------------- the triggers
func test_waving_off_a_card_can_cost_them_patience() -> void:
	var s := _shift()
	var a := _arch()
	a.rejects_every_nth_card = 1
	a.actions.assign([_action(&"told", OnReject.new(), _patience_hit(-3))])
	var c := _seat(s, 0, a)
	var card := SupportCardDef.new()
	card.id = &"made_up_card"
	card.ticks = 0
	card.needs_offer = false
	s.hand.clear()
	s.hand.append(CardInstance.new(card, 950))
	var before := c.patience
	s.play_card(0)
	h.eq("3 for the card they waved off", before - c.patience, 3)

func test_a_cadence_can_wait_for_an_empty_table() -> void:
	var s := _shift()
	var every := Every.new()
	every.ticks = 2
	every.only_when_table_empty = true
	var a := _arch()
	a.actions.assign([_action(&"bored", every, _patience_hit(-3))])
	var c := _seat(s, 0, a)
	_place(s, 0)
	var before := c.patience
	s._burn(4, "wait")
	h.eq("with something in front of them, only the clock", before - c.patience, 4)
	s.drop_offer()
	before = c.patience
	s._burn(4, "wait")
	h.check("with nothing, the clock and the action (%d)" % (before - c.patience),
		before - c.patience > 4)
