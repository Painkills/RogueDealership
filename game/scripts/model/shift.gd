class_name Shift extends RefCounted
## One shift on the floor. The pure rules core: no Node, no scene, no signal.
## The headless suite and the game drive this identical object, so they cannot
## drift.

const CHAIR_KEYS := "ABCDEFGH"

var cfg: ShiftConfig
var interests: InterestPool
var card_pool: CardPool
var archetypes: ArchetypePool
var rng := RandomNumberGenerator.new()

var tick: int = 0
var tick_budget: int
var quota: int
var margin_banked: int = 0

var chairs: Array = []
var walk_up: Array[int] = []
var at = null                      ## chair index you are standing at, or null
var last_customer = null           ## going back to them is free

var draw: Array[CardInstance] = []
var discard: Array[CardInstance] = []
var hand: Array[CardInstance] = []
var reshuffles: int = 0

var events: Array[String] = []
var action_log: Array[Dictionary] = []
var stat: Dictionary = {}
var lost_to_walks: int = 0
var served: int = 0

var _forced: Array = []
var _forced_next: int = 0
var _name_pool: Array = []


func _init(p_cfg: ShiftConfig, p_interests: InterestPool, p_cards: CardPool,
		p_arch: ArchetypePool, p_seed: int, p_forced: Array = []) -> void:
	cfg = p_cfg
	interests = p_interests
	card_pool = p_cards
	archetypes = p_arch
	rng.seed = p_seed
	_forced = p_forced

	tick_budget = cfg.shift_ticks
	quota = cfg.quota
	for key in ["cards_played", "offers", "failed_offers", "offers_dropped",
			"sales", "places", "digs", "approaches", "actions_fired",
			"ticks_cards", "ticks_place", "ticks_digs", "ticks_approach",
			"margin_conceded", "margin_padded", "margin_bonus",
			"customers_signed", "customers_walked"]:
		stat[key] = 0

	chairs.resize(cfg.floor_size)
	walk_up.resize(cfg.floor_size)
	for i in range(cfg.floor_size):
		chairs[i] = null
		walk_up[i] = 0

	var deck := Deck.build_starting(card_pool)
	draw = deck.cards.duplicate()
	_shuffle(draw)
	_draw_up()

	for i in range(cfg.floor_size):
		_spawn(i)


func seated() -> Array:
	var out := []
	for c in chairs:
		if c != null:
			out.append(c)
	return out


func is_over() -> bool:
	return tick >= tick_budget


func margin_at_risk() -> int:
	var total := 0
	for c in seated():
		total += c.unsigned_margin()
	return total


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

	# Chairs already empty are the only ones whose walk-up timer moves; a chair
	# emptied BY this tick starts its wait now.
	for i in range(chairs.size()):
		if chairs[i] == null:
			walk_up[i] -= n

	for c in seated():
		c.patience -= n
		c.ticks_on_floor += n

	# Cadenced actions fire after the burn, so someone already leaving does not
	# get a parting shot.
	for c in seated():
		if c.patience > 0:
			fire(&"every", c)
			fire(&"patience_below", c)

	_settle_patience()

	if not is_over():
		for i in range(chairs.size()):
			if chairs[i] == null and walk_up[i] <= 0:
				_spawn(i)


func _settle_patience() -> void:
	## Anything that touches patience outside a tick still has to check the
	## door. Every patience mutation in the engine ends here.
	for i in range(chairs.size()):
		if chairs[i] != null and chairs[i].patience <= 0:
			_walk(i)


func _walk(chair: int) -> void:
	var c = chairs[chair]
	c.patience = 0
	c.state = "walked"
	var lost: int = c.unsigned_margin()
	lost_to_walks += lost
	stat["customers_walked"] = int(stat["customers_walked"]) + 1
	if c.offer != null:
		discard.append(c.offer.instance)
		c.offer = null
	events.append("[%s] %s walks out%s." % [c.key, c.display_name,
		" with $%d unsigned" % lost if lost > 0 else ""])
	_vacate(chair)


func _vacate(chair: int) -> void:
	chairs[chair] = null
	walk_up[chair] = cfg.walk_up_ticks
	if at == chair:
		at = null


func _spawn(chair: int) -> void:
	var arch := _pick_archetype()
	var top: int = max(1, arch.patience
		+ rng.randi_range(-cfg.patience_jitter, cfg.patience_jitter))

	# Nobody is guaranteed to walk in fresh. Some are already partway to the
	# door, which is triage pressure from the moment they sit down. Floored so
	# an arrival is never dead on arrival.
	var start: int = int(round(top * rng.randf_range(
		cfg.arrival_patience_min_fraction, 1.0)))
	start = max(min(top, cfg.arrival_patience_floor), start)

	var c := Customer.new(CHAIR_KEYS[chair], _next_name(), arch,
		Customer.make_ranks(arch, interests, rng, cfg.prior_slip),
		start, top, cfg.as_dict(), interests)

	if arch.demands_category:
		c.demands = interests.by_id(c.top_interest_id()).category.id
		c.known_top_category = c.demands      # they say so, loudly

	chairs[chair] = c
	walk_up[chair] = 0
	served += 1
	events.append("[%s] %s walks up - %s."
		% [c.key, c.display_name, arch.display_name])


func _pick_archetype() -> CustomerArchetype:
	if not _forced.is_empty():
		var id = _forced[_forced_next % _forced.size()]
		_forced_next += 1
		return archetypes.by_id(id)
	var pool := archetypes.archetypes.duplicate()
	if cfg.unique_archetypes_on_floor:
		var taken := {}
		for c in seated():
			taken[c.archetype.id] = true
		var fresh := []
		for a in pool:
			if not taken.has(a.id):
				fresh.append(a)
		if not fresh.is_empty():
			pool = fresh
	return pool[rng.randi_range(0, pool.size() - 1)]


func _next_name() -> String:
	if _name_pool.is_empty():
		_name_pool = archetypes.names.duplicate()
		_shuffle(_name_pool)
	return _name_pool.pop_back()


# ----------------------------------------------------------------------- deck
func _draw_up() -> void:
	while hand.size() < cfg.hand_size:
		if draw.is_empty():
			if discard.is_empty():
				return
			draw = discard.duplicate()
			discard.clear()
			_shuffle(draw)
			reshuffles += 1
		hand.append(draw.pop_back())


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
	if at == null:
		return [null, Result.new(false,
			"You have to go stand with someone first.")]
	var c = chairs[at]
	if c == null:
		return [null, Result.new(false, "Nobody is sitting there.")]
	return [c, null]


func approach(chair: int) -> Result:
	## Going back to whoever you were last with is free. Only changing your
	## mind about who to work costs the floor a tick.
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
	var cost: int = 0 if c == last_customer else cfg.approach_ticks
	at = chair
	last_customer = c
	stat["approaches"] = int(stat["approaches"]) + 1
	if cost > 0:
		_burn(cost, "approach")
	return Result.new(true, "You walk over to %s." % c.display_name, "move")


func leave() -> Result:
	if at == null:
		return Result.new(false, "You are already out on the floor.")
	at = null
	return Result.new(true, "You step back out onto the floor.", "move")


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
	c.offer = Offer.new(inst, c.appeal_for(product.interest.id), inst.margin())
	var band := band_for(c.line - c.offer.appeal)
	hand.remove_at(index)
	stat["places"] = int(stat["places"]) + 1
	_draw_up()
	_burn(cfg.place_ticks, "place")
	return Result.new(true, "You put the %s in front of %s."
		% [product.display_name, c.display_name], "place", {"band": band})


func _support(c: Customer, index: int) -> Result:
	var inst: CardInstance = hand[index]
	var def := inst.card as SupportCardDef
	if def.needs_offer and c.offer == null:
		return Result.new(false, "%s needs something on the table."
			% def.display_name)

	var ctx := _context(c)
	var effects: Array[Effect] = def.upgraded_effects \
		if inst.upgraded and not def.upgraded_effects.is_empty() else def.effects
	var before_margin: int = c.offer.margin if c.offer else 0
	for e in effects:
		e.apply(ctx)
	if c.offer:
		var delta: int = c.offer.margin - before_margin
		if delta < 0:
			stat["margin_conceded"] = int(stat["margin_conceded"]) - delta
		elif delta > 0:
			stat["margin_padded"] = int(stat["margin_padded"]) + delta
		c.offer.applied.append(def.display_name)

	hand.remove_at(index)
	discard.append(inst)
	stat["cards_played"] = int(stat["cards_played"]) + 1
	_draw_up()
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

	o.revealed = true
	c.known_ranks[iid] = rank
	c.known_line = true
	stat["offers"] = int(stat["offers"]) + 1

	# They evaluate at the Line they had when you ASKED. A Hawk's reaction to
	# being asked cannot retroactively sink an offer that already cleared.
	var sale := _settle(c)
	if not sale.is_empty():
		fire(&"on_sale", c, {"rank": rank, "sale": sale})
	else:
		stat["failed_offers"] = int(stat["failed_offers"]) + 1
		c.patience -= cfg.failed_offer_patience

	fire(&"on_offer", c, {"rank": rank, "short": gap, "sale": sale})
	_settle_patience()

	if not sale.is_empty():
		return Result.new(true, "%s takes the %s - $%d."
			% [c.display_name, sale["product"].display_name, sale["margin"]],
			"sale", {"rank": rank, "margin": sale["margin"],
				"bonus": sale.get("bonus", 0)})
	return Result.new(true, "%d SHORT." % gap, "miss",
		{"short": gap, "rank": rank})


func _settle(c: Customer) -> Dictionary:
	## Accept the moment appeal reaches the Line - never above it, so a card
	## that overshoots is margin you threw away.
	var o = c.offer
	if o == null or o.appeal < c.line:
		return {}
	var sale := {"product": o.product, "margin": o.margin, "bonus": 0}
	c.unsigned.append(sale)
	c.sales += 1
	c.line += c.line_per_sale
	c.add_patience(cfg.patience_per_sale)
	discard.append(o.instance)
	c.offer = null
	stat["sales"] = int(stat["sales"]) + 1
	events.append("[%s] agrees to %s - unsigned."
		% [c.key, sale["product"].display_name])
	return sale


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
	stat["offers_dropped"] = int(stat["offers_dropped"]) + 1
	return Result.new(true,
		"You take the %s back off the table." % product_name, "drop")


func dig(index: int) -> Result:
	## Rummage for the right pitch. The floor pays for it either way.
	if is_over():
		return Result.new(false, "The floor is closed.")
	if index < 0 or index >= hand.size():
		return Result.new(false, "No such card.")
	var inst: CardInstance = hand.pop_at(index)
	discard.append(inst)
	stat["digs"] = int(stat["digs"]) + 1
	_draw_up()
	_burn(cfg.dig_ticks, "digs")
	return Result.new(true,
		"You set aside the %s." % inst.card.display_name, "dig")


func close() -> Result:
	## Sign it. The only thing in the game that banks margin.
	var pair := _here()
	if pair[1] != null:
		return pair[1]
	var c: Customer = pair[0]
	if c.demands != null and not c.owns_category(c.demands):
		return Result.new(false,
			"%s came in for %s protection and is not signing until they get it."
			% [c.display_name, str(c.demands)])

	var chair: int = at
	if c.offer != null:
		discard.append(c.offer.instance)
		c.offer = null
	var banked: int = c.unsigned_margin()
	margin_banked += banked
	c.state = "signed"
	stat["customers_signed"] = int(stat["customers_signed"]) + 1
	events.append("[%s] %s signs for $%d." % [c.key, c.display_name, banked])
	if last_customer == c:
		last_customer = null
	_vacate(chair)
	return Result.new(true, "%s signs for $%d." % [c.display_name, banked],
		"close", {"margin": banked})


func _context(c: Customer) -> EffectContext:
	var ctx := EffectContext.new()
	ctx.shift = self
	ctx.customer = c
	ctx.offer = c.offer
	ctx.sales_so_far = c.unsigned.size()
	ctx.patience = c.patience
	return ctx


func band_for(gap: int) -> String:
	## The fog. Placing shows only this; offering shows the number.
	if gap <= 5:
		return "ALMOST"
	if gap <= 12:
		return "WARM"
	if gap <= 22:
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

		stat["actions_fired"] = int(stat["actions_fired"]) + 1
		action_log.append({
			"key": c.key,
			"customer": c.display_name,
			"name": act.display_name,
			"dialogue": act.dialogue,
			"descriptions": descriptions,
			"floor_wide": floor_wide,
		})
		fired.append(act)
	return fired


func _trigger_name(t: Trigger) -> StringName:
	if t is OnOffer:
		return &"on_offer"
	if t is OnSale:
		return &"on_sale"
	if t is Every:
		return &"every"
	if t is PatienceBelow:
		return &"patience_below"
	return &""
