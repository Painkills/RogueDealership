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

var state: String = "floor"        ## floor | signed | walked
var sales: int = 0
var ticks_on_floor: int = 0
var action_state: Dictionary = {}  ## action id -> when it last fired
## One log line per entry into the danger zone, not one per tick spent in it -
## re-arms the moment patience climbs back out, so a genuine second scare still
## warns.
var warned_leaving_soon: bool = false

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
	## appeal_step x (interest_count - rank). Their number one opens at 40 and
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


func reveal_room(exact: bool = false) -> void:
	## The base read narrows nine interests to three and hands you the Line -
	## which, since offering stopped teaching it, is the ONLY way to learn it.
	## The upgrade narrows that last three to one.
	##
	## Both name whichever of their interests is highest-priority and NOT
	## already sold - top_unsold_interest_id(), not top_interest_id(). A read
	## that keeps naming an interest you already closed would be a read that
	## stops telling you anything the moment you are doing well.
	known_line = true
	var top := top_unsold_interest_id()
	known_top_category = _interests.by_id(top).category.id
	# Recorded as a known RANK rather than its own flag: everything that reads
	# priorities already walks known_ranks, so the upgrade needs no new case
	# anywhere downstream of here. The rank is whatever top's real rank is -
	# 2nd, 3rd, whatever is left - not hardcoded to 1.
	if exact:
		known_ranks[top] = int(ranks[top])


func owns(product_id: StringName) -> bool:
	for u in unsigned:
		if u["product"].id == product_id:
			return true
	return false


## Any unsigned product in the category counts - Karen's own gate (close(),
## in shift.gd) tells the player only "bought something in <category>", never
## a priority threshold within it, so the check has to mean exactly that
## promise and nothing stricter. A rank-based version of this used to require
## one of her own better-ranked interests, which the player has no way to
## know without already having placed the product - a trap the demand's own
## telegraph never mentioned.
func owns_category(cat_id: StringName) -> bool:
	for u in unsigned:
		if u["product"].interest.category.id == cat_id:
			return true
	return false


func leaving_soon() -> bool:
	return patience <= int(cfg.get("leaving_soon_at", 4))


static func make_ranks(arch: CustomerArchetype, pool: InterestPool,
		rng: RandomNumberGenerator, prior_slip: float) -> Dictionary:
	## Seed the archetype's priors into the top and bottom thirds, shuffle the
	## rest. prior_slip is what keeps a prior from being a lookup table: each
	## seeded interest has that chance of being left to the shuffle instead,
	## because a prior that is never wrong is a lookup table, not a read.
	var top: Array = []
	for i in arch.top_interests:
		if rng.randf() >= prior_slip:
			top.append(i.id)
	var bottom: Array = []
	for i in arch.bottom_interests:
		if rng.randf() >= prior_slip:
			bottom.append(i.id)
	top = top.slice(0, 3)
	bottom = bottom.slice(0, 3)

	var rest: Array = []
	for i in pool.interests:
		if not top.has(i.id) and not bottom.has(i.id):
			rest.append(i.id)
	_shuffle(rest, rng)

	var n := pool.count()
	var slots: Array = []
	slots.resize(n)

	var head: Array = [0, 1, 2]
	_shuffle(head, rng)
	for k in range(top.size()):
		slots[head[k]] = top[k]

	var tail: Array = [n - 3, n - 2, n - 1]
	_shuffle(tail, rng)
	for k in range(bottom.size()):
		slots[tail[k]] = bottom[k]

	for idx in range(n):
		if slots[idx] == null:
			slots[idx] = rest.pop_back()

	var out := {}
	for idx in range(n):
		out[slots[idx]] = idx + 1
	return out


static func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	## Array.shuffle() uses the GLOBAL rng and would destroy reproducibility.
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
