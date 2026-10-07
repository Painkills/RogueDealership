class_name Customer extends RefCounted
## One person in a chair. RefCounted, never a Resource: Resources are cached
## and shared project-wide, so mutable state on one leaks between customers
## and between runs.

var key: String                    ## "A" / "B" / "C" - which chair
var display_name: String
var archetype: CustomerArchetype
var cfg: Dictionary

var ranks: Dictionary              ## interest id -> 1..9. Hidden from the player.
var line: int                      ## how high Appeal must climb before yes
var start_line: int
var line_per_sale: int
var combo_step: float              ## see CustomerArchetype.combo_step
var patience: int
var max_patience: int

var offer                          ## Offer, or null
var unsigned: Array[Dictionary] = []

# What the PLAYER knows. The hidden information in this game is the priority
# list; the arithmetic of an offer already made never is.
var known_ranks: Dictionary = {}
var known_line: bool = false
var known_top_category = null
## Upgraded Read the Room's read: the three interests they want most that
## are not sold yet, unordered. Empty until then.
var known_top_three: Array[StringName] = []

## The Karen: they will not sign until they have bought from the category they
## came in for. Announced on arrival - a free read, and then they charge the
## whole floor rent until you act on it. A standing gate on close(), NOT a
## timed ask - which is why it keeps a name one letter away from `demand`
## below rather than being folded into it.
var demands_category = null

## What they are asking you for RIGHT NOW, or null. At most one at a time: a
## customer with two live fuses is a customer you cannot triage, only lose.
var demand: Demand = null
## Absolute tick the fuse comes due, not a countdown. A countdown decremented
## inside _burn() would be wrong for a multi-tick burn and would let a demand
## raised during that same burn expire before anyone could answer it.
var demand_due_tick: int = 0
## When the last one finished, either way. -1 means they have never asked.
var demand_settled_tick: int = -1
## Their patience the moment the live demand was raised - see Shift.raise_demand()
## and DemandResolve subclasses like IncreasePatience that answer "did it go
## up since then" regardless of what caused it.
var demand_patience_at_raise: int = 0

var state: String = "floor"        ## floor | signed | walked
var sales: int = 0
var ticks_on_floor: int = 0
## action id -> when it last fired. An Every action's is set off by the jitter
## rolled for its next interval - see Shift.fire().
var action_state: Dictionary = {}
## One log line per entry into the danger zone, not one per tick spent in it -
## re-arms the moment patience climbs back out, so a genuine second scare still
## warns.
var warned_leaving_soon: bool = false
## The same, for saying so out loud - see ShiftConfig.impatient_at.
var said_impatient: bool = false
## What they are objecting to about the product on their table - "It's too
## expensive" - while you work through it. &"" when nothing is: see
## Shift._object(), and DialogueLine.becomes for how a conversation moves it.
var objection: StringName = &""
## The last few things they said, newest last - what DialoguePool.pick_line()
## steers them away from repeating. See Shift._heard().
var recent_lines: Array[String] = []
## Cards played on them since they last waved one off - see
## CustomerArchetype.rejects_every_nth_card.
var cards_since_rejection: int = 0

## What they came in to spend - see CustomerArchetype.budget_share. 0 = they
## spend freely.
var budget: int = 0
## A boss's moves (CustomerArchetype.moves): how many rounds of them are done -
## each makes their hits harder and their fuses shorter - what is left of this
## round, and the soonest the next may be raised.
var move_round: int = 0
## The tick each of CustomerArchetype.timed_moves next comes due, by index - set
## when they sit down (start_timed_moves()), and again each time one comes up.
var timed_move_due: Array[int] = []
var move_rounds_dealt: int = 0
var moves_left: Array[Demand] = []
var next_move_tick: int = 0

var _interests: InterestPool


func _init(p_key: String, p_name: String, p_arch: CustomerArchetype,
		p_ranks: Dictionary, p_patience: int, p_max: int,
		p_cfg: Dictionary, p_interests: InterestPool) -> void:
	key = p_key
	display_name = p_name
	archetype = p_arch
	ranks = p_ranks
	cfg = p_cfg
	line = p_arch.line
	start_line = p_arch.line
	line_per_sale = p_arch.line_per_sale
	combo_step = p_arch.combo_step
	patience = p_patience
	max_patience = p_max
	_interests = p_interests


func appeal_for(interest_id: StringName) -> int:
	## appeal_step x (interest_count - rank). Their number one opens at 32 and
	## their last at 0 - not a refusal, just eight places of concession you
	## will not want to pay for.
	return int(cfg["appeal_step"]) * (ranks.size() - int(ranks[interest_id]))


func add_patience(n: int) -> void:
	patience = min(max_patience, patience + n)


func unsigned_margin() -> int:
	var total := 0
	for u in unsigned:
		total += int(u["margin"])
	return total


func top_interest_id() -> StringName:
	for iid in ranks:
		if int(ranks[iid]) == 1:
			return iid
	return &""


## Their `n` highest-priority interests not yet sold, best first.
func top_unsold_interest_ids(n: int) -> Array[StringName]:
	var sold := {}
	for u in unsigned:
		sold[u["product"].interest.id] = true
	var open: Array = []
	for iid in ranks:
		if not sold.has(iid):
			open.append(iid)
	open.sort_custom(func(a, b): return int(ranks[a]) < int(ranks[b]))
	var out: Array[StringName] = []
	for iid in open.slice(0, n):
		out.append(StringName(iid))
	return out

## Their highest-priority interest that is not already sold - what Read the
## Room should actually point at. Naming their number one after you have
## already closed it is a read that tells you nothing; naming whatever is
## next is the same promise the card makes ("their number one") kept once
## the literal number one is off the table. Falls back to top_interest_id()
## only in the unreachable case where every one of their interests is sold.
func top_unsold_interest_id() -> StringName:
	var sold := {}
	for u in unsigned:
		sold[u["product"].interest.id] = true
	var best_iid: StringName = &""
	var best_rank: int = 9999
	for iid in ranks:
		if sold.has(iid):
			continue
		if int(ranks[iid]) < best_rank:
			best_rank = int(ranks[iid])
			best_iid = iid
	if best_iid == &"":
		return top_interest_id()
	return best_iid


## The board they were dealt against. The view needs it to lay their priority
## list out as a grid, and a customer knowing which nine interests exist is not
## a leak - the RANKS are the hidden information, and those stay behind
## known_ranks where they always were.
func interests() -> InterestPool:
	return _interests


func reveal_room(exact: bool = false, with_line: bool = true) -> void:
	## Active Listening. The Line, always - since offering stopped teaching it,
	## this is the ONLY way to learn it - and what they want. `exact` is the three
	## they want most that are still open, each with its rank, so in order; not
	## exact, only the one they want most.
	##
	## Whatever is highest-priority and NOT already sold. A read that keeps
	## naming what you already closed would stop telling you anything the moment
	## you are doing well.
	##
	## Nothing is lit on their interest grid beyond the ranks themselves: a row
	## is only lit for someone who ranks by category and came in for one (the
	## Karen), and they announce it on arrival (Shift._spawn()).
	##
	## `with_line` false tells you only what they want - a customer opening up
	## (RevealRoom.line), not you reading them.
	if with_line:
		known_line = true
	# Recorded as a known RANK rather than its own flag: everything that reads
	# priorities already walks known_ranks, so this needs no new case anywhere
	# downstream of here. The rank is whatever top's real rank is - 2nd, 3rd,
	# whatever is left - not hardcoded to 1.
	var top := top_unsold_interest_id()
	known_ranks[top] = int(ranks[top])
	if exact:
		known_top_three = top_unsold_interest_ids(3)
		for iid in known_top_three:
			known_ranks[iid] = int(ranks[iid])


func owns(product_id: StringName) -> bool:
	for u in unsigned:
		if u["product"].id == product_id:
			return true
	return false


## Any unsigned product in the category counts - Karen's own gate (close(),
## in shift.gd) tells the player only "bought something in <category>", never
## a priority threshold within it, so the check has to mean exactly that
## promise and nothing stricter. A rank-based version of this used to require
## one of their own better-ranked interests, which the player has no way to
## know without already having placed the product - a trap the demand's own
## telegraph never mentioned.
func owns_category(cat_id: StringName) -> bool:
	for u in unsigned:
		if u["product"].interest.category.id == cat_id:
			return true
	return false


func leaving_soon() -> bool:
	# Someone whose patience is your shield never leaves - low on it, they are
	# only easy to hurt you through.
	if archetype.patience_is_shield:
		return false
	return patience <= int(cfg.get("leaving_soon_at", 4))


func has_budget() -> bool:
	return budget > 0


## What is left of their budget: all of it, less everything they have agreed
## to so far.
func budget_left() -> int:
	return maxi(0, budget - unsigned_margin())


## Whether they came in with a budget and have none of it left to spend.
func spent_out() -> bool:
	return has_budget() and budget_left() <= 0


## Starts the clock of every timed move: each comes due its own `every_ticks`
## after `tick`.
func start_timed_moves(tick: int) -> void:
	timed_move_due.clear()
	for t in archetype.timed_moves:
		timed_move_due.append(tick + (t.every_ticks if t != null else 0))


## The timed move that is due at `tick` and has not come up yet, as an index into
## CustomerArchetype.timed_moves - the one due longest ago if two are - or -1.
func due_timed_move(tick: int) -> int:
	var due := -1
	for i in range(timed_move_due.size()):
		var t: TimedMove = archetype.timed_moves[i]
		if t != null and t.move != null and tick >= timed_move_due[i] \
				and (due == -1 or timed_move_due[i] < timed_move_due[due]):
			due = i
	return due


## The timed move that comes due soonest, or -1 when there are none.
func soonest_timed_move() -> int:
	var soonest := -1
	for i in range(timed_move_due.size()):
		var t: TimedMove = archetype.timed_moves[i]
		if t != null and t.move != null \
				and (soonest == -1 or timed_move_due[i] < timed_move_due[soonest]):
			soonest = i
	return soonest


## Whether `d` is one of this boss's moves - in the rotation, or on a clock.
func is_a_move(d: Demand) -> bool:
	if d == null:
		return false
	if archetype.moves.has(d):
		return true
	for t in archetype.timed_moves:
		if t != null and t.move == d:
			return true
	return false


## How much harder a boss's hits land than they say on paper: their escalation
## times every round of moves already done.
func move_damage_bonus() -> int:
	return archetype.escalate_damage * move_round if archetype.is_boss() else 0


## What move `d` would hit for if it landed now.
func move_damage(d: Demand) -> int:
	var base := d.hit_damage()
	return base + move_damage_bonus() if base > 0 else 0


## The fuse move `d` is raised with now: shorter every round, never below
## CustomerArchetype.min_move_fuse.
func move_fuse(d: Demand) -> int:
	return maxi(maxi(1, archetype.min_move_fuse),
		d.ticks - archetype.escalate_fuse * move_round)


## Whether the next card played on them gets waved off - the telegraph for
## CustomerArchetype.rejects_every_nth_card.
func next_card_rejected() -> bool:
	var n: int = archetype.rejects_every_nth_card
	return n > 0 and cards_since_rejection >= n - 1


## Whether they will look at `product` at all - CustomerArchetype.only_category.
func accepts(product: ProductCardDef) -> bool:
	var only: Category = archetype.only_category
	if only == null:
		return true
	var cat: Category = product.interest.category
	return cat != null and cat.id == only.id


## What a sale of `product` pays them, as a multiple of its margin -
## CustomerArchetype.premium_interests.
func margin_scale_for(product: ProductCardDef) -> float:
	for i in archetype.premium_interests:
		if i != null and i.id == product.interest.id:
			return archetype.premium_margin_scale
	return 1.0


static func make_ranks(pool: InterestPool, rng: RandomNumberGenerator,
		favourites: Array[Interest] = [], by_category: bool = false) -> Dictionary:
	## Dealt at random, for everyone - nothing about an archetype says what
	## they want.
	##
	## `favourites`, when given, take the top ranks - the Karen's demanded
	## category, which they want most because it is what they came in for.
	##
	## `by_category`: dealt a category at a time instead - see
	## CustomerArchetype.ranks_by_category and _ranks_by_category().
	if by_category:
		return _ranks_by_category(pool, rng, favourites)
	var top: Array = []
	for i in favourites:
		top.append(i.id)
	_shuffle(top, rng)
	var rest: Array = []
	for i in pool.interests:
		if not top.has(i.id):
			rest.append(i.id)
	_shuffle(rest, rng)

	var out := {}
	var rank := 1
	for iid in top + rest:
		out[iid] = rank
		rank += 1
	return out


## Ranks a category at a time: their favourite category takes the first block
## of ranks, the next category the block after it, and so on, shuffled within
## each block. The order of the categories is random - but the Karen's
## demanded one (`favourites`) comes first.
static func _ranks_by_category(pool: InterestPool, rng: RandomNumberGenerator,
		favourites: Array[Interest]) -> Dictionary:
	var top: Category = null
	if not favourites.is_empty():
		top = favourites[0].category
	var order: Array = []
	for cat in pool.categories:
		if top == null or cat.id != top.id:
			order.append(cat)
	_shuffle(order, rng)
	if top != null:
		order.push_front(top)

	var out := {}
	var rank := 1
	for cat in order:
		var block: Array = []
		for i in pool.interests:
			if i.category != null and i.category.id == cat.id:
				block.append(i.id)
		_shuffle(block, rng)
		for iid in block:
			out[iid] = rank
			rank += 1
	# An interest in no category the pool lists still needs a rank: last.
	for i in pool.interests:
		if not out.has(i.id):
			out[i.id] = rank
			rank += 1
	return out


static func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	## Array.shuffle() uses the GLOBAL rng and would destroy reproducibility.
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
