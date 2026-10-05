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
	return s.chairs[chair]

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
	var s := _shift([&"kicker", &"easygoing"], {"demand_grace_ticks": 99})
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
