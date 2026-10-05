class_name Shift extends RefCounted
## One shift on the floor. The pure rules core: no Node, no scene, no signal.
## The headless suite and the game drive this identical object, so they cannot
## drift.

const CHAIR_KEYS := "ABCDEFGH"

var cfg: ShiftConfig
var interests: InterestPool
var card_pool: CardPool
var archetypes: ArchetypePool
var dialogue: DialoguePool          ## may be null - a shift with no lines is silent
var rng := RandomNumberGenerator.new()
## Everything anybody SAYS - your lines, their replies, their chatter, what an
## action or a demand makes them say - is picked from its own stream, seeded
## from the shift's, so speaking draws nothing from `rng`: adding lines, or
## giving a card or a customer something to say, never changes who walks in
## next or what they want.
var voice_rng := RandomNumberGenerator.new()

var tick: int = 0
var tick_budget: int
var quota: int
var shift_number: int = 1          ## which shift of the run; gates archetypes
## All three set from a picked ShiftProfile, see RunState.start_shift() -
## none of them changes anything about a Shift built without one (1.0, 1.0
## and false are the no-op values), so every existing call site is
## unaffected.
var patience_scale: float = 1.0
var walk_up_scale: float = 1.0
var unlock_full_archetype_pool: bool = false
## The share of what you bank over quota paid on top of base salary - the
## picked ShiftProfile's commission. Nothing here uses it but report(); see
## RunState.bonus_from().
var commission: float = 0.25
## The picked ShiftProfile's pay_scale - see paycheck().
var pay_scale: float = 1.0
## The picked ShiftProfile's heal_up_to - see healed().
var heal_up_to: float = 0.0
## The picked ShiftProfile's hard_weight_scale, allow_hard_duplicates and
## archetype_weight_scales - see _pick_archetype().
var hard_weight_scale: float = 1.0
var allow_hard_duplicates: bool = false
var archetype_weight_scales: Dictionary = {}
## The boss's product quota for this shift: sell `category_quota_count` products
## from the `category_quota` category, or lose ShiftConfig.category_quota_standing
## at the end. &"" / 0 when there is none. Set by RunState.start_shift().
var category_quota: StringName = &""
var category_quota_name: String = ""
var category_quota_count: int = 0
## Products from that category signed so far - counted as they are banked.
var category_sold: int = 0
## The run's dealership upgrades - see DealershipUpgrade and perk(). Read as
## the floor opens, so set through the constructor, never afterwards.
var dealership: Array[DealershipUpgrade] = []
## Who never comes in on this shift - ShiftProfile.excluded_archetypes.
var excluded_archetypes: Array[CustomerArchetype] = []
## A premade shift's own customers - see ShiftProfile.only_archetypes and
## lineup. Both empty on any other shift.
var only_archetypes: Array[CustomerArchetype] = []
var lineup: Array[CustomerArchetype] = []
var _lineup_next: int = 0
var margin_banked: int = 0
## The run's HP, LIVE during this shift - seeded from RunState.standing at
## construction (0 means "use cfg's own start", the run is never legitimately
## AT 0 when a new shift begins, since the run would already be over). A
## walkout docks it immediately, in _walk(), not just at report() time - see
## is_over() below.
var standing: int
var _initial_standing: int
var _standing_lost_to_walkouts: int = 0

var chairs: Array = []
## Who is waiting for a chair, first come first seated. Archetypes only: nobody
## is anybody in particular until they sit down (see _spawn()). The floor shows
## this, so whether to keep working someone difficult or get them signed and
## out can depend on who is waiting to take their place.
var waiting: Array[CustomerArchetype] = []
## Ticks until the next customer comes in the door and joins the wait. Holds
## while the waiting list is full - see _arrive().
var next_arrival: int = 0
var at = null                      ## chair index you are standing at, or null
var last_customer = null           ## going back to them is free

var draw: Array[CardInstance] = []
var discard: Array[CardInstance] = []
var hand: Array[CardInstance] = []
var reshuffles: int = 0
## Non-null between PullCards.apply() staging a reveal and choose_pull()/
## cancel_pull() resolving it - see PendingPull's own comment. _draw_up()
## refuses to refill while this is set (the pull owns the next hand slot),
## and the view locks card dragging while it is set (see
## shift_controller.gd's set_hud_dimmed-adjacent drag lock).
var pending_pull: PendingPull = null

var events: Array[String] = []
var action_log: Array[Dictionary] = []
## Every line YOU have said this shift, in order - one per card you played
## that had something to say (see _speak()). The view drains it the way it
## drains events and puts the newest in your own bubble.
var player_lines: Array[String] = []
var stat: Dictionary = {}
var lost_to_walks: int = 0
var served: int = 0

## The run-long "closed without a walkout" streak, carried in from RunState at
## construction exactly like standing - one customer signing bumps it, one
## customer walking (anywhere on the floor, not just theirs) zeroes it.
## sale_streak_events is the ordered sequence of streak values THIS shift's
## own closes landed on - Score reads it to turn "how long was each streak"
## into points without Shift itself knowing anything about scoring.
## Unrelated to Customer.combo_step / Shift.peak_combo_multiplier below - this
## is a floor-wide, cross-shift streak, not the per-customer margin combo.
var sale_streak: int = 0
var sale_streak_events: Array[int] = []

## The highest per-sale combo multiplier (Customer.combo_step x prior sales
## this visit) reached anywhere in this shift - Score reads it, the same way
## it reads sale_streak_events, to turn "what happened" into points without
## Shift knowing anything about scoring. 1.0 (no bonus) is the floor, not 0 -
## nobody ever scores WORSE than the no-combo baseline for this category.
var peak_combo_multiplier: float = 1.0

var _forced: Array = []
var _forced_next: int = 0
var _name_pool: Array = []


func _init(p_cfg: ShiftConfig, p_interests: InterestPool, p_cards: CardPool,
		p_arch: ArchetypePool, p_seed: int, p_forced: Array = [],
		p_deck: Deck = null, p_quota: int = 0, p_shift_number: int = 1,
		p_standing: int = 0, p_sale_streak: int = 0,
		p_dialogue: DialoguePool = null, p_floor_size: int = 0,
		p_patience_scale: float = 1.0, p_walk_up_scale: float = 1.0,
		p_unlock_full_archetype_pool: bool = false,
		p_only_archetypes: Array = [], p_lineup: Array = [],
		p_excluded_archetypes: Array = [], p_arrivals: Dictionary = {},
		p_dealership: Array = []) -> void:
	cfg = p_cfg
	dealership.assign(p_dealership)
	# A bigger hand is the config's own number, so everything that deals to it
	# reads one figure - on a copy, never the run's.
	var hand_bonus := int(perk(&"hand_size"))
	if hand_bonus != 0:
		cfg = cfg.duplicate() as ShiftConfig
		cfg.hand_size = maxi(1, cfg.hand_size + hand_bonus)
	# Who the door sends - ShiftProfile's hard_weight_scale,
	# allow_hard_duplicates and archetype_weight_scales. Set before the floor
	# opens, so the first customers are picked under them like everyone after.
	hard_weight_scale = float(p_arrivals.get("hard_weight_scale", 1.0))
	allow_hard_duplicates = bool(p_arrivals.get("allow_hard_duplicates", false))
	archetype_weight_scales = (p_arrivals.get("archetype_weight_scales", {}) as Dictionary).duplicate()
	interests = p_interests
	card_pool = p_cards
	archetypes = p_arch
	# Injected, never load()ed: scripts/model and scripts/run touch nothing on
	# disk, which is what lets the suite swap any pool for a double. A shift
	# built without one still LOGS every support card - it just says nothing
	# while doing it.
	dialogue = p_dialogue
	rng.seed = p_seed
	voice_rng.seed = hash(p_seed)
	_forced = p_forced
	shift_number = p_shift_number
	patience_scale = p_patience_scale
	walk_up_scale = p_walk_up_scale
	unlock_full_archetype_pool = p_unlock_full_archetype_pool
	only_archetypes.assign(p_only_archetypes)
	lineup.assign(p_lineup)
	excluded_archetypes.assign(p_excluded_archetypes)

	tick_budget = cfg.shift_ticks
	# The run climbs the quota shift over shift; a bare shift uses the config's.
	quota = p_quota if p_quota > 0 else cfg.quota
	standing = p_standing if p_standing > 0 else cfg.standing_start
	_initial_standing = standing
	sale_streak = p_sale_streak
	for key in ["cards_played", "offers", "failed_offers", "offers_dropped",
			"sales", "places", "digs", "approaches", "actions_fired",
			"ticks_cards", "ticks_place", "ticks_digs", "ticks_approach",
			"margin_conceded", "margin_padded", "margin_bonus",
			"customers_signed", "customers_walked",
			"demands_met", "demands_missed"]:
		stat[key] = 0

	# A picked ShiftProfile (see RunState.start_shift()) may put fewer chairs
	# in use than the floor has - ShiftProfile.seats - but never more, since
	# the floor has no others. 0 means "no override", the config decides, same
	# sentinel convention p_quota/p_standing already use above.
	var floor_size: int = mini(p_floor_size, cfg.floor_size) if p_floor_size > 0 \
		else cfg.floor_size
	chairs.resize(floor_size)
	for i in range(floor_size):
		chairs[i] = null

	# The run hands in its own deck, carrying whatever the shop did to it. A
	# shift built without one deals the fixed starter deck, exactly as before.
	var deck := p_deck if p_deck != null else Deck.build_starting(card_pool)
	draw = deck.cards.duplicate()
	_shuffle(draw)
	_draw_up()

	for i in range(floor_size):
		var arch := _pick_archetype()
		if arch == null:
			break        # a lineup shorter than the floor leaves the rest empty
		_spawn(i, arch)
	# The shift opens with you sat at A - not out on a floor with nobody to
	# work yet. Seated at whoever is there, or at an empty chair a short lineup
	# left; either way the first customer to arrive there finds you.
	if not chairs.is_empty():
		at = 0
		last_customer = chairs[0]
	# Whoever the dealership's upgrades have already waiting at opening - in
	# the queue, or straight into a chair a short lineup left empty.
	var brought_forward := 0
	for u in dealership:
		if u == null:
			continue
		for arch in u.waiting_at_open:
			if arch != null and waiting.size() < cfg.waiting_max:
				waiting.append(arch)
				if u.counts_against_door:
					brought_forward += 1
	_seat_the_waiting()
	if not chairs.is_empty() and last_customer == null:
		last_customer = chairs[0]
	# The floor opens full, and nobody the door sent is waiting yet: the first to come in
	# after opening does so on the same clock as everyone after them.
	next_arrival = _arrival_gap()
	# Each customer already waiting who stands in for the door's next one puts
	# its next arrival back by a gap of its own - DealershipUpgrade.counts_against_door.
	for _i in range(brought_forward):
		next_arrival += _arrival_gap()


## One of DealershipUpgrade's bonuses, summed over every upgrade the run owns.
func perk(field: StringName) -> float:
	return DealershipUpgrade.total(dealership, field)


func seated() -> Array:
	var out := []
	for c in chairs:
		if c != null:
			out.append(c)
	return out


func is_over() -> bool:
	## Standing hitting 0 mid-shift ends it immediately, the same as running out
	## of ticks - checked here rather than only at report() time so the very
	## next _apply() (already checking is_over() after every command) shows the
	## report the instant the walkout that did it finishes resolving.
	return tick >= tick_budget or standing <= 0


func margin_at_risk() -> int:
	var total := 0
	for c in seated():
		total += c.unsigned_margin()
	return total


## The shift-wide counterpart to Customer.leaving_soon() - that one warns you
## a PERSON is about to walk; this one warns the whole FLOOR is about to close,
## taking every unsigned deal on it with it (see report()'s
## margin_lost_to_closing). False once the shift is already over - there is
## nothing left to warn about by then.
func ticks_running_low() -> bool:
	return not is_over() and (tick_budget - tick) <= cfg.low_tick_warning


## How many ticks until the next customer comes in, or -1 if nobody will
## before closing time - including while the waiting list is full, since the
## door's clock waits then (see _arrive()), and once a lineup has sent everyone
## in it. Due ON the closing tick is too late: _burn() lets nobody in once the
## shift is over.
func next_arrival_in() -> int:
	if is_over() or door_closed() or waiting.size() >= cfg.waiting_max \
			or next_arrival >= tick_budget - tick:
		return -1
	return next_arrival


## A premade shift's lineup has sent in everyone on it: nobody else is coming
## today, and once the floor is empty the shift is done.
func door_closed() -> bool:
	return not lineup.is_empty() and _lineup_next >= lineup.size()


# ------------------------------------------------------------------ the tick
func _burn(n: int, kind: String) -> void:
	## The single choke point for time. Effects have ALREADY resolved by the
	## time this runs - m0's discovered rule, that you close during your turn
	## and the damage lands after. Small Talk can therefore save someone at 1
	## patience, and a sale can land on the tick that would have walked them.
	if n <= 0:
		return
	tick += n
	var key := "ticks_" + kind
	stat[key] = int(stat.get(key, 0)) + n

	for c in seated():
		c.patience -= n
		c.ticks_on_floor += n

	# Standing with someone while the clock moves IS doing something to them -
	# it is precisely what "give us a minute" is asking you not to do.
	#
	# BEFORE the action pass, and that ordering is load-bearing: a customer can
	# raise a demand on this very tick, and if this ran afterwards their "give us
	# a minute" would break on the same burn that created it, while you were
	# still being told about it. Every demand gets at least one whole tick to
	# exist, for the same reason the fuse is stored as an absolute due-tick.
	if at != null and chairs[at] != null:
		_demand_saw(chairs[at], DemandResolve.PRESENT)

	# Cadenced actions fire after the burn, so someone already leaving does not
	# get a parting shot.
	for c in seated():
		if c.patience > 0:
			fire(&"every", c)
			fire(&"patience_below", c)

	# Fuses come due AFTER actions and BEFORE patience settles, so a WalkOut
	# consequence leaves down the one path a customer has ever left by.
	# seated() hands back a fresh array, and nothing here vacates a chair, so
	# settling inside the loop is safe.
	for c in seated():
		if c.demand != null and tick >= c.demand_due_tick:
			_settle_demand(c, c.demand.resolve != null \
				and c.demand.resolve.succeeds_on_expiry())

	_settle_patience()

	if not is_over():
		_arrive(n)


## The door. Somebody comes in every few ticks, whoever is on the floor, and
## takes an empty chair if there is one or waits for one if not - so a slow
## floor builds a queue, and getting someone signed and out brings in whoever
## is next. Nobody comes in while the waiting list is full; the door's clock
## waits with them.
func _arrive(n: int) -> void:
	if door_closed() or waiting.size() >= cfg.waiting_max:
		return
	next_arrival -= n
	while next_arrival <= 0 and waiting.size() < cfg.waiting_max and not door_closed():
		waiting.append(_pick_archetype())
		_seat_the_waiting()
		next_arrival += _arrival_gap()
	# The list filled with more still due: they went elsewhere, and the clock
	# starts over for the next one.
	if next_arrival <= 0:
		next_arrival = _arrival_gap()


## Ticks between one customer coming in and the next. Rolled fresh each time,
## not a fixed wait: a door that always opened on the same tick told you
## exactly when to be looking at it, the opposite of the triage the floor is
## for. A night ShiftProfile stretches it - see ShiftProfile.walk_up_scale -
## so fewer distinct customers come in across the same tick budget.
func _arrival_gap() -> int:
	return maxi(1, roundi(rng.randi_range(
		cfg.walk_up_ticks_min, cfg.walk_up_ticks_max) * walk_up_scale))


## Every empty chair takes whoever has waited longest, straight away.
func _seat_the_waiting() -> void:
	if is_over():
		return
	for i in range(chairs.size()):
		if waiting.is_empty():
			return
		if chairs[i] == null:
			_spawn(i, waiting.pop_front())


func _settle_patience() -> void:
	## Anything that touches patience outside a tick still has to check the
	## door. Every patience mutation in the engine ends here.
	for i in range(chairs.size()):
		if chairs[i] != null and chairs[i].patience <= 0:
			_walk(i)
	# One log line per ENTRY into the danger zone, not one per tick spent in
	# it - re-armed the instant patience climbs back out, so a genuine second
	# scare still warns. A customer this pass just walked out of is already
	# gone from seated(), so they cannot also log a stale warning here.
	for c in seated():
		if c.leaving_soon():
			if not c.warned_leaving_soon:
				c.warned_leaving_soon = true
				events.append("[%s] %s is losing patience." % [c.key, c.display_name])
		else:
			c.warned_leaving_soon = false
		# And out loud, a little before that: "a dialogue line for when a
		# customer reaches 5 or less patience." Once per dip, re-armed the same
		# way - a customer grumbling every tick is noise, one grumbling once is
		# a person telling you who needs you next.
		if c.patience <= cfg.impatient_at:
			if not c.said_impatient:
				c.said_impatient = true
				_chatter(c, [&"impatient"])
		else:
			c.said_impatient = false


func _walk(chair: int) -> void:
	var c = chairs[chair]
	c.patience = 0
	c.state = "walked"
	var lost: int = c.unsigned_margin()
	lost_to_walks += lost
	stat["customers_walked"] = int(stat["customers_walked"]) + 1
	sale_streak = 0   # one walkout, anywhere on the floor, breaks the streak
	if c.offer != null:
		discard.append(c.offer.instance)
		c.offer = null
	events.append("[%s] %s walks out%s." % [c.key, c.display_name,
		" with $%d unsigned" % lost if lost > 0 else ""])
	# Immediate, not deferred to report() - the whole point of costing standing
	# per walkout is that it should sting the moment it happens, not show up as
	# a surprise on a screen five minutes later. maxi() rather than a bare
	# subtraction so a walkout can never be the thing that makes standing READ
	# negative, only the thing that makes is_over() true.
	var before := standing
	standing = maxi(0, standing - cfg.standing_cost_per_walkout)
	_standing_lost_to_walkouts += before - standing
	events.append("Standing -%d (now %d/%d)." \
		% [before - standing, standing, cfg.standing_start])
	_vacate(chair)


func _vacate(chair: int) -> void:
	chairs[chair] = null
	# You are NOT unseated: `at` stays on this chair, now empty, and whoever
	# sits down next takes it with you already there. Nothing moves you off a
	# seat but your own choice - approach() to another, or leave().
	# Whoever is waiting takes the chair now, not a few ticks from now - that is
	# what getting a difficult customer out for them buys.
	_seat_the_waiting()


## Seats `arch` in `chair`, or whoever the door would send if no one is named -
## how the floor fills when the shift opens.
func _spawn(chair: int, arch: CustomerArchetype = null) -> void:
	if arch == null:
		arch = _pick_archetype()
	# patience_scale is the picked ShiftProfile's, not the archetype's own -
	# applied AFTER jitter, so a midday customer is still "this archetype,
	# a little worse," not a different roll entirely.
	var top: int = max(1, roundi((arch.patience
		+ rng.randi_range(-cfg.patience_jitter, cfg.patience_jitter)) * patience_scale))

	# Nobody is guaranteed to walk in fresh. Some are already partway to the
	# door, which is triage pressure from the moment they sit down. Floored so
	# an arrival is never dead on arrival.
	var start: int = int(round(top * rng.randf_range(
		cfg.arrival_patience_min_fraction, 1.0)))
	start = max(min(top, cfg.arrival_patience_floor), start)
	# The dealership's own comfort on top of all that - more to work with, and
	# more of it to start from.
	var comfort := int(perk(&"patience"))
	top = maxi(1, top + comfort)
	start = clampi(start + comfort, 1, top)

	# Someone who demands a category comes in for one at random, and its
	# interests are their three favourites - what she wants is what she wants.
	var wanted: Category = null
	var favourites: Array[Interest] = []
	if arch.demands_category and not interests.categories.is_empty():
		wanted = interests.categories[rng.randi_range(0, interests.categories.size() - 1)]
		favourites = interests.in_category(wanted)
	var c := Customer.new(CHAIR_KEYS[chair], _next_name(), arch,
		Customer.make_ranks(arch, interests, rng, cfg.prior_slip, favourites),
		start, top, cfg.as_dict(), interests)
	var easier := int(perk(&"line"))
	if easier != 0:
		c.line = maxi(0, c.line + easier)
		c.start_line = c.line
	c.combo_step += perk(&"combo_step")

	# Every-triggered actions start their cadence counter jittered, not at a
	# clean 0, so this customer's first demand does not land on the exact same
	# tick every other one of their archetype's ever has - see fire()'s "every"
	# branch, which reads this as "when it last fired" and never touches it
	# again until the action actually does.
	for act in arch.actions:
		if act.trigger is Every:
			c.action_state[act.id] = rng.randi_range(
				-cfg.action_cadence_jitter_ticks, cfg.action_cadence_jitter_ticks)

	if arch.demands_category:
		c.demands_category = wanted.id if wanted != null \
			else interests.by_id(c.top_interest_id()).category.id
		c.known_top_category = c.demands_category      # they say so, loudly

	chairs[chair] = c
	served += 1
	events.append("[%s] %s walks up - %s."
		% [c.key, c.display_name, arch.display_name])


## Who comes in next - null only once a lineup has sent everyone on it.
func _pick_archetype() -> CustomerArchetype:
	if not _forced.is_empty():
		var id = _forced[_forced_next % _forced.size()]
		_forced_next += 1
		return archetypes.by_id(id)
	# A premade shift's lineup is exactly who comes, in its order, and nobody
	# after - no uniqueness rule, no ladder, no second pass.
	if not lineup.is_empty():
		if door_closed():
			return null
		_lineup_next += 1
		return lineup[_lineup_next - 1]
	var pool := _archetypes_available_this_shift()
	if cfg.unique_archetypes_on_floor and not allow_hard_duplicates:
		# The waiting list counts as the floor: they are who sits down next.
		# Only the hard ones are kept to one at a time.
		var taken := {}
		for c in seated():
			taken[c.archetype.id] = true
		for a in waiting:
			taken[a.id] = true
		var fresh: Array[CustomerArchetype] = []
		for a in pool:
			if not (a.hard and taken.has(a.id)):
				fresh.append(a)
		if not fresh.is_empty():
			pool = fresh
	return _weighted_archetype(pool)


## One of `pool`, by CustomerArchetype.weight - the hard ones scaled by this
## shift's hard_weight_scale. Evenly, if every weight comes to nothing.
func _weighted_archetype(pool: Array[CustomerArchetype]) -> CustomerArchetype:
	var total := 0.0
	for a in pool:
		total += _weight_of(a)
	if total <= 0.0:
		return pool[rng.randi_range(0, pool.size() - 1)]
	var roll := rng.randf() * total
	for a in pool:
		roll -= _weight_of(a)
		if roll < 0.0:
			return a
	return pool[pool.size() - 1]


func _weight_of(a: CustomerArchetype) -> float:
	return maxf(0.0, a.weight) * (hard_weight_scale if a.hard else 1.0) \
		* maxf(0.0, float(archetype_weight_scales.get(a.id, 1.0)))


func _archetypes_available_this_shift() -> Array[CustomerArchetype]:
	## The difficulty ladder. Falls back to the whole pool rather than returning
	## nothing: misauthored min_shift values would otherwise index an empty array
	## and take the game down, and a floor that is too hard beats no floor at all.
	##
	## A night ShiftProfile skips the ladder entirely - the whole pool is fair
	## game regardless of which real shift number this is, which is the actual
	## point of picking night rather than a side effect of it.
	##
	## A premade shift that names its customers skips it too: they are who comes,
	## whatever the day.
	##
	## Whoever the shift excludes is taken out of whichever pool that is - unless
	## that would leave nobody, when the exclusion gives way the way the ladder
	## does.
	var pool: Array[CustomerArchetype] = []
	if not only_archetypes.is_empty():
		pool = only_archetypes.duplicate()
	elif unlock_full_archetype_pool:
		pool = archetypes.archetypes.duplicate()
	else:
		for a in archetypes.archetypes:
			if a.min_shift <= shift_number:
				pool.append(a)
		if pool.is_empty():
			pool = archetypes.archetypes.duplicate()
	if excluded_archetypes.is_empty():
		return pool
	var kept: Array[CustomerArchetype] = []
	kept.assign(pool.filter(func(a): return not excluded_archetypes.has(a)))
	return kept if not kept.is_empty() else pool


func _next_name() -> String:
	if _name_pool.is_empty():
		_name_pool = archetypes.names.duplicate()
		_shuffle(_name_pool)
	return _name_pool.pop_back()


# ----------------------------------------------------------------------- deck
func _draw_up() -> void:
	# A pull owns the next hand slot - refilling it blind here first would
	# leave choose_pull() nowhere to put the card you actually picked.
	# cancel_pull() calls this again once the pull clears, to fill it the
	# normal way after all.
	if pending_pull != null:
		return
	while hand.size() < cfg.hand_size:
		if draw.is_empty():
			if discard.is_empty():
				return
			_recycle_discard()
		# The floor needs a product for this slot and the pile has none left to
		# give. Pull the discard back in NOW rather than deal a support card and
		# lapse: placed products drain into the discard as the shift runs, so by
		# mid-shift the pile goes product-free while still holding plenty of
		# support - which is exactly when a dead hand hurts most. Waiting for the
		# pile to empty on its own would make the floor lapse at the worst time.
		if _needs_a_product() and _top_product_index() < 0 and _discard_has_product():
			_recycle_discard()
		# Index 0, not appended: FanCardLayout renders hand[0] leftmost with no
		# reordering of its own, so this is the whole rule for "a freshly drawn
		# card appears on the left."
		hand.insert(0, draw.pop_at(_next_draw_index()))


func _recycle_discard() -> void:
	## Merged rather than assigned: the early recycle above runs while the pile
	## still holds support cards, and replacing it outright would delete them
	## from the deck.
	draw.append_array(discard)
	discard.clear()
	_shuffle(draw)
	reshuffles += 1


func _needs_a_product() -> bool:
	## True once the slots left to fill are down to the product deficit itself -
	## so a hand that draws products on its own never triggers the bias, and the
	## shuffle stays honest right up to the last card.
	return cfg.hand_min_products - _products_in_hand() \
		>= cfg.hand_size - hand.size()


func _next_draw_index() -> int:
	## The top of the pile, unless taking it would strand the hand under
	## hand_min_products - in which case the draw reaches PAST support cards for
	## the nearest product instead.
	var top: int = draw.size() - 1
	if not _needs_a_product():
		return top
	var found: int = _top_product_index()
	# -1 here means no product exists anywhere in circulation - every one of them
	# is sitting in an offer on the table - so there is nothing to conjure and the
	# top card is the honest answer. Spelled out because pop_at(-1) would pop the
	# top card anyway and hide the miss.
	return found if found >= 0 else top


func _products_in_hand() -> int:
	var n := 0
	for c in hand:
		if c.is_product():
			n += 1
	return n


func _discard_has_product() -> bool:
	## Gates the early recycle on it being able to HELP. Without this, a deck whose
	## every product is sitting in an offer would reshuffle on every single draw
	## and find nothing each time.
	for c in discard:
		if c.is_product():
			return true
	return false


func _top_product_index() -> int:
	## Scanned from the top down, so the bias takes the product NEAREST the top
	## and disturbs the shuffle as little as it can.
	for i in range(draw.size() - 1, -1, -1):
		if draw[i].is_product():
			return i
	return -1


func discard_random_from_hand(n: int) -> void:
	for _i in range(n):
		if hand.is_empty():
			return
		discard.append(hand.pop_at(rng.randi_range(0, hand.size() - 1)))
	_draw_up()


func _shuffle(arr: Array) -> void:
	## Array.shuffle() uses the GLOBAL rng. Never use it.
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


# --------------------------------------------------------------------- commands
func _here() -> Array:
	## [customer, refusal]. Every action with a customer starts here.
	if is_over():
		return [null, Result.new(false, "The floor is closed.")]
	# A pull is a choice you owe: a second card played over it would stage a
	# second pull on top and the first one's revealed cards would be gone from
	# the deck for good. The view locks its own input for the same reason; this
	# is the rule itself, so nothing that reaches the model can get round it.
	if pending_pull != null:
		return [null, Result.new(false, PULL_FIRST)]
	if at == null:
		return [null, Result.new(false,
			"You have to go stand with someone first.")]
	var c = chairs[at]
	if c == null:
		return [null, Result.new(false, "Nobody is sitting there.")]
	return [c, null]


func approach(chair: int) -> Result:
	## Walking is FREE. The clock measures work - cards, digs, waiting for the
	## door - not distance. Charging a tick to go and look at someone made the
	## cheapest play "finish whoever you are with and never look up", which is
	## the exact opposite of a game about deciding who deserves the next tick.
	##
	## cfg.approach_ticks survives at 0 rather than being deleted, so the charge
	## is one number away if free movement turns out to be too loose. What does
	## NOT survive is the old discount for returning to last_customer: an
	## asymmetry that made coming back cheaper than going was the shape of the
	## tunnel vision, so if the charge ever comes back it comes back uniform.
	if is_over():
		return Result.new(false, "The floor is closed.")
	if chair < 0 or chair >= chairs.size():
		return Result.new(false, "No such chair.")
	if chairs[chair] == null:
		return Result.new(false, "Nobody is sitting there.")
	if at == chair:
		return Result.new(false, "You are already standing with %s."
			% chairs[chair].display_name)
	var c = chairs[chair]
	at = chair
	last_customer = c
	stat["approaches"] = int(stat["approaches"]) + 1
	# _burn() no-ops on 0, so the default costs nothing and spends no branch.
	_burn(cfg.approach_ticks, "approach")
	return Result.new(true, "You walk over to %s." % c.display_name, "move")


func leave() -> Result:
	if at == null:
		return Result.new(false, "You are already out on the floor.")
	at = null
	return Result.new(true, "You step back out onto the floor.", "move")


func wait() -> Result:
	## The only command that moves the clock without a customer, and it exists
	## for exactly one state: every chair empty.
	##
	## Everything else that burns a tick needs somebody to burn it on - approach,
	## place, support, offer, close - and the one exception, dig, reaches the
	## clock only through your hand, which is not on screen while you are out on
	## the floor. So the last customer walking out of a floor with empty chairs
	## used to stop time permanently: nothing to press, nobody to approach, and a
	## tick counter that would never reach the end of the shift.
	##
	## Refused while anybody is still seated, deliberately. Being able to skip
	## time at will is a different game - the pressure a Karen puts on the whole
	## floor only means anything if you cannot simply wait her out.
	if is_over():
		return Result.new(false, "The floor is closed.")
	if not seated().is_empty():
		return Result.new(false,
			"There are people on the floor - go and sell to them.")

	var n := _ticks_until_the_door_opens()
	events.append("... %d ticks later ..." % n)
	_burn(n, "wait")
	return Result.new(true, "%d ticks later." % n, "wait", {"ticks": n})


func _ticks_until_the_door_opens() -> int:
	## The next arrival, or whatever is left of the shift if nobody is due
	## before it ends - or ever, once a lineup is done: the last of them leaving
	## is the end of the day. Never less than one: _burn ignores a zero, and a
	## wait that does not move the clock is the deadlock it was written to break.
	var left: int = tick_budget - tick
	return maxi(1, left if door_closed() else mini(left, next_arrival))


func play_card(index: int) -> Result:
	var pair := _here()
	if pair[1] != null:
		return pair[1]
	if index < 0 or index >= hand.size():
		return Result.new(false, "No such card.")
	if hand[index].is_product():
		return place(index)
	return _support(pair[0], index)


func place(index: int) -> Result:
	## Costs a tick and shows only a BAND. Placing is the price of information
	## here - reading a priority list by putting products in front of people
	## costs the same as any other read in the game.
	var pair := _here()
	if pair[1] != null:
		return pair[1]
	var c: Customer = pair[0]
	if index < 0 or index >= hand.size():
		return Result.new(false, "No such card.")
	var inst: CardInstance = hand[index]
	if not inst.is_product():
		return Result.new(false, "%s is not a product." % inst.card.display_name)
	if c.offer != null:
		return Result.new(false,
			"The %s is already on the table - offer it or drop it."
			% c.offer.product.display_name)
	if c.owns(inst.card.id):
		return Result.new(false, "%s already took the %s."
			% [c.display_name, inst.card.display_name])

	var product := inst.card as ProductCardDef
	var iid: StringName = product.interest.id
	var rank: int = int(c.ranks[iid])
	c.offer = Offer.new(inst, c.appeal_for(iid),
		roundi(inst.margin() * (1.0 + perk(&"margin"))))
	# A new product is a new conversation: whatever they objected to about the
	# last one went with it.
	c.objection = &""
	# Your pitch as it goes down, before any effect of its own lands - the same
	# moment _support() speaks at.
	_speak(product.player_dialogue_tags, c, product.id,
		StringName(band_for(c.line - c.offer.appeal)))

	# A product's own effects, if it was authored with any - the same loop
	# _support() runs, so a product is no longer required to be pure
	# appeal-and-margin data. Empty (every shipped product today) is a no-op.
	var effects: Array[Effect] = product.upgraded_effects \
		if inst.upgraded and not product.upgraded_effects.is_empty() else product.effects
	if not effects.is_empty():
		var ctx := _yours(c, product)
		var descriptions: Array[String] = []
		var floor_wide := false
		for e in effects:
			e.apply(ctx)
			var d := e.describe()
			if d != "":
				descriptions.append(d)
			if _is_floor_wide(e):
				floor_wide = true
		action_log.append({
			"key": c.key,
			"customer": c.display_name,
			"name": product.display_name,
			"dialogue": "",
			"descriptions": descriptions if not descriptions.is_empty() \
				else ["nothing you could point at"],
			"floor_wide": floor_wide,
		})

	# The band is read AFTER the effects land, not before - a product whose
	# own effect moves appeal should draw the band that reflects where the
	# offer actually landed, the same rule _support()'s own comment states.
	var band := band_for(c.line - c.offer.appeal)
	hand.remove_at(index)
	stat["places"] = int(stat["places"]) + 1
	_draw_up()
	# Placing teaches nothing the player can see - rank stays hidden, unlike
	# offer()'s known_ranks reveal - but an archetype can still react to it
	# internally, the same way OnOffer already reacts to a rank you never see.
	fire(&"on_place", c, {"rank": rank})
	_demand_saw(c, DemandResolve.PLACE, {"product": product})
	# After their archetype has had its say, so the objection is what is left
	# in the bubble - and read against the Line as it stands after that, which
	# an archetype's own reaction may just have moved.
	_object(c, product)
	_burn(cfg.place_ticks, "place")
	return Result.new(true, "You put the %s in front of %s."
		% [product.display_name, c.display_name], "place", {"band": band})


## Shared by place() and _support(): an effect that hits the whole floor
## rather than just this customer gets the log's red "floor_wide" treatment
## instead of the ordinary purple one. One place to extend as more
## floor-wide verbs join ChangePatienceFloor/ChangeLineFloorWide, rather than
## this list drifting out of sync between the two callers.
func _is_floor_wide(e: Effect) -> bool:
	return e is ChangePatienceFloor or e is ChangeLineFloorWide


## What you say to `c`: a line from `tags` (a card's player_dialogue_tags, or
## the close offer() says itself), narrowed the way a customer's is - by who
## you are talking to, the product on the table, its band and the objection
## you are answering - onto player_lines. Drawn from voice_rng, never rng (see
## voice_rng).
func _speak(tags: Array[StringName], c: Customer, product_id: StringName,
		band: StringName) -> DialogueLine:
	if dialogue == null or tags.is_empty():
		return null
	var l := dialogue.pick_line(voice_rng, tags, c.archetype.id, product_id, band,
		_objection_of(c), player_lines.slice(-RECENT_LINES))
	if l == null:
		return null
	player_lines.append(l.text)
	_open(c, l)
	return l


## What every command says while a pull is waiting on your choice.
const PULL_FIRST := "Choose one of the revealed cards first, or put them back."

## How many of a speaker's latest lines a new one steers clear of repeating -
## see DialoguePool.pick_line()'s `avoid`.
const RECENT_LINES := 4

## Remembers what `c` just said, so they do not say it again straight away.
func _heard(c: Customer, said: String) -> void:
	c.recent_lines.append(said)
	if c.recent_lines.size() > RECENT_LINES:
		c.recent_lines = c.recent_lines.slice(-RECENT_LINES)


## What they object to, while there is still something on the table to object
## to. Whatever takes the product off it - a sale, a drop, a walkout, an
## archetype sweeping it away - ends the conversation about it, without every
## one of those having to remember to say so.
func _objection_of(c: Customer) -> StringName:
	return c.objection if c.offer != null else &""


## A line that, once said, opens or moves their objection - DialogueLine.becomes.
func _open(c: Customer, l: DialogueLine) -> void:
	if l.becomes != &"":
		c.objection = l.becomes


## What they say about the product you just put in front of them. Under their
## Line it is an objection from the product's objection_tags - "It's too
## expensive" - which stays open while you work through it; already over it,
## something warm - the INTERESTED band. Drawn from voice_rng, like your own
## lines.
func _object(c: Customer, product: ProductCardDef) -> void:
	if dialogue == null or c.offer == null:
		return
	var tags: Array[StringName] = [&"interested"]
	if c.offer.appeal < c.line:
		tags = product.objection_tags
	var l := dialogue.pick_line(voice_rng, tags, c.archetype.id, product.id,
		StringName(band_for(c.line - c.offer.appeal)), &"", c.recent_lines)
	if l == null:
		return
	_log_words(c, l.text)
	_open(c, l)


func _support(c: Customer, index: int) -> Result:
	var inst: CardInstance = hand[index]
	var def := inst.card as SupportCardDef
	if def.needs_offer and c.offer == null:
		return Result.new(false, "%s needs something on the table."
			% def.display_name)
	# Yours is read off the table as you reach for the card, before its effects
	# land; their reply below reads it after.
	var yours := _speak(def.player_dialogue_tags, c, c.offer.product.id if c.offer else &"",
		StringName(band_for(c.line - c.offer.appeal)) if c.offer else &"")

	var ctx := _yours(c, def)
	var effects: Array[Effect] = def.upgraded_effects \
		if inst.upgraded and not def.upgraded_effects.is_empty() else def.effects
	var before_margin: int = c.offer.margin if c.offer else 0
	var patience_before: int = c.patience
	# One pass, the same one fire() and _settle_demand() make: apply, collect
	# what to say it did, and notice a floor-wide hit while we are here.
	var descriptions: Array[String] = []
	var floor_wide := false
	for e in effects:
		e.apply(ctx)
		var d := e.describe()
		if d != "":
			descriptions.append(d)
		if _is_floor_wide(e):
			floor_wide = true
	if descriptions.is_empty():
		descriptions.append("nothing you could point at")

	if c.offer:
		var delta: int = c.offer.margin - before_margin
		if delta < 0:
			c.offer.conceded = true
			stat["margin_conceded"] = int(stat["margin_conceded"]) - delta
		elif delta > 0:
			stat["margin_padded"] = int(stat["margin_padded"]) + delta
		c.offer.applied.append(def.display_name)

	# What they say back. The band is read AFTER the effects land, not before:
	# a card that lifts them COOL to WARM should draw a WARM line, because
	# they are reacting to where they are now, not where they were. With
	# nothing on the table both the product and the band read as &"", and
	# DialogueLine.fits() excludes every line that names either - so a card
	# played on an empty table falls back to the unfiltered lines instead of
	# talking about a car that is not there. With an objection open, the reply
	# written for it - and what it becomes, where answering it flushes out the
	# real one ("No thanks" turning out to be the price).
	var said := ""
	if dialogue != null and not def.dialogue_tags.is_empty():
		var product_id: StringName = c.offer.product.id if c.offer else &""
		var band: StringName = StringName(band_for(c.line - c.offer.appeal)) \
			if c.offer else &""
		# An answer to what you just said, where you said something with a key
		# - or silence, never a non sequitur (DialogueLine.key).
		var reply := dialogue.pick_line(voice_rng, def.dialogue_tags, c.archetype.id,
			product_id, band, _objection_of(c), c.recent_lines,
			yours.key if yours != null else &"")
		if reply != null:
			said = reply.text
			_heard(c, said)
			_open(c, reply)
	# Appended even when nothing was said, and even when the card is untagged:
	# until now playing a support card produced NO log line at all, while
	# every archetype action did. Same shape fire() appends, so _drain_log()
	# renders it and pops the speech bubble without knowing a card from an
	# objection.
	#
	# MUST stay above _demand_saw(): settling a demand appends its own entry,
	# and test_demands.gd's test_both_halves_of_a_demand_reach_the_log reads
	# action_log[-1] expecting to find THAT one, not this one.
	action_log.append({
		"key": c.key,
		"customer": c.display_name,
		"name": def.display_name,
		"dialogue": said,
		"descriptions": descriptions,
		"floor_wide": floor_wide,
	})

	hand.remove_at(index)
	discard.append(inst)
	stat["cards_played"] = int(stat["cards_played"]) + 1
	_draw_up()
	# Before the burn, so playing the card they asked for answers them rather
	# than racing the very tick it costs to play it.
	_demand_saw(c, DemandResolve.SUPPORT, {"card": def, "effects": effects,
		"patience_before": patience_before})
	_settle_patience()
	_burn(def.ticks, "cards")
	return Result.new(true, def.display_name + ".", "support")


func offer() -> Result:
	## Free in time. What it costs is exposure: a short offer bruises their
	## patience and is what provokes whatever this archetype does.
	var pair := _here()
	if pair[1] != null:
		return pair[1]
	var c: Customer = pair[0]
	if c.offer == null:
		return Result.new(false, "There is nothing on the table to offer.")

	var o = c.offer
	var iid: StringName = o.product.interest.id
	var rank: int = int(c.ranks[iid])
	var gap: int = max(0, c.line - o.appeal)
	# The trial close - asking is what you say, before they answer, and it
	# closes on whatever they were objecting to where a close was written for it.
	_speak([&"player_close"], c, o.product.id, StringName(band_for(c.line - o.appeal)))

	# Offering teaches you the RANK of what you just put in front of them, and
	# nothing about their Line. It used to set known_line too, which made Read
	# the Room a convenience rather than the only way to see the number - ask
	# once and the fog was gone for the rest of the shift, for free. The gap is
	# still true in the model; detail_card_3d.gd decides how much of it you see.
	o.revealed = true
	c.known_ranks[iid] = rank
	stat["offers"] = int(stat["offers"]) + 1

	# They evaluate at the Line they had when you ASKED. A Hawk's reaction to
	# being asked cannot retroactively sink an offer that already cleared.
	var patience_before: int = c.patience
	var sale := _settle(c)
	if not sale.is_empty():
		# They say yes out loud, about the product they just took where a line
		# was written for it - before anything their archetype does about it,
		# which is what happens next.
		_chatter(c, [&"accepted"], sale["product"].id)
		fire(&"on_sale", c, {"rank": rank, "sale": sale})
	else:
		stat["failed_offers"] = int(stat["failed_offers"]) + 1
		c.patience -= cfg.failed_offer_patience
		# Turned down for want of a concession, not for appeal: say so, or
		# nothing on screen tells the player what would have worked.
		if o.appeal >= c.line and holds_out_for_a_concession(c):
			_chatter(c, [&"wants_concession"], o.product.id)

	fire(&"on_offer", c, {"rank": rank, "short": gap, "sale": sale})
	_demand_saw(c, DemandResolve.OFFER, {"rank": rank, "short": gap, "sale": sale,
		"patience_before": patience_before})
	_settle_patience()

	if not sale.is_empty():
		return Result.new(true, "%s takes the %s - $%d."
			% [c.display_name, sale["product"].display_name, sale["margin"]],
			"sale", {"rank": rank, "margin": sale["margin"],
				"bonus": sale.get("bonus", 0)})
	# Exact on purpose, and NOT player-facing: _apply() logs a Result's message
	# only when it is a refusal. The model always knows the true gap; the fog
	# lives in the view, which is the only place that can decide how much of it
	# a player has earned the right to see.
	return Result.new(true, "%d SHORT." % gap, "miss",
		{"short": gap, "rank": rank})


func _settle(c: Customer) -> Dictionary:
	## Accept the moment appeal reaches the Line - never above it, so a card
	## that overshoots is margin you threw away.
	var o = c.offer
	if o == null or o.appeal < c.line or holds_out_for_a_concession(c):
		return {}
	# c.sales is PRIOR sales this visit only - it has not been incremented
	# for this one yet, so the first sale always multiplies by exactly 1.0.
	var multiplier: float = 1.0 + c.combo_step * c.sales
	peak_combo_multiplier = maxf(peak_combo_multiplier, multiplier)
	var margin := roundi(o.margin * multiplier)
	var sale := {"product": o.product, "margin": margin, "bonus": 0,
		"combo_margin": margin - o.margin}
	c.unsigned.append(sale)
	c.sales += 1
	c.line += c.line_per_sale
	c.add_patience(cfg.patience_per_sale)
	discard.append(o.instance)
	c.offer = null
	c.objection = &""
	stat["sales"] = int(stat["sales"]) + 1
	events.append("[%s] agrees to %s - unsigned%s."
		% [c.key, sale["product"].display_name,
			" (×%.1f combo)" % multiplier if multiplier > 1.0 else ""])
	return sale


## True while what is on their table is outside their top
## CustomerArchetype.needs_concession_past_rank and nothing has been conceded
## on it - "not accept anything under their top 5 unless there's a concession."
func holds_out_for_a_concession(c: Customer) -> bool:
	var past: int = c.archetype.needs_concession_past_rank
	if past <= 0 or c.offer == null or c.offer.conceded:
		return false
	return int(c.ranks[c.offer.product.interest.id]) > past


func drop_offer() -> Result:
	## Free. The ticks that built this offer are already spent - charging again
	## for admitting it failed would just tax you for being wrong.
	var pair := _here()
	if pair[1] != null:
		return pair[1]
	var c: Customer = pair[0]
	if c.offer == null:
		return Result.new(false, "There is nothing on the table.")
	var product_name: String = c.offer.product.display_name
	discard.append(c.offer.instance)
	c.offer = null
	c.objection = &""
	stat["offers_dropped"] = int(stat["offers_dropped"]) + 1
	return Result.new(true,
		"You take the %s back off the table." % product_name, "drop")


func dig(index: int) -> Result:
	## Rummage for the right pitch. The floor pays for it either way.
	if is_over():
		return Result.new(false, "The floor is closed.")
	if pending_pull != null:
		return Result.new(false, PULL_FIRST)
	if index < 0 or index >= hand.size():
		return Result.new(false, "No such card.")
	var inst: CardInstance = hand.pop_at(index)
	discard.append(inst)
	stat["digs"] = int(stat["digs"]) + 1
	_draw_up()
	_burn(cfg.dig_ticks, "digs")
	return Result.new(true,
		"You set aside the %s." % inst.card.display_name, "dig")


## Scans draw from the top, collecting the first `count` cards matching
## `kind` (&"any" matches everything, so it is the SAME loop as
## &"support"/&"product" with an always-true predicate - not a separate
## "top N" special case). Removed from draw immediately, not merely marked:
## the drag lock the view applies while pending_pull is set is what keeps
## draw from changing out from under the indices recorded here, not
## anything in this function itself.
##
## Reveals fewer than `count` if that is all there is, and simply leaves
## nothing pending if there is no match at all - the triggering card still
## resolves normally either way (see _support()'s own unconditional
## discard), so a whiffed pull costs nothing extra.
func _start_pull(count: int, kind: StringName) -> void:
	var found: Array[CardInstance] = []
	var indices: Array[int] = []
	var i := 0
	while i < draw.size() and found.size() < count:
		var inst: CardInstance = draw[i]
		var matches: bool
		match kind:
			&"product": matches = inst.is_product()
			&"support": matches = not inst.is_product()
			_: matches = true                        # &"any"
		if matches:
			found.append(inst)
			indices.append(i)
		i += 1
	# Highest original index first, so removing one never shifts an index
	# still queued to be removed.
	for j in range(indices.size() - 1, -1, -1):
		draw.remove_at(indices[j])
	if found.is_empty():
		return
	var p := PendingPull.new()
	p.revealed = found
	p.original_indices = indices
	pending_pull = p


## Reinserts every revealed card the pull did NOT keep, each at the exact
## slot it left - "in the order they were in" for the whole pile, not just
## relative to each other. Walks original_indices ascending (the order they
## were found in), tracking how many earlier entries were permanently kept
## (chosen_index, or none on a cancel) so each later insert lands at its
## true position in the SHRUNKEN pile - not the position it would have had
## if the chosen card were still there to be skipped over.
func _return_pull(p: PendingPull, chosen_index: int) -> void:
	var offset := 0
	for i in range(p.original_indices.size()):
		if i == chosen_index:
			offset += 1
			continue
		draw.insert(p.original_indices[i] - offset, p.revealed[i])


func choose_pull(index: int) -> Result:
	if pending_pull == null:
		return Result.new(false, "There is nothing to choose from.")
	if index < 0 or index >= pending_pull.revealed.size():
		return Result.new(false, "No such card.")
	var chosen: CardInstance = pending_pull.revealed[index]
	_return_pull(pending_pull, index)
	pending_pull = null
	# Index 0, matching _draw_up()'s own convention: a freshly acquired card
	# appears on the left, whether it arrived blind or by your own pick.
	hand.insert(0, chosen)
	return Result.new(true, "You take the %s." % chosen.card.display_name,
		"pull")


func cancel_pull() -> Result:
	if pending_pull == null:
		return Result.new(false, "There is nothing to cancel.")
	_return_pull(pending_pull, -1)
	pending_pull = null
	# Declining costs nothing beyond what the triggering card already cost -
	# the vacated slot still gets filled, just the normal blind way.
	_draw_up()
	return Result.new(true, "You put them back.", "cancel_pull")


func close() -> Result:
	## Sign it. The only thing in the game that banks margin.
	var pair := _here()
	if pair[1] != null:
		return pair[1]
	var c: Customer = pair[0]
	# Closing empty used to be a free "give up on this one" button - now the
	# only way to shed a customer you will not sell to is to let their patience
	# run out (which costs standing when they walk). A future effect/card can
	# grant a one-time bypass here ("strike") without this check itself moving.
	if c.unsigned.is_empty():
		return Result.new(false,
			"%s hasn't agreed to anything yet - sell them something first."
			% c.display_name)
	# Exactly the promise the demand's own telegraph makes - "bought something
	# in <category>" - and nothing stricter. See Customer.owns_category()'s
	# own comment: a hidden priority-within-category threshold used to sit
	# here, and a player who sold her a real category match still got
	# refused with no way to have known why.
	if c.demands_category != null \
			and not c.owns_category(c.demands_category):
		return Result.new(false,
			"%s came in for %s protection and is not signing until they get it."
			% [c.display_name, str(c.demands_category)])

	var chair: int = at
	# While they are still in the chair: settling a demand mutates the customer,
	# and after _vacate() nothing can see them to do it.
	_demand_saw(c, DemandResolve.CLOSE)
	if c.offer != null:
		discard.append(c.offer.instance)
		c.offer = null
	var banked: int = c.unsigned_margin()
	margin_banked += banked
	if category_quota != &"":
		for sale in c.unsigned:
			if sale["product"].interest.category.id == category_quota:
				category_sold += 1
	c.state = "signed"
	stat["customers_signed"] = int(stat["customers_signed"]) + 1
	sale_streak += 1
	sale_streak_events.append(sale_streak)
	events.append("[%s] %s signs for $%d." % [c.key, c.display_name, banked])
	if last_customer == c:
		last_customer = null
	_vacate(chair)
	return Result.new(true, "%s signs for $%d." % [c.display_name, banked],
		"close", {"margin": banked})


## The context for one of YOUR cards or products - the same as _context(), plus
## what the dealership adds to every bit of appeal you add. A customer's own
## actions and demands never get it.
func _yours(c: Customer, card: CardDef = null) -> EffectContext:
	var ctx := _context(c)
	ctx.appeal_bonus = int(perk(&"appeal_per_card"))
	# Bigger Line drops for the card's own brand, from every upgrade that
	# singles it out (or every card, with no brand named).
	var extra := 0.0
	for u in dealership:
		if u != null and u.line_drop_extra != 0.0 and (u.line_drop_brand == &"" \
				or (card != null and card.brand == u.line_drop_brand)):
			extra += u.line_drop_extra
	ctx.line_drop_scale = 1.0 + extra
	return ctx


func _context(c: Customer) -> EffectContext:
	var ctx := EffectContext.new()
	ctx.shift = self
	ctx.customer = c
	ctx.offer = c.offer
	ctx.sales_so_far = c.unsigned.size()
	ctx.patience = c.patience
	return ctx


# --------------------------------------------------------------------- demands
func can_take_a_demand(c: Customer) -> bool:
	## One at a time, not the instant they sit down, and not back to back.
	## Three customers each free to open a fresh fuse every few ticks is not a
	## floor you triage, it is a floor you lose.
	if c == null or c.demand != null:
		return false
	if c.ticks_on_floor < cfg.demand_grace_ticks:
		return false
	if c.demand_settled_tick >= 0 \
			and tick - c.demand_settled_tick < cfg.demand_cooldown_ticks:
		return false
	return true


func raise_demand(c: Customer, d: Demand) -> bool:
	if d == null or not can_take_a_demand(c):
		return false
	c.demand = d
	# Absolute, and at least one tick away, so a demand raised during a burn
	# cannot come due on that same burn before anyone could answer it.
	c.demand_due_tick = tick + maxi(1, d.ticks)
	c.demand_patience_at_raise = c.patience
	return true


func _asks_for_something(act: CustomerAction) -> bool:
	for e in act.effects:
		if e is RaiseDemand:
			return true
	return false


func _demand_saw(c: Customer, kind: StringName, data: Dictionary = {}) -> void:
	## Every player action that touches a customer reports itself here. The
	## demand decides what it meant - which is why adding a way to answer a
	## customer is a new DemandResolve file and not a branch in this function.
	if c == null or c.demand == null or c.demand.resolve == null:
		return
	# offer()'s own _settle() runs before this - a sale may already exist and
	# c.offer may already be null by the time a demand resolves off the SAME
	# offer. Passed through so a relief effect can tell which one it is.
	var sale: Dictionary = data.get("sale", {})
	# Always available, regardless of kind - a resolve like IncreasePatience
	# answers "did it go up since the demand was raised" no matter which
	# action asked, rather than being wired to one specific card or effect.
	data["patience"] = c.patience
	data["patience_at_raise"] = c.demand_patience_at_raise
	if c.demand.resolve.satisfied(kind, data):
		_settle_demand(c, true, sale)
	elif c.demand.resolve.broken_by(kind, data):
		_settle_demand(c, false, sale)


func _settle_demand(c: Customer, met: bool, sale: Dictionary = {}) -> void:
	var d: Demand = c.demand
	c.demand = null
	c.demand_due_tick = 0
	c.demand_settled_tick = tick

	var ctx := _context(c)
	ctx.sale = sale
	var effects: Array[Effect] = d.relief if met else d.effects
	var descriptions: Array[String] = []
	var floor_wide := false
	for e in effects:
		e.apply(ctx)
		descriptions.append(e.describe())
		if e is ChangePatienceFloor:
			floor_wide = true
	if descriptions.is_empty():
		descriptions.append("nothing comes of it" if met else "they let it go")

	stat["demands_met" if met else "demands_missed"] = \
		int(stat["demands_met" if met else "demands_missed"]) + 1

	# What they say once it's settled - previously always silent (this key
	# was hardcoded ""), since the RAISE was the only moment that ever spoke.
	# Met and missed draw from separate tags: relief and a shrug are
	# different registers, not one blended pool.
	var said := ""
	if dialogue != null:
		var tags: Array[StringName] = d.dialogue_tags_met if met else d.dialogue_tags_missed
		if not tags.is_empty():
			var product_id: StringName = c.offer.product.id if c.offer else &""
			var band: StringName = StringName(band_for(c.line - c.offer.appeal)) \
				if c.offer else &""
			said = dialogue.pick(voice_rng, tags, c.archetype.id, product_id, band)

	# Same shape fire() appends, so _drain_log() renders it without knowing a
	# demand from an ordinary action.
	action_log.append({
		"key": c.key,
		"customer": c.display_name,
		"name": "%s - %s" % [d.display_name, "handled" if met else "IGNORED"],
		"dialogue": said,
		"descriptions": descriptions,
		"floor_wide": floor_wide,
	})


## Something a customer says that is not the voice of anything they DID -
## taking a product, running short of patience. It goes in the same action_log
## every other reaction does, so the view pops the same speech bubble for it,
## but with no action's name and nothing done: `chatter` is what tells the log
## to print just the words. Nothing at all is logged when there is no pool, or
## nothing in it fits - the same silence every other line falls back to.
func _chatter(c: Customer, tags: Array[StringName], product_id: StringName = &"") -> void:
	if dialogue == null:
		return
	var said := dialogue.pick(voice_rng, tags, c.archetype.id, product_id, &"", &"",
		c.recent_lines)
	if said == "":
		return
	_log_words(c, said)


## Their words and nothing done - the entry _chatter() and _object() append.
func _log_words(c: Customer, said: String) -> void:
	_heard(c, said)
	action_log.append({
		"key": c.key,
		"customer": c.display_name,
		"name": "",
		"dialogue": said,
		"descriptions": [],
		"floor_wide": false,
		"chatter": true,
	})


func band_for(gap: int) -> String:
	## The fog. Placing shows only this; Read the Room shows the number.
	## INTERESTED is at or over the Line - they would say yes. The rest step out
	## in rungs of ShiftConfig.appeal_step: within one, within about two and a
	## half, within about four and a half, and beyond.
	if gap <= 0:
		return "INTERESTED"
	var step: int = maxi(1, cfg.appeal_step)
	if gap <= step:
		return "ALMOST"
	if gap <= roundi(step * 2.5):
		return "WARM"
	if gap <= roundi(step * 4.5):
		return "COOL"
	return "COLD"


# ---------------------------------------------------------------------- actions
func fire(trigger_type: StringName, c, extra: Dictionary = {}) -> Array:
	## The objection engine. Everything a customer does to you comes through
	## here, so adding an archetype is a data edit and never a code change.
	if c == null:
		return []
	var fired := []
	for act in c.archetype.actions:
		if act.trigger == null or _trigger_name(act.trigger) != trigger_type:
			continue
		# An action whose job is to raise a demand is skipped WHOLESALE when the
		# customer cannot take one, rather than firing and quietly doing nothing:
		# the log would otherwise announce an ask that never happened. Checked
		# before the cadence bookkeeping below, so a throttled customer keeps
		# their place in the rhythm and asks the moment they are allowed to.
		if not can_take_a_demand(c) and _asks_for_something(act):
			continue

		if trigger_type == &"every":
			# Cadence is the caller's job: the trigger itself has no memory.
			var last: int = int(c.action_state.get(act.id, 0))
			if c.ticks_on_floor - last < (act.trigger as Every).ticks:
				continue
			c.action_state[act.id] = c.ticks_on_floor
		else:
			var probe := _context(c)
			probe.rank = int(extra.get("rank", 0))
			probe.short = int(extra.get("short", 0))
			if not act.trigger.matches(probe):
				continue
			if act.trigger is PatienceBelow \
					and (act.trigger as PatienceBelow).once \
					and c.action_state.has(act.id):
				continue
			if act.cooldown > 0 and c.action_state.has(act.id) \
					and tick - int(c.action_state[act.id]) < act.cooldown:
				continue
			c.action_state[act.id] = tick

		var ctx := _context(c)
		ctx.rank = int(extra.get("rank", 0))
		ctx.short = int(extra.get("short", 0))
		# Dictionaries are references, so MarginBonus mutating ctx.sale updates
		# the very entry already sitting in the customer's unsigned deal.
		ctx.sale = extra.get("sale", {})
		var bonus_before: int = int(ctx.sale.get("bonus", 0))

		var descriptions: Array[String] = []
		var floor_wide := false
		for e in act.effects:
			e.apply(ctx)
			descriptions.append(e.describe())
			if e is ChangePatienceFloor:
				floor_wide = true

		if not ctx.sale.is_empty():
			stat["margin_bonus"] = int(stat["margin_bonus"]) \
				+ int(ctx.sale.get("bonus", 0)) - bonus_before

		# What they say when this fires - same post-effect product/band read
		# _support() uses, for the same reason: react to where things ARE.
		var said := ""
		if dialogue != null and not act.dialogue_tags.is_empty():
			var product_id: StringName = c.offer.product.id if c.offer else &""
			var band: StringName = StringName(band_for(c.line - c.offer.appeal)) \
				if c.offer else &""
			said = dialogue.pick(voice_rng, act.dialogue_tags, c.archetype.id,
				product_id, band)

		stat["actions_fired"] = int(stat["actions_fired"]) + 1
		action_log.append({
			"key": c.key,
			"customer": c.display_name,
			"name": act.display_name,
			"dialogue": said,
			"descriptions": descriptions,
			"floor_wide": floor_wide,
		})
		fired.append(act)
	return fired


func _trigger_name(t: Trigger) -> StringName:
	if t is OnOffer:
		return &"on_offer"
	if t is OnPlace:
		return &"on_place"
	if t is OnSale:
		return &"on_sale"
	if t is Every:
		return &"every"
	if t is PatienceBelow:
		return &"patience_below"
	return &""


func report() -> Dictionary:
	var lost_at_bell := 0
	if is_over():
		for c in seated():
			lost_at_bell += c.unsigned_margin()
	var offers: int = int(stat["offers"])
	return {
		"margin_banked": margin_banked,
		"quota": quota,
		"made_quota": margin_banked >= quota,
		"commission": commission,
		"paycheck": paycheck(),
		"standing_delta": _standing_delta(),
		"standing_lost_to_walkouts": _standing_lost_to_walkouts,
		"standing_healed": healed(),
		"category_quota": category_quota,
		"category_quota_name": category_quota_name,
		"category_quota_count": category_quota_count,
		"category_sold": category_sold,
		"category_quota_cost": category_quota_cost(),
		"ticks": tick,
		"tick_budget": tick_budget,
		"customers_seen": served,
		"customers_signed": int(stat["customers_signed"]),
		"customers_walked": int(stat["customers_walked"]),
		"sales": int(stat["sales"]),
		"offers": offers,
		"failed_offers": int(stat["failed_offers"]),
		"close_rate": (float(stat["sales"]) / offers) if offers > 0 else 0.0,
		"margin_conceded": int(stat["margin_conceded"]),
		"margin_padded": int(stat["margin_padded"]),
		"margin_bonus": int(stat["margin_bonus"]),
		"margin_lost_to_walks": lost_to_walks,
		"margin_lost_to_closing": lost_at_bell,
		"actions_fired": int(stat["actions_fired"]),
		"digs": int(stat["digs"]),
		"approaches": int(stat["approaches"]),
		"ticks_cards": int(stat["ticks_cards"]),
		"ticks_place": int(stat["ticks_place"]),
		"ticks_digs": int(stat["ticks_digs"]),
		"ticks_approach": int(stat["ticks_approach"]),
		"demands_met": int(stat["demands_met"]),
		"demands_missed": int(stat["demands_missed"]),
		"sale_streak_end": sale_streak,
		"sale_streak_events": sale_streak_events.duplicate(),
		"peak_combo_multiplier": peak_combo_multiplier,
	}


func _standing_delta() -> int:
	## The NET change RunState folds into its own authoritative total, exactly
	## as before this shift ever ran live walkout damage. Walkouts already
	## docked `standing` immediately, in _walk() - (standing - _initial_standing)
	## is however much of that survived the floor at 0, so a shift this method
	## never lets the eventual RunState.finish_shift() double-charge. The quota
	## term is added here because margin_banked is not final until report() is
	## actually called - it cannot be evaluated any earlier than this. So is the
	## shift's own heal, for the same reason.
	return (standing - _initial_standing) + _standing_delta_from_quota() + healed() \
		- category_quota_cost()


## Products from the quota category that customers have AGREED to but not yet
## signed for - not counted until they sign (category_sold), and lost if the
## bell comes first. What the top bar shows beside the count.
func category_unsigned() -> int:
	if category_quota == &"":
		return 0
	var n := 0
	for c in seated():
		for sale in c.unsigned:
			if sale["product"].interest.category.id == category_quota:
				n += 1
	return n

## Whether this shift had a product quota and fell short of it.
func category_quota_missed() -> bool:
	return category_quota_count > 0 and category_sold < category_quota_count


## What falling short of the product quota costs in standing - nothing if it
## was met, or there was none.
func category_quota_cost() -> int:
	return cfg.category_quota_standing if category_quota_missed() else 0


## What this shift's own heal gives back - ShiftProfile.heal_up_to of the run's
## full standing, in proportion to how much of the quota was banked, all of it
## at quota or better. Nothing for a shift without one.
func healed() -> int:
	# Earned by passing, not by trying: "you should only heal at the end of a
	# boss fight if you pass quota."
	if heal_up_to <= 0.0 or quota <= 0 or margin_banked < quota:
		return 0
	return roundi(heal_up_to * cfg.standing_start)


func _standing_delta_from_quota() -> int:
	## Asymmetric: missing costs far more than beating heals, so this reads as
	## "a bad shift makes death more likely," not "one bad shift and you're out."
	if quota <= 0:
		return 0
	if margin_banked >= quota:
		var over := float(margin_banked - quota) / float(quota)
		return roundi(over * cfg.standing_heal_scale)
	# At least miss_standing_min however close, up to this week's cap at
	# nothing banked.
	var short := clampf(float(quota - margin_banked) / float(quota), 0.0, 1.0)
	return -roundi(lerpf(float(cfg.miss_standing_min), float(miss_cap()), short))


## Which week of the run this shift falls in, from 1.
func week() -> int:
	return (shift_number - 1) / maxi(1, cfg.days_per_week) + 1


## This shift's base salary - ShiftConfig.paycheck, plus the raise for every
## week after the first, times the shift's own pay_scale.
func paycheck() -> int:
	return roundi(cfg.paycheck_in_week(week()) * pay_scale)


## The most missing quota can cost this shift - its week's entry in
## ShiftConfig.miss_standing_max_by_week.
func miss_cap() -> int:
	var caps := cfg.miss_standing_max_by_week
	if caps.is_empty():
		return cfg.miss_standing_min
	var week := (shift_number - 1) / maxi(1, cfg.days_per_week)
	return caps[mini(week, caps.size() - 1)]
