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


## Stub until Task 8 fills it in. The signature already matches its
## replacement, so the _burn() calls above keep working unchanged.
func fire(_trigger_type: StringName, _c, _extra: Dictionary = {}) -> Array:
	return []
