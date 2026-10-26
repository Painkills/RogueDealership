extends RefCounted
## The demand engine itself, driven with made-up Demands rather than authored
## ones, so these stay true when the archetypes get retuned. What the five
## shipped demands actually DO to you lives in test_actions.gd.
var h: Harness

func _cfg(overrides: Dictionary = {}) -> ShiftConfig:
	var cfg: ShiftConfig = (load("res://data/shift_config.tres") as ShiftConfig).duplicate()
	cfg.patience_jitter = 0
	cfg.action_cadence_jitter_ticks = 0
	cfg.arrival_patience_min_fraction = 1.0
	for k in overrides:
		cfg.set(k, overrides[k])
	return cfg

func _shift(floor_ids: Array, overrides: Dictionary = {}) -> Shift:
	return Shift.new(_cfg(overrides),
		load("res://data/interests/interest_pool.tres"),
		load("res://data/card_pool.tres"),
		load("res://data/archetype_pool.tres"), 1, floor_ids)

## Seated long enough to be allowed to ask. Imposed rather than waited for:
## the grace period is not what any of these tests are about.
func _sat_a_while(s: Shift, chair: int = 0) -> Customer:
	s.at = chair
	s.last_customer = s.chairs[chair]
	s.chairs[chair].ticks_on_floor = s.cfg.demand_grace_ticks
	var none: Array[CustomerAction] = []
	return _asks_for(s.chairs[chair], none)

## `c` with `actions` and nothing else of their own - these tests are about the
## demand engine, never about what any shipped archetype asks for. A copy:
## the loaded archetype is shared project-wide.
func _asks_for(c: Customer, actions: Array[CustomerAction]) -> Customer:
	c.archetype = c.archetype.duplicate()
	c.archetype.actions = actions
	c.action_state.clear()
	return c

func _made_up(ticks: int, resolve: DemandResolve, effects: Array[Effect],
		relief: Array[Effect] = []) -> Demand:
	var d := Demand.new()
	d.id = &"test_demand"
	d.display_name = "Wants a thing"
	d.telegraph = "THING?"
	d.dialogue_tags_met = [&"relief"]
	d.dialogue_tags_missed = [&"ignored"]
	d.ticks = ticks
	d.resolve = resolve
	d.effects = effects
	d.relief = relief
	return d

func _patience(n: int) -> Array[Effect]:
	var e := ChangePatience.new()
	e.amount = n
	var out: Array[Effect] = [e]
	return out

# ------------------------------------------------------------------ the fuse
func test_a_demand_comes_due_on_an_absolute_tick_not_a_countdown() -> void:
	## A countdown decremented inside _burn() would be wrong for a multi-tick
	## burn - Hard Close costs two - and this is the case that proves the fuse
	## is read against the clock rather than nudged by it.
	var s := _shift([&"easygoing"])
	var c := _sat_a_while(s)
	s.raise_demand(c, _made_up(3, PlayAnySupport.new(), _patience(-5)))
	var due: int = c.demand_due_tick
	h.eq("three ticks from now, in absolute terms", due, s.tick + 3)
	s._burn(2, "cards")
	h.check("two ticks in, still live", c.demand != null)
	s._burn(2, "cards")
	h.check("and a burn that overshoots still settles it", c.demand == null)

func test_a_demand_raised_during_a_burn_cannot_expire_on_that_same_burn() -> void:
	var s := _shift([&"easygoing"])
	var c := _sat_a_while(s)
	# ticks = 0 is the pathological author error this guards against.
	s.raise_demand(c, _made_up(0, PlayAnySupport.new(), _patience(-5)))
	h.check("a zero fuse is still at least one tick away",
		c.demand_due_tick > s.tick)

func test_running_out_of_time_fires_the_consequence() -> void:
	var s := _shift([&"easygoing"])
	var c := _sat_a_while(s)
	s.raise_demand(c, _made_up(1, PlayAnySupport.new(), _patience(-5)))
	var p: int = c.patience
	s._burn(1, "cards")
	h.check("the demand is gone", c.demand == null)
	h.eq("and it cost them", c.patience, p - 1 - 5)
	h.eq("counted as missed", int(s.stat["demands_missed"]), 1)
	h.eq("and not as met", int(s.stat["demands_met"]), 0)

# ------------------------------------------------------------------- throttles
func test_a_customer_only_ever_has_one_demand_at_a_time() -> void:
	var s := _shift([&"easygoing"])
	var c := _sat_a_while(s)
	var first := _made_up(5, PlayAnySupport.new(), _patience(-5))
	h.check("the first is raised", s.raise_demand(c, first))
	h.check("the second is refused",
		not s.raise_demand(c, _made_up(5, MakeAnOffer.new(), _patience(-5))))
	h.check("and the first is still the live one", c.demand == first)

func test_nobody_demands_anything_the_moment_they_sit_down() -> void:
	var s := _shift([&"easygoing"], {"demand_grace_ticks": 3})
	s.at = 0
	var c: Customer = s.chairs[0]
	h.check("straight off the street, no", not s.can_take_a_demand(c))
	c.ticks_on_floor = 3
	h.check("settled in, yes", s.can_take_a_demand(c))

func test_demands_do_not_come_back_to_back() -> void:
	var s := _shift([&"easygoing"], {"demand_cooldown_ticks": 4})
	var c := _sat_a_while(s)
	s.raise_demand(c, _made_up(1, PlayAnySupport.new(), _patience(-1)))
	s._burn(1, "cards")
	h.check("it settled", c.demand == null)
	h.check("and they cannot immediately ask again", not s.can_take_a_demand(c))
	s._burn(4, "cards")
	h.check("but they can once the cooldown is up", s.can_take_a_demand(c))

func test_a_throttled_customer_never_announces_an_ask_they_did_not_make() -> void:
	## fire() skips a demand-raising action wholesale rather than firing it and
	## quietly doing nothing, or the log would narrate an ask that never
	## happened and burn the action's own cadence doing it.
	var s := _shift([&"easygoing"], {"demand_grace_ticks": 99})
	var every := Every.new()
	every.ticks = 1
	var raise := RaiseDemand.new()
	raise.demand = _made_up(3, MakeAnOffer.new(), _patience(-1))
	var asks := CustomerAction.new()
	asks.id = &"asks_all_the_time"
	asks.display_name = "Asks all the time"
	asks.trigger = every
	var effects: Array[Effect] = [raise]
	asks.effects = effects
	var only: Array[CustomerAction] = [asks]
	for c in s.seated():
		_asks_for(c, only)
	s.at = 0
	s.last_customer = s.chairs[0]
	# Deliberately NOT _sat_a_while: it seats them exactly ON the grace line,
	# which is the thing this test needs them to be short of.
	s.chairs[0].ticks_on_floor = 0
	for _i in range(6):
		s.dig(0)
	h.eq("nothing was announced", s.action_log.size(), 0)
	h.check("and they are still in the chair, having asked for nothing",
		s.chairs[0] != null and s.chairs[0].demand == null)

# -------------------------------------------------------- major consequences
func test_walking_out_goes_through_the_one_path_anybody_leaves_by() -> void:
	## WalkOut sets patience to 0 and lets _settle_patience() do the leaving,
	## so it inherits the standing damage, the log line, the at-risk accounting
	## and _vacate() rather than reimplementing any of them.
	var s := _shift([&"easygoing"])
	var c := _sat_a_while(s)
	var out: Array[Effect] = [WalkOut.new()]
	s.raise_demand(c, _made_up(1, PlayAnySupport.new(), out))
	var standing: int = s.standing
	s._burn(1, "cards")
	h.check("the chair is empty", s.chairs[0] == null)
	h.eq("counted as a walkout", int(s.stat["customers_walked"]), 1)
	h.eq("and it cost standing like any other",
		s.standing, standing - s.cfg.standing_cost_per_walkout)

func test_a_demand_can_dock_standing_directly_and_end_the_run() -> void:
	var s := _shift([&"easygoing"], {"standing_start": 6})
	var c := _sat_a_while(s)
	var hit := ChangeStanding.new()
	hit.amount = -6
	var effs: Array[Effect] = [hit]
	s.raise_demand(c, _made_up(1, PlayAnySupport.new(), effs))
	h.check("plenty of clock left", s.tick < s.tick_budget - 1)
	s._burn(1, "cards")
	h.eq("standing reads exactly 0, never negative", s.standing, 0)
	h.check("and the shift is over on the spot", s.is_over())
	h.check("with ticks that were never spent", s.tick < s.tick_budget)

# ------------------------------------------------ give us a minute
func test_give_us_a_minute_breaks_only_on_something_played() -> void:
	## "Only if you play a card on them, not if you're still there when it ticks."
	var r := LeaveThemAlone.new()
	h.check("standing with them as the clock moves does not break it",
		not r.broken_by(DemandResolve.PRESENT, {}))
	for kind in [DemandResolve.SUPPORT, DemandResolve.PLACE, DemandResolve.OFFER, DemandResolve.CLOSE]:
		h.check("%s breaks it" % kind, r.broken_by(kind, {}))
	h.check("and waiting it out is the answer", r.succeeds_on_expiry())

# ------------------------------------------- a card that reaches the floor
## A support card whose effect gives the whole floor `n` patience, in your hand -
## made up, so it stays true whatever the shipped cards become.
func _floor_calm_in_hand(s: Shift, n: int) -> void:
	var e := ChangePatienceFloor.new()
	e.amount = n
	var def := SupportCardDef.new()
	def.id = &"made_up_floor_calm"
	def.display_name = "Made-up Floor Calm"
	def.needs_offer = false
	def.effects = [e]
	s.hand[0] = CardInstance.new(def, 9001)

## Two at the floor, you with the first; the second waiting on `resolve`.
func _asking_next_door(resolve: DemandResolve) -> Array:
	var s := _shift([&"easygoing", &"easygoing"])
	var here := _sat_a_while(s, 0)
	var there := _sat_a_while(s, 1)
	s.at = 0
	s.last_customer = here
	# Kept waiting a while, as anyone asking has been - room for patience to rise.
	there.patience = there.max_patience / 2
	here.patience = here.max_patience / 2
	s.raise_demand(there, _made_up(5, resolve, _patience(-5)))
	return [s, here, there]

func test_a_floor_wide_card_answers_a_patience_ask_at_another_seat() -> void:
	## "I was playing against 3 Karens and used Smooth Jazz ... the manager call
	## went off and I lost the customer despite playing a patience card (not on
	## the Karen who fired, but on the one at another seat)."
	var set := _asking_next_door(IncreasePatience.new())
	var s: Shift = set[0]
	var there: Customer = set[2]
	_floor_calm_in_hand(s, 4)
	var before := there.patience
	var r := s.play_card(0)
	h.check("played on the one you are with (%s)" % r.msg, r.ok)
	h.check("it reached the one next door (%d -> %d)" % [before, there.patience],
		there.patience > before)
	h.check("and answered their ask", there.demand == null)
	h.eq("counted as met", int(s.stat["demands_met"]), 1)

func test_a_floor_wide_card_is_not_a_card_played_on_the_others() -> void:
	var set := _asking_next_door(PlayAnySupport.new())
	var s: Shift = set[0]
	_floor_calm_in_hand(s, 4)
	s.play_card(0)
	h.check("an ask for a card played on THEM is still open", (set[2] as Customer).demand != null)
	var left := _asking_next_door(LeaveThemAlone.new())
	s = left[0]
	_floor_calm_in_hand(s, 4)
	s.play_card(0)
	h.check("and one to be left alone is not broken by it", (left[2] as Customer).demand != null)

# ------------------------------------------------ asked at full patience
## A made-up support card that gives `n` patience to the one it is played on -
## or does nothing at all, for n = 0.
func _card_in_hand(s: Shift, n: int, slot: int = 0) -> void:
	var def := SupportCardDef.new()
	def.id = &"made_up_calm_%d" % n
	def.display_name = "Made-up Calm"
	def.needs_offer = false
	if n != 0:
		var e := ChangePatience.new()
		e.amount = n
		def.effects = [e]
	s.hand[slot] = CardInstance.new(def, 9100 + slot)

## You with one customer, at full patience, asking for more.
func _full_and_asking() -> Array:
	var s := _shift([&"easygoing", &"easygoing"])
	var c := _sat_a_while(s, 0)
	c.patience = c.max_patience
	s.raise_demand(c, _made_up(5, IncreasePatience.new(), _patience(-5)))
	return [s, c]

func test_a_patience_card_answers_an_ask_made_at_full_patience() -> void:
	## "Make a patience card count even at full patience."
	var set := _full_and_asking()
	var s: Shift = set[0]
	var c: Customer = set[1]
	_card_in_hand(s, 3)
	s.play_card(0)
	h.check("it cannot raise them past their ceiling", c.patience <= c.max_patience)
	h.check("but it answers them", c.demand == null)
	h.eq("counted as met", int(s.stat["demands_met"]), 1)

func test_a_card_that_gives_no_patience_does_not_answer_it() -> void:
	var set := _full_and_asking()
	var s: Shift = set[0]
	_card_in_hand(s, 0)
	s.play_card(0)
	h.check("still asking", (set[1] as Customer).demand != null)

func test_at_full_patience_only_a_card_that_reached_them_answers_them() -> void:
	var s := _shift([&"easygoing", &"easygoing"])
	var here := _sat_a_while(s, 0)
	var there := _sat_a_while(s, 1)
	s.at = 0
	s.last_customer = here
	there.patience = there.max_patience
	s.raise_demand(there, _made_up(5, IncreasePatience.new(), _patience(-5)))
	_card_in_hand(s, 3)
	s.play_card(0)
	h.check("a patience card for the one you are with does not answer the one next door",
		there.demand != null)
	there.patience = there.max_patience
	_floor_calm_in_hand(s, 3)
	s.play_card(0)
	h.check("one that reaches the whole floor does, full or not", there.demand == null)

