extends RefCounted
## What the five action-carrying archetypes actually DO to you.
##
## All five used to be passives: things that happened whether or not you
## engaged, which meant there was never anything to react to. They are Demands
## now - a timed ask, an answer, and a price for ignoring it - so every test
## here is shaped the same way: they ask, and then you either answer or pay.
## The engine underneath is tested with made-up demands in test_demands.gd.
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

## Ranks `iid` dead last (worst possible). Used against the Hawk, whose
## OnOffer trigger is a live balance knob - it may currently gate on how
## SHORT an offer falls or on how bad its RANK is (or both, or neither).
## Worst-on-both is the one setup that fires his demand no matter which
## dimension the trigger is tuned to read.
func _rank_worst(c: Customer, iid: StringName) -> void:
	var order: Array = NINE.duplicate()
	order.erase(iid)
	order.append(iid)
	_rank(c, order)

func _hand(s: Shift, ids: Array) -> void:
	s.hand.clear()
	var uid := 900
	for id in ids:
		s.hand.append(CardInstance.new(s.card_pool.by_id(id), uid))
		uid += 1

## Hand position is not stable once _draw_up() refills behind you.
func _index_of(s: Shift, id: StringName) -> int:
	for i in range(s.hand.size()):
		if s.hand[i].card.id == id:
			return i
	return -1

## Seated past the grace period, so the archetype's own cadence is the only
## thing deciding when they speak up.
func _sat_a_while(s: Shift, chair: int = 0) -> Customer:
	s.at = chair
	s.last_customer = s.chairs[chair]
	s.chairs[chair].ticks_on_floor = s.cfg.demand_grace_ticks
	return s.chairs[chair]

# ------------------------------------------------------------- Budget Hawk
func test_the_hawk_shops_you_the_moment_an_offer_falls_short() -> void:
	var s := _shift([&"hawk"])
	var c := _sat_a_while(s)
	# See test_the_hawk_shops_you_according_to_his_own_trigger for the version
	# that checks the trigger's own verdict at arbitrary ranks - this one just
	# needs a scenario guaranteed to fire it, whatever it's tuned to.
	_rank_worst(c, &"reliability")
	_hand(s, [&"vsc"])
	s.place(0)
	h.check("nothing to complain about yet", c.demand == null)
	s.offer()
	h.check("the worst possible offer gets him shopping", c.demand != null)
	h.eq("by name", c.demand.id, &"better_quote")
	h.check("and he does not wait long", c.demand.ticks > 0)

func test_the_hawk_sweeps_the_table_if_you_will_not_come_down() -> void:
	var s := _shift([&"hawk"])
	var c := _sat_a_while(s)
	_rank_worst(c, &"reliability")
	_hand(s, [&"vsc"])
	s.place(0)
	s.offer()
	h.check("he is shopping you", c.demand != null)
	var discarded: int = s.discard.size()
	# Dig (no concession) until the fuse runs out on its own, whatever length
	# it's currently tuned to - bounded so a stuck fuse fails loudly instead
	# of hanging.
	var guard := 0
	while c.demand != null and guard < 30:
		s.dig(0)
		guard += 1
	h.check("the fuse ran out", c.demand == null)
	h.check("and your product came off the table", c.offer == null)
	h.check("into the discard, not out of the deck",
		s.discard.size() >= discarded + 1)

func test_coming_down_on_the_price_sends_the_hawk_away_satisfied() -> void:
	var s := _shift([&"hawk"])
	var c := _sat_a_while(s)
	_rank_worst(c, &"reliability")
	_hand(s, [&"vsc", &"discount"])
	s.place(0)
	s.offer()
	h.check("he is shopping you", c.demand != null)
	s.play_card(_index_of(s, &"discount"))
	h.check("money off answers him", c.demand == null)
	h.check("and your product stays where it is", c.offer != null)

func test_the_hawk_shops_you_according_to_his_own_trigger() -> void:
	## His trigger config (short_at / rank_worse_than) is a live balance knob -
	## already retuned twice in one afternoon while this suite was being
	## audited. Rather than this test assuming one specific configuration,
	## build the same rank/short pair the model computes, ask his own
	## OnOffer.matches() what SHOULD happen, and confirm the shift agrees -
	## so whatever the trigger is dialed to right now, this keeps testing
	## "the trigger decides, and the shift obeys it" rather than a snapshot.
	var hawk_arch := (load("res://data/archetype_pool.tres") as ArchetypePool).by_id(&"hawk")
	var trigger := hawk_arch.actions[0].trigger

	for rank in [1, 9]:
		var s := _shift([&"hawk"])
		var c := _sat_a_while(s)
		var others: Array = []
		for iid in NINE:
			if iid != &"reliability":
				others.append(iid)
		_rank(c, others.slice(0, rank - 1) + [&"reliability"])
		_hand(s, [&"vsc"])
		s.place(0)
		var appeal := c.appeal_for(&"reliability")
		var short: int = maxi(0, c.line - appeal)

		var probe := EffectContext.new()
		probe.rank = rank
		probe.short = short
		var should_demand: bool = trigger.matches(probe)

		s.offer()
		h.eq("rank %d (%d short): the trigger's own verdict matches what happened"
			% [rank, short], c.demand != null, should_demand)

# -------------------------------------------------------------- Tire Kicker
## The cadence itself (how many ticks the Kicker waits before speaking up) is
## a live balance knob - see restless.tres - so these dig in a bounded loop
## until the demand actually appears, rather than assuming today's tuning.
func _dig_until_demanded(s: Shift, c: Customer, cap: int = 30) -> void:
	var guard := 0
	while c.demand == null and guard < cap:
		s.dig(0)
		guard += 1

func test_the_tire_kicker_asks_for_a_price() -> void:
	var s := _shift([&"kicker", &"easygoing"])
	var c := _sat_a_while(s)
	_dig_until_demanded(s, c)
	h.check("now he wants a number", c.demand != null)
	h.eq("by name", c.demand.id, &"restless")

func test_the_tire_kicker_walks_if_you_never_ask_for_the_business() -> void:
	## The major tier. He does not bleed you slowly any more - he leaves, and a
	## walkout has always cost standing, so the consequences chain by
	## themselves rather than being restated here.
	var s := _shift([&"kicker", &"easygoing"])
	var c := _sat_a_while(s)
	_dig_until_demanded(s, c)
	h.check("he asked", c.demand != null)
	var standing: int = s.standing
	var walked: int = int(s.stat["customers_walked"])
	h.check("with patience to spare - this is the demand, not the clock",
		c.patience > 3)
	var guard := 0
	while s.chairs[0] != null and guard < 30:
		s.dig(0)
		guard += 1
	h.check("the chair is empty", s.chairs[0] == null)
	h.eq("counted as a walkout", int(s.stat["customers_walked"]), walked + 1)
	h.eq("so it cost standing like any other",
		s.standing, standing - s.cfg.standing_cost_per_walkout)

func test_asking_the_tire_kicker_for_the_business_settles_him() -> void:
	var s := _shift([&"kicker", &"easygoing"])
	var c := _sat_a_while(s)
	_dig_until_demanded(s, c)
	h.check("he asked", c.demand != null)
	c.line = 99                                       # so the offer misses
	_hand(s, [&"vsc"])
	s.place(0)
	s.offer()
	h.check("being asked is the whole demand - he did not need to say yes",
		c.demand == null)
	h.check("and he is still in the chair", s.chairs[0] != null)

# ---------------------------------------------------------- Tech Enthusiast
func test_the_tech_enthusiast_asks_to_see_something_from_their_own_top_three() -> void:
	var s := _shift([&"tech"])
	var c := _sat_a_while(s)
	_dig_until_demanded(s, c)
	h.check("they want to see the good stuff", c.demand != null)
	h.eq("by name", c.demand.id, &"show_me")

func test_showing_the_tech_enthusiast_the_good_stuff_is_worth_it() -> void:
	## Tech is one of the two archetypes the design rule keeps in the player's
	## favour, so their demand is an OPPORTUNITY with a deadline: the relief is
	## the point and the miss is nominal. Checks the DIRECTION of the relief
	## (margin goes up), not its exact size - that size is a balance knob (see
	## show_me.tres's relief effect). Offering fails on purpose here (line 99),
	## so the only thing that could move the margin at all is the relief.
	var s := _shift([&"tech"])
	var c := _sat_a_while(s)
	c.line = 99                                       # the offer misses on purpose
	_rank(c, [&"reliability"])                        # vsc is their number one
	_dig_until_demanded(s, c)
	h.check("they asked", c.demand != null)
	_hand(s, [&"vsc"])
	s.place(0)
	var before_margin: int = c.offer.margin
	s.offer()
	h.check("their own number one answers them", c.demand == null)
	h.check("and it pads the still-open offer (%d -> %d)"
		% [before_margin, c.offer.margin], c.offer.margin > before_margin)

## The bug this guards: offer() calls _settle() BEFORE the demand resolves,
## so when the same offer that satisfies "show me your top 3" also clears
## his Line, c.offer is already null by the time the relief runs. A relief
## effect that only knows how to touch ctx.offer (ChangeMargin) would
## silently no-op there even though the log claimed it landed - this is the
## far more common case in real play, since a top-3 pick easily clears a
## Line low enough to have been worth offering at all.
func test_showing_the_tech_enthusiast_the_good_stuff_is_worth_it_even_when_it_also_sells() -> void:
	var s := _shift([&"tech"])
	var c := _sat_a_while(s)
	c.line = 0                                        # guarantees it also sells
	_rank(c, [&"reliability"])                        # vsc is their number one
	_dig_until_demanded(s, c)
	h.check("they asked", c.demand != null)
	_hand(s, [&"vsc"])
	s.place(0)
	var base_margin: int = s.card_pool.by_id(&"vsc").margin
	s.offer()
	h.check("their own number one answers them", c.demand == null)
	h.eq("it sold in the same offer", c.unsigned.size(), 1)
	h.check("and the relief landed on the sale, not a dead offer reference (%d > %d)"
		% [c.unsigned_margin(), base_margin], c.unsigned_margin() > base_margin)

func test_ignoring_the_tech_enthusiast_only_costs_a_little() -> void:
	var s := _shift([&"tech"])
	var c := _sat_a_while(s)
	_dig_until_demanded(s, c)
	h.check("they asked", c.demand != null)
	var p: int = c.patience
	var guard := 0
	while c.demand != null and guard < 30:
		s.dig(0)
		guard += 1
	h.check("the fuse ran out", c.demand == null)
	h.check("and it cost a bit more than the clock alone", c.patience < p - guard)
	h.check("they are still in the chair", s.chairs[0] != null)

func test_junk_does_not_satisfy_the_tech_enthusiast() -> void:
	var s := _shift([&"tech"])
	var c := _sat_a_while(s)
	c.line = 99
	_rank(c, [&"reliability", &"equity", &"stability", &"security",
		&"affordability", &"convenience"])            # convenience 6th
	_dig_until_demanded(s, c)
	h.check("they asked", c.demand != null)
	_hand(s, [&"concierge"])
	s.place(0)
	s.offer()
	h.check("their sixth is not what they asked to see", c.demand != null)

# ------------------------------------------------------------- Family First
func test_family_first_asks_for_a_minute_to_talk_it_over() -> void:
	var s := _shift([&"family", &"easygoing", &"easygoing"])
	var c := _sat_a_while(s)
	_dig_until_demanded(s, c)
	h.check("they need a minute", c.demand != null)
	h.eq("by name", c.demand.id, &"thinking")

func test_hovering_over_family_first_is_what_costs_you() -> void:
	var s := _shift([&"family", &"easygoing", &"easygoing"])
	var c := _sat_a_while(s)
	_dig_until_demanded(s, c)
	h.check("they asked for a minute", c.demand != null)
	var p: int = c.patience
	s.dig(0)                                          # and you stayed put
	h.check("staying put broke it", c.demand == null)
	h.check("at a real cost, not just the clock's own tick", c.patience < p - 1)

func test_giving_family_first_the_minute_brings_them_back_easier() -> void:
	## The clearest expression of why walking is free: you cannot give them
	## their minute by standing still, because standing still does not move the
	## clock. You have to go and spend it on somebody else.
	var s := _shift([&"family", &"easygoing", &"easygoing"])
	var c := _sat_a_while(s)
	_dig_until_demanded(s, c)
	h.check("they asked for a minute", c.demand != null)
	s.approach(1)
	h.eq("walking over cost nothing", int(s.stat["ticks_approach"]), 0)
	var p: int = c.patience
	var guard := 0
	while c.demand != null and guard < 30:
		s.dig(0)                                      # working somebody else
		guard += 1
	h.check("the minute is up, and they are content", c.demand == null)
	h.check("and they came back with MORE patience than the clock alone cost them",
		c.patience > p - guard)

# ----------------------------------------------------------------- The Karen
func test_the_karen_asks_for_the_manager_and_means_it() -> void:
	var s := _shift([&"karen", &"easygoing", &"easygoing"])
	var c := _sat_a_while(s)
	_dig_until_demanded(s, c)
	h.check("she asks for the manager", c.demand != null)
	h.eq("by name", c.demand.id, &"manager")

func test_ignoring_the_karen_costs_the_whole_floor_and_your_standing() -> void:
	## The major tier, and the second source of direct standing damage after a
	## walkout. What used to be an unanswerable tax is now a decision. Checks
	## the SHAPE of the consequence (standing takes a hit, she pays only the
	## clock, everyone else pays the clock plus her tax) rather than the exact
	## magnitudes, which live in manager.tres.
	var s := _shift([&"karen", &"easygoing", &"easygoing"])
	var c := _sat_a_while(s)
	_dig_until_demanded(s, c)
	h.check("she asked", c.demand != null)
	var standing: int = s.standing
	var hers: int = c.patience
	var theirs: int = s.chairs[1].patience
	var guard := 0
	while c.demand != null and guard < 30:
		s.dig(0)
		guard += 1
	h.check("the fuse ran out", c.demand == null)
	h.check("your standing took the complaint", s.standing < standing)
	h.eq("she pays only the clock", c.patience, hers - guard)
	h.check("everyone else pays more than just the clock",
		s.chairs[1].patience < theirs - guard)
	h.eq("and so does C", s.chairs[2].patience, s.chairs[1].patience)

func test_coming_down_on_the_price_gets_the_karen_off_your_back() -> void:
	var s := _shift([&"karen", &"easygoing", &"easygoing"])
	var c := _sat_a_while(s)
	_dig_until_demanded(s, c)
	h.check("she asked", c.demand != null)
	_hand(s, [&"vsc", &"discount"])
	s.place(0)
	var standing: int = s.standing
	s.play_card(_index_of(s, &"discount"))
	h.check("money off answers her", c.demand == null)
	h.eq("and your standing is untouched", s.standing, standing)

func test_the_karen_still_will_not_sign_outside_her_category() -> void:
	## demands_category is a standing gate on close(), not a timed ask. Both are
	## true of her, which is why they keep names a letter apart rather than
	## being folded into one another.
	var s := _shift([&"karen", &"easygoing", &"easygoing"])
	var c := _sat_a_while(s)
	h.check("she came in for something specific", c.demands_category != null)
	h.check("and says so on arrival", c.known_top_category == c.demands_category)
	h.check("closing is refused until she has it", not s.close().ok)

# ------------------------------------------------------------------- quiet
func test_the_quiet_archetypes_never_do_anything() -> void:
	for id in [&"easygoing", &"laydown"]:
		var s := _shift([id, id])
		var c := _sat_a_while(s)
		c.line = 99
		_rank(c, [&"status", &"power", &"reliability"])
		_hand(s, [&"vsc"])
		s.place(0)
		s.offer()
		s.offer()
		for _i in range(6):
			s.dig(0)
		h.eq("%s does nothing to you" % id, s.action_log.size(), 0)
		h.check("%s never asks for anything" % id, c.demand == null)

# ----------------------------------------------------------- announcements
func test_raising_a_demand_is_announced_with_its_fuse_and_its_price() -> void:
	## "Asks for the manager" is an event. "Asks for the manager, 3 ticks to
	## give them something off the price" is a decision, and the log is the
	## only place the fuse is stated before stage 5 puts it on the card.
	var s := _shift([&"karen", &"easygoing", &"easygoing"])
	var c := _sat_a_while(s)
	_dig_until_demanded(s, c)
	h.check("something was announced", s.action_log.size() >= 1)
	var fuse: int = c.demand.ticks
	var entry: Dictionary = s.action_log[0]
	h.check("it names the customer", str(entry["customer"]) != "")
	h.check("it carries dialogue", str(entry["dialogue"]) != "")
	var said: String = str(entry["descriptions"])
	h.check("it telegraphs the ask (%s)" % said, said.contains("MANAGER"))
	h.check("it states the fuse (%s, expected %d ticks)" % [said, fuse],
		said.contains("%d ticks" % fuse))
	h.check("and how to answer it", said.to_lower().contains("price"))

func test_a_floor_wide_consequence_is_flagged_when_it_lands() -> void:
	## Raising the demand is not floor-wide; what it costs when ignored is. The
	## flag is computed where the effects actually run, which is why it is
	## false on the ask and true on the bill.
	var s := _shift([&"karen", &"easygoing", &"easygoing"])
	var c := _sat_a_while(s)
	_dig_until_demanded(s, c)
	h.check("the ask is not itself floor-wide",
		not bool(s.action_log[0]["floor_wide"]))
	var guard := 0
	while c.demand != null and guard < 30:
		s.dig(0)
		guard += 1
	var bill: Dictionary = s.action_log[-1]
	h.check("but ignoring it is (%s)" % bill["name"], bool(bill["floor_wide"]))
	h.check("and it says so (%s)" % str(bill["descriptions"]),
		str(bill["descriptions"]).to_lower().contains("everyone else"))

func test_a_self_only_consequence_is_not_flagged_floor_wide() -> void:
	var s := _shift([&"kicker", &"easygoing"])
	var c := _sat_a_while(s)
	_dig_until_demanded(s, c)
	h.check("the kicker asked", s.action_log.size() >= 1)
	h.check("but not on the whole floor",
		not bool(s.action_log[0]["floor_wide"]))

func test_actions_fired_is_counted() -> void:
	var s := _shift([&"karen", &"easygoing", &"easygoing"])
	var c := _sat_a_while(s)
	_dig_until_demanded(s, c)
	h.check("the counter moved", int(s.stat["actions_fired"]) >= 1)
