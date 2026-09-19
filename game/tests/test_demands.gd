extends RefCounted
## The demand engine itself, driven with made-up Demands rather than authored
## ones, so these stay true when the archetypes get retuned. What the five
## shipped demands actually DO to you lives in test_actions.gd.
var h: Harness

func _cfg(overrides: Dictionary = {}) -> ShiftConfig:
	var cfg: ShiftConfig = (load("res://data/shift_config.tres") as ShiftConfig).duplicate()
	cfg.patience_jitter = 0
	cfg.prior_slip = 0.0
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

func _index_of(s: Shift, id: StringName) -> int:
	for i in range(s.hand.size()):
		if s.hand[i].card.id == id:
			return i
	return -1

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

# --------------------------------------------------------------- answering it
func test_playing_the_card_they_asked_for_answers_them() -> void:
	var s := _shift([&"easygoing"])
	var c := _sat_a_while(s)
	s.hand.clear()
	s.hand.append(CardInstance.new(s.card_pool.by_id(&"smalltalk"), 900))
	s.raise_demand(c, _made_up(3, PlayAnySupport.new(), _patience(-5),
		_patience(4)))
	s.play_card(0)
	h.check("answered", c.demand == null)
	h.eq("counted as met", int(s.stat["demands_met"]), 1)

func test_a_concession_is_defined_by_what_the_card_does_not_by_its_id() -> void:
	## PlayConcession reads the effects that actually executed, so every card
	## that gives money away answers it and a card that stops giving money away
	## stops answering it - without this file or that one knowing about it.
	var s := _shift([&"easygoing"])
	var c := _sat_a_while(s)
	s.hand.clear()
	s.hand.append(CardInstance.new(s.card_pool.by_id(&"vsc"), 900))
	s.hand.append(CardInstance.new(s.card_pool.by_id(&"explain"), 901))
	s.hand.append(CardInstance.new(s.card_pool.by_id(&"discount"), 902))
	s.place(0)
	s.raise_demand(c, _made_up(9, PlayConcession.new(), _patience(-5)))
	s.play_card(_index_of(s, &"explain"))
	h.check("Explain the Product costs them nothing, so it is no answer",
		c.demand != null)
	s.play_card(_index_of(s, &"discount"))
	h.check("Offer a Discount is money off, so it is", c.demand == null)

func test_asking_for_the_business_is_not_the_same_as_talking_at_them() -> void:
	var s := _shift([&"easygoing"])
	var c := _sat_a_while(s)
	c.line = 99
	s.hand.clear()
	s.hand.append(CardInstance.new(s.card_pool.by_id(&"vsc"), 900))
	s.hand.append(CardInstance.new(s.card_pool.by_id(&"explain"), 901))
	s.place(0)
	s.raise_demand(c, _made_up(9, MakeAnOffer.new(), _patience(-5)))
	s.play_card(_index_of(s, &"explain"))
	h.check("a support card does not count", c.demand != null)
	s.offer()
	h.check("being asked does", c.demand == null)

func test_offering_something_good_means_something_on_their_own_list() -> void:
	var s := _shift([&"easygoing"])
	var c := _sat_a_while(s)
	c.line = 99
	for iid in c.ranks:
		c.ranks[iid] = 9
	c.ranks[&"convenience"] = 8
	c.ranks[&"reliability"] = 1
	s.hand.clear()
	s.hand.append(CardInstance.new(s.card_pool.by_id(&"concierge"), 900))
	s.hand.append(CardInstance.new(s.card_pool.by_id(&"vsc"), 901))
	var resolve := OfferSomethingGood.new()
	resolve.rank_better_than = 3
	s.raise_demand(c, _made_up(9, resolve, _patience(-5)))

	s.place(_index_of(s, &"concierge"))
	s.offer()
	h.check("their 8th does not answer it", c.demand != null)
	s.drop_offer()
	s.place(_index_of(s, &"vsc"))
	s.offer()
	h.check("their 1st does", c.demand == null)

# ---------------------------------------------------------- leaving them alone
func test_leave_them_alone_is_answered_by_the_fuse_running_out() -> void:
	var s := _shift([&"easygoing", &"easygoing", &"easygoing"])
	var c := _sat_a_while(s)
	s.raise_demand(c, _made_up(2, LeaveThemAlone.new(), _patience(-5),
		_patience(4)))
	s.approach(1)                       # go and work somebody else - free
	# Headroom: add_patience() clamps at max_patience, and a relief that lands
	# on a full customer would prove nothing about whether it landed at all.
	c.patience = 10
	var p: int = c.patience
	s._burn(2, "cards")
	h.check("the minute is up", c.demand == null)
	h.eq("and it was the ANSWER, not the failure", int(s.stat["demands_met"]), 1)
	h.eq("so they are easier for it", c.patience, p - 2 + 4)

func test_standing_over_them_is_what_leave_them_alone_means_you_must_not_do() -> void:
	## The whole point of free movement. You cannot spend their minute standing
	## there doing nothing, because the clock only moves when you WORK - so the
	## only way to give it to them is to go and spend it on somebody else.
	var s := _shift([&"easygoing", &"easygoing", &"easygoing"])
	var c := _sat_a_while(s)
	s.raise_demand(c, _made_up(3, LeaveThemAlone.new(), _patience(-5),
		_patience(4)))
	var p: int = c.patience
	s._burn(1, "cards")                 # still standing at chair 0
	h.check("they noticed you never left", c.demand == null)
	h.eq("counted as missed", int(s.stat["demands_missed"]), 1)
	h.eq("and it cost them", c.patience, p - 1 - 5)

func test_a_minute_asked_for_while_you_stand_there_still_gets_its_minute() -> void:
	## Found by test_actions.gd, not by reasoning: a customer can raise their
	## demand on the very tick you happen to be standing with them, and the
	## first cut broke it on that same burn - costing patience for ignoring an
	## ask the player had not been shown yet. The presence notice runs BEFORE
	## the action pass so every demand gets one whole tick to exist.
	var s := _shift([&"easygoing", &"easygoing", &"easygoing"])
	var c := _sat_a_while(s)
	var demand := _made_up(3, LeaveThemAlone.new(), _patience(-5))
	# Raised from inside the burn, exactly as a trigger would raise it.
	var raiser := RaiseDemand.new()
	raiser.demand = demand
	var ctx := EffectContext.new()
	ctx.shift = s
	ctx.customer = c
	s._burn(1, "cards")
	raiser.apply(ctx)
	h.check("they asked", c.demand != null)
	h.check("and it survived the tick it was born on", c.demand != null)
	s._burn(1, "cards")
	h.check("the NEXT tick you spend standing there is the one that breaks it",
		c.demand == null)

func test_walking_away_and_coming_straight_back_does_not_count() -> void:
	var s := _shift([&"easygoing", &"easygoing", &"easygoing"])
	var c := _sat_a_while(s)
	s.raise_demand(c, _made_up(3, LeaveThemAlone.new(), _patience(-5)))
	s.approach(1)
	s.approach(0)                       # both free, neither moves the clock
	h.check("no work done, so nothing has happened yet", c.demand != null)
	s._burn(1, "cards")
	h.check("and the tick you spend back with them breaks it", c.demand == null)

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

func test_a_demand_can_sweep_your_product_off_the_table() -> void:
	var s := _shift([&"easygoing"])
	var c := _sat_a_while(s)
	s.hand.clear()
	s.hand.append(CardInstance.new(s.card_pool.by_id(&"vsc"), 900))
	s.place(0)
	h.check("something is on the table", c.offer != null)
	var agreed := {"product": s.card_pool.by_id(&"gap"), "margin": 1400, "bonus": 0}
	c.unsigned.append(agreed)
	var sweep: Array[Effect] = [DropOffer.new()]
	s.raise_demand(c, _made_up(1, PlayAnySupport.new(), sweep))
	var discarded: int = s.discard.size()
	s._burn(1, "cards")
	h.check("the table is clear", c.offer == null)
	h.eq("the card went to the discard rather than out of the deck",
		s.discard.size(), discarded + 1)
	h.eq("and what they had already agreed to is untouched",
		c.unsigned.size(), 1)

# ------------------------------------------------------------------ the log
func test_both_halves_of_a_demand_reach_the_log() -> void:
	var s := _shift([&"easygoing"])
	var c := _sat_a_while(s)
	s.hand.clear()
	s.hand.append(CardInstance.new(s.card_pool.by_id(&"smalltalk"), 900))
	s.raise_demand(c, _made_up(5, PlayAnySupport.new(), _patience(-5)))
	s.play_card(0)
	h.check("settling it was announced", s.action_log.size() >= 1)
	var entry: Dictionary = s.action_log[-1]
	h.check("named for the demand (%s)" % entry["name"],
		str(entry["name"]).contains("Wants a thing"))
	h.check("and says it was handled (%s)" % entry["name"],
		str(entry["name"]).to_lower().contains("handled"))

func test_an_ignored_demand_says_so_in_the_log() -> void:
	var s := _shift([&"easygoing"])
	var c := _sat_a_while(s)
	s.raise_demand(c, _made_up(1, PlayAnySupport.new(), _patience(-5)))
	s._burn(1, "cards")
	var entry: Dictionary = s.action_log[-1]
	h.check("flagged as ignored (%s)" % entry["name"],
		str(entry["name"]).contains("IGNORED"))
	h.check("and it says what that cost (%s)" % str(entry["descriptions"]),
		str(entry["descriptions"]).contains("Patience"))
