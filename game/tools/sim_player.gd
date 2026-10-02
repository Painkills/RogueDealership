class_name SimPlayer extends RefCounted
## The scripted player the balance probes share (tools/sim_tiers.gd,
## tools/sim_runs.gd): one fixed, reasonably sharp policy. It knows every
## customer's true priorities and Line - a sharp human reads most of that from
## bands and Read the Room, at a cost this skips - so results run optimistic.
## It answers demands it can, signs anyone about to walk, and leaves Family
## First alone when asked.
##
## With `fog` on it plays on what a person can see instead: it knows each
## archetype's tastes (its favourites usually rank near the top, its dislikes
## near the bottom) but not this customer's ranks, and it guesses a typical
## Line until Read the Room shows the real one. After placing it sees only the
## band, offers on ALMOST, pushes or drops on the rest, and learns the exact
## gap the way you do - by offering, or by Read the Room.

static var fog := false
## What a fogged player guesses a Line is before anything has told it.
const GUESSED_LINE := 35
## Where an interest is guessed to rank: an archetype favourite, a dislike,
## or neither.
const GUESS_TOP := 2
const GUESS_BOTTOM := 8
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
	for i in c.archetype.top_interests:
		if i.id == iid:
			return GUESS_TOP
	for i in c.archetype.bottom_interests:
		if i.id == iid:
			return GUESS_BOTTOM
	return GUESS_MIDDLE

## The appeal this player expects `iid` to open at with `c`.
static func _est_appeal(c: Customer, iid: StringName) -> int:
	if not fog or c.known_ranks.has(iid):
		return c.appeal_for(iid)
	return int(c.cfg["appeal_step"]) * (c.ranks.size() - _est_rank(c, iid))

## Whether this player knows the exact gap on the table: always without fog;
## with it, once the Line is read or the offer has been made once.
static func _gap_known(c: Customer) -> bool:
	return not fog or c.known_line or (c.offer != null and c.offer.revealed)

## How much appeal a band suggests is still missing - its middle.
static func _band_need(band: String) -> int:
	match band:
		"ALMOST": return 3
		"WARM": return 9
		"COOL": return 18
	return 28

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
		if s.at == null or int(s.at) != target:
			s.approach(target)
		if not _act(s, s.chairs[target]):
			if not _dig(s):
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
	return false

## One move with customer `c`. False when there was nothing worth doing.
static func _act(s: Shift, c: Customer) -> bool:
	if c.demand != null and _can_answer(s, c):
		var r := c.demand.resolve
		if r is IncreasePatience:
			return s.play_card(_find(s, "patience")).ok
		if r is MakeAnOffer:
			if c.offer == null:
				return s.place(_best_product(s, c, true)).ok
			return s.offer().ok
		if r is OfferSomethingGood:
			if c.offer != null and _est_rank(c, c.offer.product.interest.id) <= 3:
				return s.offer().ok
			if c.offer != null:
				s.drop_offer()
			return s.place(_top3_product(s, c)).ok
		if r is PlayConcession:
			return s.play_card(_find(s, "concession")).ok
		if r is PlayAnySupport:
			return s.play_card(_any_support(s, c)).ok
	if not c.unsigned.is_empty() and _should_close(s, c):
		if s.close().ok:
			return true
	if c.offer != null and not _gap_known(c):
		# Only the band to go on. Read the Room first if it is in hand - it
		# turns the band into a number.
		var read := _find(s, "read")
		if read >= 0:
			return s.play_card(read).ok
		var band := s.band_for(c.line - c.offer.appeal)
		if band == "ALMOST":
			return s.offer().ok
		var need := _band_need(band)
		if _appeal_in_hand(s) >= need:
			return s.play_card(_appeal_card_for(s, need)).ok
		s.drop_offer()
	elif c.offer != null:
		var gap: int = c.line - c.offer.appeal
		if gap <= 0:
			# Over the Line already: sweeten the deal first if a card adds money
			# without dropping them back under it, while the clock allows.
			var sweetener := _money_card_for(s, c)
			if sweetener >= 0:
				return s.play_card(sweetener).ok
			return s.offer().ok
		var card := _appeal_card_for(s, gap)
		if card >= 0:
			return s.play_card(card).ok
		s.drop_offer()
	var p := _best_product(s, c)
	if p >= 0:
		return s.place(p).ok
	# Nothing in hand sells to them: a free draw card goes looking for it.
	var draw := _free_draw(s)
	if draw >= 0:
		return s.play_card(draw).ok
	if c.patience <= 4:
		var calm := _find(s, "patience")
		if calm >= 0:
			return s.play_card(calm).ok
	if not c.unsigned.is_empty():
		return s.close().ok
	return false

static func _should_close(s: Shift, c: Customer) -> bool:
	return c.patience <= 3 or (s.tick_budget - s.tick) <= 2 \
		or (c.offer == null and _best_product(s, c) < 0)

## The product in hand that sells best to `c`: outright sales first, by margin;
## then the smallest gap the appeal cards in hand can close. -1 if none can.
## `any_offer`: any product at all will do (a Kicker only wants to be asked).
static func _best_product(s: Shift, c: Customer, any_offer: bool = false) -> int:
	var boost := _appeal_in_hand(s)
	var best := -1
	var best_key := -INF
	for i in range(s.hand.size()):
		var inst: CardInstance = s.hand[i]
		if not inst.is_product() or c.owns(inst.card.id):
			continue
		var appeal: int = _est_appeal(c, (inst.card as ProductCardDef).interest.id)
		var gap: int = _est_line(c) - appeal
		if gap > boost and not any_offer:
			continue
		var key: float = (100000.0 if gap <= 0 else -1000.0 * gap) + inst.margin()
		if key > best_key:
			best_key = key
			best = i
	return best

static func _top3_product(s: Shift, c: Customer) -> int:
	var best := -1
	var best_rank := 99
	for i in range(s.hand.size()):
		var inst: CardInstance = s.hand[i]
		if not inst.is_product() or c.owns(inst.card.id):
			continue
		var rank: int = _est_rank(c, (inst.card as ProductCardDef).interest.id)
		if rank <= 3 and rank < best_rank:
			best_rank = rank
			best = i
	return best

static func _margin_of(s: Shift, i: int) -> int:
	return (s.hand[i] as CardInstance).margin()

static func _appeal_of(inst: CardInstance) -> int:
	if inst.is_product():
		return 0
	var def := inst.card as SupportCardDef
	var total := 0
	var effects: Array = def.upgraded_effects \
		if inst.upgraded and not def.upgraded_effects.is_empty() else def.effects
	for e in effects:
		if e is ChangeAppeal:
			total += e.amount
	return total

static func _appeal_in_hand(s: Shift) -> int:
	var total := 0
	for inst in s.hand:
		total += maxi(0, _appeal_of(inst))
	return total

## The smallest appeal card that closes `gap` on its own, or else the biggest.
static func _appeal_card_for(s: Shift, gap: int) -> int:
	var covering := -1
	var biggest := -1
	for i in range(s.hand.size()):
		var a := _appeal_of(s.hand[i])
		if a <= 0:
			continue
		if a >= gap and (covering < 0 or a < _appeal_of(s.hand[covering])):
			covering = i
		if biggest < 0 or a > _appeal_of(s.hand[biggest]):
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
		if money > 0 and c.offer.appeal + appeal >= c.line:
			return i
	return -1

## A draw card in hand that costs no time - or -1.
static func _free_draw(s: Shift) -> int:
	for i in range(s.hand.size()):
		var inst: CardInstance = s.hand[i]
		if inst.is_product() or inst.card.ticks > 0:
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
			key = float(_appeal_of(inst))
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
	for i in range(s.hand.size()):
		var inst: CardInstance = s.hand[i]
		var value := 20.0
		if inst.is_product():
			value = 0.0
			for c in s.seated():
				value = maxf(value, float(_est_appeal(c, (inst.card as ProductCardDef).interest.id)))
		if value < worst_value:
			worst_value = value
			worst = i
	return s.dig(worst).ok

