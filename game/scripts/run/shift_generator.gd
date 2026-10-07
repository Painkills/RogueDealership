class_name ShiftGenerator extends RefCounted
## Builds the shift a calendar slot deals, to the slot's difficulty target:
## exactly who comes in (a lineup), and - for a premade shift that scales (see
## ShiftProfile.difficulty) - the complicators it comes with.
##
## Difficulty is counted in points: each customer brings their archetype's
## (CustomerArchetype.difficulty), a premade shift's own rules bring its
## `difficulty`, and each complicator its `points`. Who may come in is the
## door's own rule (Shift.eligible_archetypes) - so the hardest archetypes wait
## for week 2, and within a week the budget decides how many of the difficult
## ones a shift can afford: one Family First on an easy morning, two on a harder
## one.
##
## Pure like the rest of scripts/run: every pool is handed in, and every roll
## comes from the rng handed in.

## The copy of `shift` that goes on the calendar in `tier`'s slot on `day`,
## filled to `target` points. `shift` is `tier` itself for a regular shift, which
## brings no rules of its own - customers, and a harder quota where its
## difficulty target is spent on one (ShiftComplicator.on_regular_shifts).
static func fill(shift: ShiftProfile, tier: ShiftProfile, day: int, week: int,
		target: int, archetypes: ArchetypePool, complicators: Array, share: float,
		rng: RandomNumberGenerator) -> ShiftProfile:
	var premade := shift != tier
	var count := shift.customers if premade and shift.customers > 0 else tier.customers
	var pool := _pool(shift, tier, week, archetypes)
	var rules := shift.difficulty if premade else 0
	var budget := target - rules
	# What the cheapest lineup costs - anything over it is spare, to be spent on
	# tougher customers or, a share of it, on complicators.
	var spare := maxi(0, budget - _cheapest(pool) * count)
	var chosen: Array[ShiftComplicator] = []
	var open: Array[ShiftComplicator] = []
	open = _eligible(complicators, day, shift.touches(), rng, not premade)
	_add(chosen, open, floori(spare * share))
	var for_customers := budget - _points(chosen)
	var weight_of := func(a: CustomerArchetype) -> float:
		var w := maxf(0.0, a.weight) * maxf(0.0, float(tier.archetype_weight_scales.get(a.id, 1.0)))
		if premade:
			w *= maxf(0.0, float(shift.archetype_weight_scales.get(a.id, 1.0)))
		return w * (tier.hard_weight_scale if a.hard else 1.0)
	var lineup := lineup_for(pool, count, for_customers, weight_of,
		tier.allow_hard_duplicates or (premade and shift.allow_hard_duplicates), rng)
	var got := _sum(lineup)
	# Customers alone could not get there - week 1 has nobody harder to send - so
	# complicators make up what they can of the rest.
	if got < for_customers:
		_add(chosen, open, for_customers - got)
	var copy := shift.duplicate() as ShiftProfile
	copy.lineup = lineup
	copy.complicators = chosen
	copy.difficulty = rules + _points(chosen) + got
	return copy

## `count` customers from `pool` whose points come as near `want` as the pool
## allows: drawn by `weight_of` first, then swapped one at a time towards it.
## Without `allow_hard_duplicates`, a hard archetype (CustomerArchetype.hard)
## comes in at most once - the floor's own rule for those - unless the pool
## has nobody else to send.
static func lineup_for(pool: Array[CustomerArchetype], count: int, want: int,
		weight_of: Callable, allow_hard_duplicates: bool,
		rng: RandomNumberGenerator) -> Array[CustomerArchetype]:
	var out: Array[CustomerArchetype] = []
	if pool.is_empty():
		return out
	for _i in range(count):
		out.append(_draw(_open_for(pool, out, -1, allow_hard_duplicates), weight_of, rng))
	for _step in range(count * 4):
		var need := want - _sum(out)
		if need == 0:
			break
		var swapped := false
		for i in _shuffled_indices(count, rng):
			var here: CustomerArchetype = out[i]
			var options := _open_for(pool, out, i, allow_hard_duplicates).filter(
				func(a): return absi(need - (a.difficulty - here.difficulty)) < absi(need))
			if options.is_empty():
				continue
			var typed: Array[CustomerArchetype] = []
			typed.assign(options)
			out[i] = _draw(typed, weight_of, rng)
			swapped = true
			break
		if not swapped:
			break
	return out

## Who may come in: the door's rule for the week, minus whoever the slot or
## the shift keeps out, and nobody the shift never sends (weight 0) unless
## that is everybody.
static func _pool(shift: ShiftProfile, tier: ShiftProfile, week: int,
		archetypes: ArchetypePool) -> Array[CustomerArchetype]:
	var excluded: Array = tier.excluded_archetypes.duplicate()
	if shift != tier:
		excluded.append_array(shift.excluded_archetypes)
	var pool := Shift.eligible_archetypes(archetypes, week, shift.only_archetypes, excluded)
	var sent: Array[CustomerArchetype] = []
	sent.assign(pool.filter(func(a): return a.weight > 0.0))
	return sent if not sent.is_empty() else pool

## `pool` less the hard archetypes already in `out` - but the one at `skip`,
## which is the one being swapped out.
static func _open_for(pool: Array[CustomerArchetype], out: Array[CustomerArchetype],
		skip: int, allow_hard_duplicates: bool) -> Array[CustomerArchetype]:
	if allow_hard_duplicates:
		return pool
	var taken := {}
	for i in range(out.size()):
		if i != skip and out[i].hard:
			taken[out[i]] = true
	var open: Array[CustomerArchetype] = []
	open.assign(pool.filter(func(a): return not taken.has(a)))
	return open if not open.is_empty() else pool

static func _draw(options: Array[CustomerArchetype], weight_of: Callable,
		rng: RandomNumberGenerator) -> CustomerArchetype:
	var total := 0.0
	for a in options:
		total += float(weight_of.call(a))
	if total <= 0.0:
		return options[rng.randi_range(0, options.size() - 1)]
	var roll := rng.randf() * total
	for a in options:
		roll -= float(weight_of.call(a))
		if roll < 0.0:
			return a
	return options[options.size() - 1]

## The complicators `day` allows that change nothing the shift sets itself
## (`touched`), in an order drawn from `rng`.
static func _eligible(complicators: Array, day: int, touched: Array[StringName],
		rng: RandomNumberGenerator, regular: bool = false) -> Array[ShiftComplicator]:
	var out: Array[ShiftComplicator] = []
	for c in complicators:
		if c == null or c.points <= 0 or c.from_day > day:
			continue
		if regular and not c.on_regular_shifts:
			continue
		if c.touches().any(func(t): return touched.has(t)):
			continue
		out.append(c)
	for i in range(out.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap := out[i]
		out[i] = out[j]
		out[j] = swap
	return out

## Adds from `open`, in its order, every complicator that fits in `room` points
## and changes nothing one already chosen does.
static func _add(chosen: Array[ShiftComplicator], open: Array[ShiftComplicator],
		room: int) -> void:
	for c in open:
		if room <= 0:
			return
		if chosen.has(c) or c.points > room:
			continue
		var clash := false
		for other in chosen:
			if c.touches().any(func(t): return other.touches().has(t)):
				clash = true
				break
		if clash:
			continue
		chosen.append(c)
		room -= c.points

static func _cheapest(pool: Array[CustomerArchetype]) -> int:
	var low := 0
	for i in range(pool.size()):
		if i == 0 or pool[i].difficulty < low:
			low = pool[i].difficulty
	return low

static func _sum(lineup: Array[CustomerArchetype]) -> int:
	var total := 0
	for a in lineup:
		total += a.difficulty
	return total

static func _points(chosen: Array[ShiftComplicator]) -> int:
	var total := 0
	for c in chosen:
		total += c.points
	return total

static func _shuffled_indices(n: int, rng: RandomNumberGenerator) -> Array[int]:
	var out: Array[int] = []
	for i in range(n):
		out.append(i)
	for i in range(n - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap := out[i]
		out[i] = out[j]
		out[j] = swap
	return out
