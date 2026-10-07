class_name SimPlayer extends RefCounted
## The scripted player the balance probes share (tools/sim_tiers.gd,
## tools/sim_runs.gd): one fixed, reasonably sharp policy. It knows every
## customer's true priorities and Line - a sharp human reads most of that from
## bands and Read the Room, at a cost this skips - so results run optimistic.
## It answers demands it can, signs anyone about to walk, and leaves Family
## First alone when asked.
##
## With `fog` on it plays on what a person can see instead: it does not know
## this customer's ranks - nobody's archetype says what they want - and it
## guesses a typical Line until Read the Room shows the real one. After placing
## it sees only the band, offers on INTERESTED, pushes or drops on the rest, and
## learns the exact gap the way you do - by offering, or by Read the Room.

static var fog := false
## What a fogged player guesses a Line is before anything has told it.
const GUESSED_LINE := 24
## Where an interest is guessed to rank: in the category they announced they
## came for (the Karen), or anything else.
const GUESS_TOP := 2
const GUESS_MIDDLE := 5

## The Line as this player knows it.
static func _est_line(c: Customer) -> int:
	if not fog or c.known_line:
		return c.line
	return GUESSED_LINE + c.line_per_sale * c.sales

## Where this player thinks `iid` ranks for `c`.
static func _est_rank(c: Customer, iid: StringName) -> int:
	if not fog or c.known_ranks.has(iid):
		return int(c.ranks[iid])
	if c.archetype.ranks_by_category:
		return _est_rank_by_category(c, iid)
	# Someone who announces the category they came for wants it most - and so
	# does someone who will look at nothing else.
	var cat_id: StringName = c.interests().by_id(iid).category.id
	if (c.demands_category != null and cat_id == c.demands_category) or cat_id == _only(c):
		return GUESS_TOP
	return GUESS_MIDDLE

## The one category they will look at, which is the one they want - or &"".
static func _only(c: Customer) -> StringName:
	return c.archetype.only_category.id if c.archetype.only_category != null else &""

## Ranks dealt a category at a time (CustomerArchetype.ranks_by_category): one rank
## known places its whole category, so this reasons by block - the ranks a
## category's interests share. A category is in the block a known rank puts it
## in; failing that, the first block still free if it is the one Active
## Listening named or the one they announced (the Karen), and otherwise any
## free block. The guess is the middle of the ranks still open there.
static func _est_rank_by_category(c: Customer, iid: StringName) -> int:
	var pool := c.interests()
	var cat: Category = pool.by_id(iid).category
	var size: int = maxi(1, pool.in_category(cat).size())
	var blocks := {}            # category id -> block, from ranks already known
	for known in c.known_ranks:
		var known_cat: Category = pool.by_id(known).category
		blocks[known_cat.id] = (int(c.known_ranks[known]) - 1) / size
	var free: Array[int] = []
	for b in range(pool.categories.size()):
		if not blocks.values().has(b):
			free.append(b)
	var where: Array[int] = []
	if blocks.has(cat.id):
		where = [int(blocks[cat.id])]
	elif not free.is_empty():
		if c.known_top_category == cat.id or c.demands_category == cat.id \
				or _only(c) == cat.id:
			where = [free[0]]
		else:
			where = free
	var open: Array[int] = []
	for b in where:
		for r in range(b * size + 1, b * size + size + 1):
			open.append(r)
	for other in pool.in_category(cat):
		if c.known_ranks.has(other.id):
			open.erase(int(c.known_ranks[other.id]))
	if open.is_empty():
		return GUESS_MIDDLE
	var total := 0
	for r in open:
		total += r
	return roundi(float(total) / open.size())

## The appeal this player expects `iid` to open at with `c`.
static func _est_appeal(c: Customer, iid: StringName) -> int:
	if not fog or c.known_ranks.has(iid):
		return c.appeal_for(iid)
	return int(c.cfg["appeal_step"]) * (c.ranks.size() - _est_rank(c, iid))

## Whether this player knows the exact gap on the table: always without fog;
## with it, once the Line is read or the offer has been made once.
static func _gap_known(c: Customer) -> bool:
	return not fog or c.known_line or (c.offer != null and c.offer.revealed)

## How much appeal a band suggests is still missing - about its middle, in
## rungs of appeal_step (4): ALMOST is within one, WARM within 2.5, COOL 4.5.
static func _band_need(band: String) -> int:
	match band:
		"ALMOST": return 3
		"WARM": return 7
		"COOL": return 14
	return 22

## With `track` on, every visit is written down as it is played: customer ->
## {"ticks", "banked"} - the ticks spent working them (cards cycled for them
## included) and the margin banked when they signed. See probe_visits.gd.
static var track := false
static var visits := {}

## What the last move in _act() was for - see _did().
static var _last := ""

## Tags the move _act() just made, for `track`, and passes its result through.
static func _did(kind: String, ok: bool) -> bool:
	_last = kind
	return ok

static func _note(c: Customer, ticks: int, banked: int, kind: String) -> void:
	if not visits.has(c):
		visits[c] = {"ticks": 0, "banked": 0, "by": {}}
	visits[c]["ticks"] += ticks
	visits[c]["banked"] += banked
	if ticks > 0:
		visits[c]["by"][kind] = int(visits[c]["by"].get(kind, 0)) + ticks

static func play(s: Shift) -> void:
	var guard := 0
	while not s.is_over() and guard < 600:
		guard += 1
		if s.pending_pull != null:
			s.choose_pull(_best_pull(s))
			continue
		if s.seated().is_empty():
			if not s.wait().ok:
				break
			continue
		var target := _pick_target(s)
		if target < 0:
			# Only someone asking to be left alone: step away and cycle a card.
			if s.at != null:
				s.leave()
			if not _dig(s):
				break
			continue
		var who: Customer = s.chairs[target]
		var tick_before := s.tick
		var banked_before := s.margin_banked
		if s.at == null or int(s.at) != target:
			s.approach(target)
		var stuck := false
		_last = ""
		if not _act(s, who):
			_last = "cycle a card (nothing to sell)"
			stuck = not _dig(s)
		if track:
			_note(who, s.tick - tick_before, s.margin_banked - banked_before, _last)
		if stuck:
			break

## Who to work next: whoever has a demand you can answer, soonest due; then
## anyone with a deal unsigned and about to walk; then who you are with, if
## there is still a sale in hand for them; then the best sale on the floor.
static func _pick_target(s: Shift) -> int:
	var best := -1
	var best_score := -INF
	for i in range(s.chairs.size()):
		var c: Customer = s.chairs[i]
		if c == null:
			continue
		if c.demand != null and c.demand.resolve is LeaveThemAlone:
			continue
		var score := 0.0
		if c.demand != null and _can_answer(s, c):
			score = 1000.0 - float(c.demand_due_tick - s.tick)
		elif not c.unsigned.is_empty() and c.patience <= 3:
			score = 900.0 - float(c.patience)
		else:
			var p := _best_product(s, c)
			if p >= 0:
				score = float(_margin_of(s, p)) / 100.0 + (5.0 if s.at != null and int(s.at) == i else 0.0)
			elif not c.unsigned.is_empty():
				score = 1.0
			else:
				score = -10.0 + float(c.patience) * -0.1
		if score > best_score:
			best_score = score
			best = i
	return best

static func _can_answer(s: Shift, c: Customer) -> bool:
	var r := c.demand.resolve
	# An ask whose only reward is being told what they want is worth a card and
	# a tick only to someone who does not know it yet - ignoring it costs less.
	if _only_tells(c.demand) and (not fog or c.known_top_category != null):
		return false
	if r is IncreasePatience:
		return _find(s, "patience") >= 0
	if r is MakeAnOffer:
		return c.offer != null or _best_product(s, c, true) >= 0
	if r is OfferSomethingGood:
		return (c.offer != null and _est_rank(c, c.offer.product.interest.id) <= 3) \
			or _top3_product(s, c) >= 0
	if r is PlayConcession:
		return c.offer != null and _find(s, "concession") >= 0
	if r is PlayAnySupport:
		return _any_support(s, c) >= 0
	if r is PlayAppealCard:
		return c.offer != null and _appeal_answer(s, c) >= 0
	return false

## Whether meeting `d` earns nothing but a read on them.
static func _only_tells(d: Demand) -> bool:
	return not d.relief.is_empty() and d.relief.all(func(e): return e is RevealRoom)

## One move with customer `c`. False when there was nothing worth doing.
static func _act(s: Shift, c: Customer) -> bool:
	if c.demand != null and _can_answer(s, c):
		var r := c.demand.resolve
		if r is IncreasePatience:
			return _did("answer a demand: raise patience", s.play_card(_find(s, "patience")).ok)
		if r is MakeAnOffer:
			if c.offer == null:
				return _did("answer a demand: make an offer", s.place(_best_product(s, c, true)).ok)
			return _did("answer a demand: make an offer", s.offer().ok)
		if r is OfferSomethingGood:
			if c.offer != null and _est_rank(c, c.offer.product.interest.id) <= 3:
				return _did("answer a demand: offer a top-3", s.offer().ok)
			if c.offer != null:
				s.drop_offer()
			return _did("answer a demand: offer a top-3", s.place(_top3_product(s, c)).ok)
		if r is PlayConcession:
			return _did("answer a demand: concession", s.play_card(_find(s, "concession")).ok)
		if r is PlayAnySupport:
			return _did("answer a demand: any support card", s.play_card(_any_support(s, c)).ok)
		if r is PlayAppealCard:
			return _did("answer a demand: appeal card", s.play_card(_appeal_answer(s, c)).ok)
	if not c.unsigned.is_empty() and _should_close(s, c):
		if s.close().ok:
			return _did("close", true)
	# Whatever goes on them next is waved off: give them the card you can spare,
	# or go and cycle one rather than waste a good one.
	if c.next_card_rejected():
		var spare := _spare_card(s, c)
		if spare < 0:
			return false
		return _did("a card to be waved off", s.play_card(spare).ok)
	if c.offer != null and not _gap_known(c):
		# Only the band to go on. Read the Room first if it is in hand - it
		# turns the band into a number.
		var read := _find(s, "read")
		if read >= 0:
			return _did("read the room", s.play_card(read).ok)
		var band := s.band_for(c.line - c.offer.appeal)
		if band == "INTERESTED":
			var sweetener := _money_card_for(s, c)
			if sweetener >= 0:
				return _did("money card", s.play_card(sweetener).ok)
			return _did("offer", s.offer().ok)
		var need := _band_need(band)
		if _appeal_in_hand(s) >= need:
			return _did("appeal card", s.play_card(_appeal_card_for(s, need)).ok)
		s.drop_offer()
	elif c.offer != null:
		var gap: int = c.line - c.offer.appeal
		if gap <= 0:
			# Over the Line already: sweeten the deal first if a card adds money
			# without dropping them back under it, while the clock allows.
			var sweetener := _money_card_for(s, c)
			if sweetener >= 0:
				return _did("money card", s.play_card(sweetener).ok)
			return _did("offer", s.offer().ok)
		var card := _appeal_card_for(s, gap)
		if card >= 0:
			return _did("appeal card", s.play_card(card).ok)
		s.drop_offer()
	var p := _best_product(s, c)
	if p >= 0:
		return _did("place a product", s.place(p).ok)
	# Nothing in hand sells to them: a free draw card goes looking for it.
	var draw := _free_draw(s)
	if draw >= 0:
		return _did("draw card", s.play_card(draw).ok)
	if c.patience <= 4:
		var calm := _find(s, "patience")
		if calm >= 0:
			return _did("patience card", s.play_card(calm).ok)
	if not c.unsigned.is_empty():
		return _did("close", s.close().ok)
	return false

static func _should_close(s: Shift, c: Customer) -> bool:
	return c.patience <= 3 or (s.tick_budget - s.tick) <= 2 \
		or (c.offer == null and _best_product(s, c) < 0)

## The product in hand that sells best to `c`: outright sales first, by margin;
## then the smallest gap the appeal cards in hand can close. -1 if none can.
## `any_offer`: any product at all will do (a Kicker only wants to be asked).
static func _best_product(s: Shift, c: Customer, any_offer: bool = false) -> int:
	var boost := _appeal_in_hand(s)
	var short := _quota_short(s)
	var best := -1
	var best_key := -INF
	for i in range(s.hand.size()):
		var inst: CardInstance = s.hand[i]
		if not inst.is_product() or c.owns(inst.card.id) \
				or not c.accepts(inst.card as ProductCardDef):
			continue
		var appeal: int = _est_appeal(c, (inst.card as ProductCardDef).interest.id)
		var gap: int = _est_line(c) - appeal
		if gap > boost and not any_offer:
			continue
		var key: float = (100000.0 if gap <= 0 else -1000.0 * gap) \
			+ inst.margin() * c.margin_scale_for(inst.card as ProductCardDef)
		# The day's product quota first, until it is met - then play normally.
		if short > 0 and _in_quota(s, inst):
			key += 1000000.0
		if key > best_key:
			best_key = key
			best = i
	return best

## How many more of the day's quota category the shift still needs, counting
## sales agreed but not yet signed - 0 once met, or on a shift without one.
static func _quota_short(s: Shift) -> int:
	if s.category_quota_count <= 0:
		return 0
	return maxi(0, s.category_quota_count - s.category_sold - s.category_unsigned())

static func _in_quota(s: Shift, inst: CardInstance) -> bool:
	return inst.is_product() \
		and (inst.card as ProductCardDef).interest.category.id == s.category_quota

static func _top3_product(s: Shift, c: Customer) -> int:
	var best := -1
	var best_rank := 99
	for i in range(s.hand.size()):
		var inst: CardInstance = s.hand[i]
		if not inst.is_product() or c.owns(inst.card.id) \
				or not c.accepts(inst.card as ProductCardDef):
			continue
		var rank: int = _est_rank(c, (inst.card as ProductCardDef).interest.id)
		if rank <= 3 and rank < best_rank:
			best_rank = rank
			best = i
	return best

static func _margin_of(s: Shift, i: int) -> int:
	return (s.hand[i] as CardInstance).margin()

## How far a card closes the gap: its appeal - Back to Value's grows with
## `sales`, the products they have already taken - plus however far it lowers
## the Line (WALKAWAY Complimentary), which comes to the same thing.
static func _appeal_of(inst: CardInstance, sales: int = 0) -> int:
	if inst.is_product():
		return 0
	var def := inst.card as SupportCardDef
	var total := 0
	var effects: Array = def.upgraded_effects \
		if inst.upgraded and not def.upgraded_effects.is_empty() else def.effects
	for e in effects:
		if e is ChangeAppeal:
			total += e.amount
		elif e is ScaleBySales and e.inner is ChangeAppeal:
			total += e.inner.amount * (1 + sales)
		elif (e is ChangeLineFloorWide or e is ChangeLine) and e.amount < 0:
			total -= e.amount
	return total

## Sales already made to whoever you are sitting with.
static func _sales_here(s: Shift) -> int:
	if s.at == null or s.chairs[int(s.at)] == null:
		return 0
	return (s.chairs[int(s.at)] as Customer).sales

static func _appeal_in_hand(s: Shift) -> int:
	var total := 0
	var sales := _sales_here(s)
	for inst in s.hand:
		total += maxi(0, _appeal_of(inst, sales))
	return total

## The smallest appeal card that closes `gap` on its own, or else the biggest.
static func _appeal_card_for(s: Shift, gap: int) -> int:
	var covering := -1
	var biggest := -1
	var sales := _sales_here(s)
	for i in range(s.hand.size()):
		var a := _appeal_of(s.hand[i], sales)
		if a <= 0:
			continue
		if a >= gap and (covering < 0 or a < _appeal_of(s.hand[covering], sales)):
			covering = i
		if biggest < 0 or a > _appeal_of(s.hand[biggest], sales):
			biggest = i
	return covering if covering >= 0 else biggest

## A card in hand that adds margin to the offer and still leaves appeal at the
## Line - or -1. Only with ticks to spare for it.
static func _money_card_for(s: Shift, c: Customer) -> int:
	if s.tick_budget - s.tick <= 3:
		return -1
	for i in range(s.hand.size()):
		var inst: CardInstance = s.hand[i]
		if inst.is_product():
			continue
		var def := inst.card as SupportCardDef
		var effects: Array = def.upgraded_effects if inst.upgraded and not def.upgraded_effects.is_empty() \
			else def.effects
		var money := 0
		var appeal := 0
		for e in effects:
			var inner = e.inner if e is ScaleBySales else e
			if inner is ChangeMargin:
				money += inner.amount
			if inner is ChangeAppeal:
				appeal += inner.amount
		if money <= 0:
			continue
		if _gap_known(c):
			if c.offer.appeal + appeal >= c.line:
				return i
		elif appeal >= 0 or _appeal_in_hand(s) >= -appeal:
			# Only the band says they are over: a card that costs appeal is
			# played only with enough appeal in hand to win it back.
			return i
	return -1

## A draw card in hand that costs no time - or -1.
static func _free_draw(s: Shift) -> int:
	for i in range(s.hand.size()):
		var inst: CardInstance = s.hand[i]
		if inst.is_product() or inst.ticks() > 0:
			continue
		for e in (inst.card as SupportCardDef).effects:
			if e is PullCards:
				return i
	return -1

## From a draw card's choices: the product the customer you are with likes
## best, or else the biggest appeal card, or else the first.
static func _best_pull(s: Shift) -> int:
	var c: Customer = s.chairs[int(s.at)] if s.at != null else null
	var best := 0
	var best_key := -INF
	for i in range(s.pending_pull.revealed.size()):
		var inst: CardInstance = s.pending_pull.revealed[i]
		var key := 0.0
		if inst.is_product():
			if c != null and not c.owns(inst.card.id):
				key = 1000.0 + float(_est_appeal(c, (inst.card as ProductCardDef).interest.id))
		else:
			key = float(_appeal_of(inst, _sales_here(s)))
		if key > best_key:
			best_key = key
			best = i
	return best

static func _find(s: Shift, what: String) -> int:
	for i in range(s.hand.size()):
		var inst: CardInstance = s.hand[i]
		if inst.is_product():
			continue
		var def := inst.card as SupportCardDef
		for e in def.effects:
			if what == "patience" and (e is ChangePatience or e is ChangePatienceFloor) \
					and e.amount > 0:
				return i
			if what == "concession" and e is ChangeMargin and e.amount < 0:
				return i
			if what == "read" and e is RevealRoom:
				return i
	return -1

## A card in hand that answers "explain it to me" (PlayAppealCard): the
## smallest that closes the gap as far as this player knows it, or else the
## biggest - or -1.
static func _appeal_answer(s: Shift, c: Customer) -> int:
	var gap: int = maxi(1, _est_line(c) - c.offer.appeal) if c.offer != null else 1
	var covering := -1
	var biggest := -1
	for i in range(s.hand.size()):
		var inst: CardInstance = s.hand[i]
		if inst.is_product():
			continue
		var def := inst.card as SupportCardDef
		var effects: Array = def.upgraded_effects \
			if inst.upgraded and not def.upgraded_effects.is_empty() else def.effects
		if not effects.any(func(e): return PlayAppealCard.adds_appeal(e)):
			continue
		var a := _appeal_of(inst, c.sales)
		if a >= gap and (covering < 0 or a < _appeal_of(s.hand[covering], c.sales)):
			covering = i
		if biggest < 0 or a > _appeal_of(s.hand[biggest], c.sales):
			biggest = i
	return covering if covering >= 0 else biggest

## The support card you would miss least - the quickest, then the weakest -
## that can go on `c` right now, or -1.
static func _spare_card(s: Shift, c: Customer) -> int:
	var best := -1
	var best_key := INF
	for i in range(s.hand.size()):
		var inst: CardInstance = s.hand[i]
		if inst.is_product():
			continue
		if (inst.card as SupportCardDef).needs_offer and c.offer == null:
			continue
		var key := float(inst.ticks()) * 100.0 + float(_appeal_of(inst, c.sales))
		if key < best_key:
			best_key = key
			best = i
	return best

static func _any_support(s: Shift, c: Customer) -> int:
	for i in range(s.hand.size()):
		var inst: CardInstance = s.hand[i]
		if not inst.is_product() and (c.offer != null or not (inst.card as SupportCardDef).needs_offer):
			return i
	return -1

## Cycle the least useful card: a product nobody on the floor wants much, or
## else the first support card.
static func _dig(s: Shift) -> bool:
	if s.hand.is_empty():
		return false
	var worst := 0
	var worst_value := INF
	var short := _quota_short(s)
	for i in range(s.hand.size()):
		var inst: CardInstance = s.hand[i]
		var value := 20.0
		if inst.is_product():
			value = 0.0
			for c in s.seated():
				value = maxf(value, float(_est_appeal(c, (inst.card as ProductCardDef).interest.id)))
			# Never throw away what the day's quota still needs.
			if short > 0 and _in_quota(s, inst):
				value += 100.0
		if value < worst_value:
			worst_value = value
			worst = i
	return s.dig(worst).ok

