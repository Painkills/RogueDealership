extends RefCounted
## Shift.forecast(): what a card's ticks would do, read off the table before it
## is played - and touching nothing while it looks. Made-up demands and cards
## throughout, so these stay true whatever the archetypes are tuned to.
var h: Harness

func _cfg(overrides: Dictionary = {}) -> ShiftConfig:
	var cfg: ShiftConfig = (load("res://data/shift_config.tres") as ShiftConfig).duplicate()
	cfg.patience_jitter = 0
	cfg.action_cadence_jitter_ticks = 0
	cfg.arrival_patience_min_fraction = 1.0
	for k in overrides:
		cfg.set(k, overrides[k])
	return cfg

## Two at the floor, you with the first, neither with anything of their own to
## do - the forecast is about countdowns, not about what an archetype asks.
func _shift(seed_value: int = 1, overrides: Dictionary = {}) -> Shift:
	var s := Shift.new(_cfg(overrides),
		load("res://data/interests/interest_pool.tres"),
		load("res://data/card_pool.tres"),
		load("res://data/archetype_pool.tres"), seed_value, [&"easygoing", &"easygoing"])
	for i in range(2):
		var c: Customer = s.chairs[i]
		c.archetype = c.archetype.duplicate()
		c.archetype.actions = [] as Array[CustomerAction]
		c.action_state.clear()
		c.ticks_on_floor = s.cfg.demand_grace_ticks
	s.at = 0
	s.last_customer = s.chairs[0]
	return s

func _demand(ticks: int, resolve: DemandResolve, effects: Array[Effect] = []) -> Demand:
	var d := Demand.new()
	d.id = &"made_up"
	d.display_name = "Wants a thing"
	d.telegraph = "THING?"
	d.ticks = ticks
	d.resolve = resolve
	d.effects = effects
	return d

func _patience(n: int) -> Array[Effect]:
	var e := ChangePatience.new()
	e.amount = n
	var out: Array[Effect] = [e]
	return out

## A made-up support card in hand slot 0: `gain` patience to whoever it is
## played on, costing `ticks`.
func _card(s: Shift, ticks: int, gain: int = 0) -> CardInstance:
	var def := SupportCardDef.new()
	def.id = &"made_up_card"
	def.display_name = "Made-up Card"
	def.needs_offer = false
	def.ticks = ticks
	if gain != 0:
		def.effects = _patience(gain)
	var inst := CardInstance.new(def, 9001)
	s.hand[0] = inst
	return inst

func _chair(f: Dictionary, i: int) -> Dictionary:
	return f["chairs"][i]

# ------------------------------------------------------------------ read-only
func test_forecasting_changes_nothing() -> void:
	var s := _shift()
	s.raise_demand(s.chairs[0], _demand(2, PlayAnySupport.new(), _patience(-3)))
	var inst := _card(s, 3, 2)
	var before := [s.tick, s.chairs[0].patience, s.chairs[1].patience, s.chairs[0].demand,
		s.chairs[0].demand_due_tick, s.chairs[0].patience_raises, s.commands.size(),
		s.hand.size(), s.events.size(), s.rng.state]
	s.forecast(3, 0, inst)
	s.forecast(99, 1, inst)
	var after := [s.tick, s.chairs[0].patience, s.chairs[1].patience, s.chairs[0].demand,
		s.chairs[0].demand_due_tick, s.chairs[0].patience_raises, s.commands.size(),
		s.hand.size(), s.events.size(), s.rng.state]
	h.eq("the shift is exactly as it was", after, before)

# ------------------------------------------------------------------ patience
func test_the_drain_comes_off_everyone() -> void:
	var s := _shift()
	var f := s.forecast(2)
	for i in range(2):
		h.eq("chair %d loses the ticks" % i, int(_chair(f, i)["patience_after"]),
			s.chairs[i].patience - 2)
	h.eq("and the clock moves on", int(f["tick_after"]), s.tick + 2)

func test_a_patience_card_counts_on_who_it_is_played_on_only() -> void:
	var s := _shift()
	s.chairs[0].patience = 4
	s.chairs[1].patience = 4
	var f := s.forecast(1, 0, _card(s, 1, 3))
	h.eq("theirs goes up before the drain", int(_chair(f, 0)["patience_after"]),
		mini(s.chairs[0].max_patience, 4 + roundi(3 * s.chairs[0].archetype.patience_card_scale)) - 1)
	h.eq("the other's does not", int(_chair(f, 1)["patience_after"]), 3)
	s.chairs[0].patience = s.chairs[0].max_patience
	f = s.forecast(1, 0, _card(s, 1, 3))
	h.eq("and never past their ceiling", int(_chair(f, 0)["patience_after"]),
		s.chairs[0].max_patience - 1)

func test_running_out_of_patience_walks_them_but_never_a_shield() -> void:
	var s := _shift()
	s.chairs[0].patience = 2
	h.check("2 ticks at 2 patience walks them", bool(_chair(s.forecast(2), 0)["walks"]))
	h.check("1 tick does not", not bool(_chair(s.forecast(1), 0)["walks"]))
	s.chairs[0].archetype.patience_is_shield = true
	h.check("a shield running out is not a walkout", not bool(_chair(s.forecast(2), 0)["walks"]))

# ------------------------------------------------------------------ demands
func test_a_fuse_inside_the_ticks_is_missed_and_one_outside_is_not() -> void:
	var s := _shift()
	s.raise_demand(s.chairs[1], _demand(2, PlayAnySupport.new()))
	h.eq("due in 2, 2 ticks: missed", _chair(s.forecast(2), 1)["misses"], "Wants a thing")
	h.eq("1 tick: not yet", _chair(s.forecast(1), 1)["misses"], "")

func test_a_card_that_answers_it_is_not_a_miss() -> void:
	var s := _shift()
	s.raise_demand(s.chairs[0], _demand(1, PlayAnySupport.new()))
	var inst := _card(s, 2)
	h.eq("played on them, it answers them", _chair(s.forecast(2, 0, inst), 0)["misses"], "")
	h.eq("played on someone else, they miss out",
		_chair(s.forecast(2, 1, inst), 0)["misses"], "Wants a thing")

func test_a_patience_raise_answers_a_patience_ask() -> void:
	var s := _shift()
	s.raise_demand(s.chairs[0], _demand(1, IncreasePatience.new()))
	h.eq("a patience card on them answers it", _chair(s.forecast(1, 0, _card(s, 1, 2)), 0)["misses"], "")
	h.eq("a card with no patience does not", _chair(s.forecast(1, 0, _card(s, 1)), 0)["misses"],
		"Wants a thing")

func test_leave_them_alone_is_met_by_waiting_and_broken_by_a_card() -> void:
	var s := _shift()
	s.raise_demand(s.chairs[0], _demand(2, LeaveThemAlone.new(), _patience(-3)))
	var inst := _card(s, 2)
	var away := _chair(s.forecast(2, 1, inst), 0)
	h.eq("left alone till it runs out: met", away["met"], "Wants a thing")
	h.eq("and not missed", away["misses"], "")
	var on := _chair(s.forecast(2, 0, inst), 0)
	h.eq("a card on them breaks it", on["breaks"], "Wants a thing")
	h.eq("and what breaking it costs is counted", int(on["patience_after"]),
		s.chairs[0].patience - 3 - 2)

func test_a_demand_that_walks_them_when_missed_says_so() -> void:
	var s := _shift()
	var out: Array[Effect] = [WalkOut.new()]
	s.raise_demand(s.chairs[1], _demand(1, MakeAnOffer.new(), out))
	var f := _chair(s.forecast(1), 1)
	h.check("missed", f["misses"] == "Wants a thing")
	h.check("and they walk with plenty of patience left", bool(f["walks"])
		and int(f["patience_after"]) > 0)

# ------------------------------------------------------------------ the bell
func test_the_bell_rings_exactly_at_the_budget() -> void:
	var s := _shift()
	var left := s.tick_budget - s.tick
	h.check("one short of it: no bell", not bool(s.forecast(left - 1)["bell"]))
	h.check("onto it: the bell", bool(s.forecast(left)["bell"]))
	h.eq("and it says what is unsigned", int(s.forecast(left)["unsigned_lost"]), s.margin_at_risk())
	s.has_clock = false
	h.check("no clock, no bell", not bool(s.forecast(left + 10)["bell"]))

# ------------------------------------------------------------------ agreement
func test_the_forecast_agrees_with_what_playing_the_card_does() -> void:
	## Twins from one seed: forecast on one, play on the other, compare.
	for gain in [0, 3]:
		var a := _shift(7)
		var b := _shift(7)
		for s in [a, b]:
			s.chairs[0].patience = 3
			s.chairs[1].patience = 2
			s.raise_demand(s.chairs[1], _demand(1, PlayAnySupport.new(), _patience(-1)))
		var f := a.forecast(2, 0, _card(a, 2, gain))
		var walked_before := int(b.stat.get("customers_walked", 0))
		var missed_before := int(b.stat.get("demands_missed", 0))
		_card(b, 2, gain)
		b.play_card(0)
		var walked := int(b.stat.get("customers_walked", 0)) - walked_before
		var predicted_walks := 0
		for i in range(2):
			if bool(_chair(f, i)["walks"]):
				predicted_walks += 1
		h.eq("gain %d: as many walk as it said" % gain, walked, predicted_walks)
		h.eq("gain %d: the miss it said happened" % gain,
			int(b.stat.get("demands_missed", 0)) - missed_before,
			1 if _chair(f, 1)["misses"] != "" else 0)
		if b.chairs[0] != null:
			h.eq("gain %d: their patience is what it said" % gain, b.chairs[0].patience,
				int(_chair(f, 0)["patience_after"]))
