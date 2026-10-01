class_name Shop extends RefCounted
## Between shifts. Every visit the house offers you a few cards and gives you
## ONE of them, free - pick one, or none. Then the store, stocked by the shift
## you just worked: a few cards for sale, and a few of your own offered for an
## upgrade (its ShiftProfile's cards_for_sale and upgrades). Buy or upgrade as
## many of those as you can afford. Nothing else - no relics, no run
## modifiers. GODOT_SPEC.md §4's "one system to balance instead of two", and
## everything here is legible as a card you can look at.
##
## Every action returns a Result, and a refusal spends nothing - not the money,
## not the card. Same convention as every model command.

var run: RunState
## The cards on the house this visit, to pick ONE from. Rolled once, like
## everything here, and never re-rolled for the life of this Shop; the next
## visit rolls its own.
var free_cards: Array[CardDef] = []
## Whether this visit's free pick is still to be made, and which card it was
## once it has been.
var free_picks_left: int = 1
## The lowest CardDef.Rarity the free pick offers - see
## ShiftProfile.free_pick_min_rarity.
var free_pick_min_rarity: int = 0
var free_taken: CardDef = null
## What you may BUY this visit - as many of them as you can afford. A card
## leaves it the moment you buy it.
var offers: Array[CardDef] = []
## Which of your cards you may upgrade this visit, by uid - a random few,
## rolled once, and every one of them yours to upgrade if you can afford it.
## Buying, upgrading or dropping never re-rolls it; a card that becomes
## upgraded (or leaves the deck) simply stops matching.
var upgrade_offers: Array[int] = []
## How many cards this visit put up for sale, and how many of yours it offers
## to upgrade - the shift's own shape, from its ShiftProfile, fixed for the
## visit. `offers` is what is still left on the shelf.
var cards_for_sale: int = 0
var upgrades: int = 0

## How often each rarity turns up, relative to the others - not a percentage,
## just a ratio consumed by _weighted_pick(). Flat on purpose: the pool is still
## small, and a steep drop-off (Slay the Spire's rare odds, say) would make
## Preferred nearly unobtainable with only a handful of cards to draw from.
const RARITY_WEIGHTS := {
	CardDef.Rarity.BASIC: 4,
	CardDef.Rarity.ECONOMY: 3,
	CardDef.Rarity.VALUE: 2,
	CardDef.Rarity.PREFERRED: 1,
}

## p_profile: the ShiftProfile of the shift that just ended - what it adds on
## top of the free card. A null profile adds nothing: the free card alone.
##
## The free card comes whether or not that shift made quota. What missing quota
## costs you is already applied elsewhere - standing, and a bonus pot left
## empty - and anything that is not free here is paid for out of that pot.
func _init(p_run: RunState, p_profile: ShiftProfile = null) -> void:
	run = p_run
	if p_profile != null:
		cards_for_sale = maxi(0, p_profile.cards_for_sale)
		upgrades = maxi(0, p_profile.upgrades)
		free_pick_min_rarity = p_profile.free_pick_min_rarity
	_roll_cards()
	_roll_upgrade_offers()

func _roll_cards() -> void:
	## Drawn from the RUN's seeded rng, never the global one: two runs from the
	## same seed must be offered the same cards. Starter cards are excluded -
	## every run already opens with one, so this is where a run diverges, not
	## where it doubles up on its own starting deck.
	##
	## One draw WITHOUT replacement for everything: no free option turns up
	## twice, and the card for sale is never one you could have had free.
	var pool: Array[CardDef] = []
	for c in run.card_pool.shoppable_cards():
		pool.append(c)
	free_cards.clear()
	# A shift can raise the floor on its free pick - "finishing a boss should
	# offer cards of a higher rarity" (ShiftProfile.free_pick_min_rarity).
	# Drawn from the cards that clear it, while there are any left to draw.
	for _i in range(run.cfg.free_card_choices):
		var fine: Array[CardDef] = []
		for c in pool:
			if c.rarity >= free_pick_min_rarity:
				fine.append(c)
		var from: Array[CardDef] = fine if not fine.is_empty() else pool
		if from.is_empty():
			break
		var picked: CardDef = from[_weighted_pick(from)]
		pool.erase(picked)
		free_cards.append(picked)
	offers.clear()
	for _i in range(mini(cards_for_sale, pool.size())):
		offers.append(pool.pop_at(_weighted_pick(pool)))

## Roulette-wheel selection weighted by RARITY_WEIGHTS, so a common card is more
## likely to turn up than a rare one rather than an equal draw from whatever is
## left.
func _weighted_pick(pool: Array[CardDef]) -> int:
	var total := 0
	for c in pool:
		total += RARITY_WEIGHTS[c.rarity]
	var roll := run.rng.randi_range(0, total - 1)
	var running := 0
	for i in range(pool.size()):
		running += RARITY_WEIGHTS[pool[i].rarity]
		if roll < running:
			return i
	return pool.size() - 1

func _roll_upgrade_offers() -> void:
	## A choice among a few, not a checklist: every un-upgraded card with an
	## upgrade to sell used to get a button at once - eight or more deep by the
	## back half of a run. As many as the shift offers, rolled at random, from
	## the RUN's seeded rng, so two runs from the same seed offer the same cards.
	##
	## By UID, not by CardDef: two copies of the same card (three Explains in
	## the starter deck) are different CardInstances that can be upgraded
	## independently, and the offer has to pick a specific COPY.
	##
	## A visit with no upgrade to give skips this before touching the rng at
	## all, so nothing about a later roll in the same run depends on whether
	## this one ran.
	if upgrades <= 0:
		return
	var pool: Array[int] = []
	for inst in run.deck.cards:
		if not inst.upgraded and upgrade_gain(inst) > 0:
			pool.append(inst.uid)
	upgrade_offers.clear()
	var wanted: int = mini(upgrades, pool.size())
	for _i in range(wanted):
		upgrade_offers.append(pool.pop_at(run.rng.randi_range(0, pool.size() - 1)))

# --- prices ----------------------------------------------------------------

## Its rarity's rung on the ladder - see ShiftConfig.card_prices. A rarity the
## ladder has no rung for costs the top one rather than nothing.
func buy_price(def: CardDef) -> int:
	var ladder := run.cfg.card_prices
	if ladder.is_empty():
		return 0
	return ladder[clampi(int(def.rarity), 0, ladder.size() - 1)]

## "Upgrades should cost half of a purchase": a share of what BUYING that card
## costs, whatever it would gain - nothing for a card with no upgrade to sell.
func upgrade_price(inst: CardInstance) -> int:
	if upgrade_gain(inst) <= 0:
		return 0
	return roundi(buy_price(inst.card) * run.cfg.upgrade_price_share)

## Whether (and, for a product, by how much) a card improves. It no longer sets
## the price - see upgrade_price() - only whether there is an upgrade to buy.
func upgrade_gain(inst: CardInstance) -> int:
	## For a product this is real money per sale. A support card upgrades its
	## EFFECTS, which have no cash value to read, so it reads as a quarter of
	## what the card costs - positive whenever an upgrade is authored.
	if not inst.is_product():
		var s := inst.card as SupportCardDef
		# product_card_def.gd's upgraded_margin == 0 means "no upgrade authored
		# yet", and card_instance.gd's margin() already guards for exactly that.
		# The support-card equivalent is an empty upgraded_effects - shift.gd and
		# card_text.gd both treat that as "no upgrade" too. Charging for either
		# here would be a purchase that changes nothing at all.
		if s.upgraded_effects.is_empty():
			return 0
		return int(round(float(buy_price(inst.card)) * 0.25))
	var p := inst.card as ProductCardDef
	if p.upgraded_margin <= 0:
		return 0
	return p.upgraded_margin - p.margin

func remove_price() -> int:
	return run.cfg.remove_price

## What the store holds beyond the free card, in one line for its header -
## lives here, not in shop_screen.gd, so the wording can never drift from what
## the visit actually offers.
func perk_text() -> String:
	var extras: Array[String] = []
	if cards_for_sale > 0:
		extras.append("%d card%s for sale" % [cards_for_sale, "" if cards_for_sale == 1 else "s"])
	if upgrades > 0:
		extras.append("%d of your cards to upgrade" % upgrades)
	if extras.is_empty():
		return "Just your free card this visit - your bonus carries over."
	return "On top of your free card: %s. Buy as many as your bonus covers." \
		% " and ".join(extras)

# --- the verbs ---------------------------------------------------------------

## "Out of which the player picks ONE. Once they've picked one, they can't pick
## any more of these free ones until the next shift."
func take_free(def: CardDef) -> Result:
	if free_picks_left <= 0:
		return Result.new(false, "You have already taken this visit's free card.")
	if not free_cards.has(def):
		return Result.new(false, "%s is not one of the free cards." % def.display_name)
	run.deck.add(def)
	free_picks_left -= 1
	free_taken = def
	return Result.new(true, "You add the %s to your toolkit. On the house."
		% def.display_name, "take", {"price": 0})

## "Pick one, or none": passing spends the visit's pick on nothing.
func pass_on_free() -> Result:
	if free_picks_left <= 0:
		return Result.new(false, "You have already had this visit's free card.")
	free_picks_left = 0
	return Result.new(true, "You pass on the free cards this time.", "pass")

func buy(def: CardDef) -> Result:
	if not offers.has(def):
		return Result.new(false, "%s is not for sale." % def.display_name)
	var price := buy_price(def)
	if run.money < price:
		return Result.new(false, "You cannot afford the %s." % def.display_name)
	run.money -= price
	run.deck.add(def)
	offers.erase(def)
	return Result.new(true, "You add the %s to your toolkit." % def.display_name,
		"buy", {"price": price})

func upgrade(uid: int) -> Result:
	var inst := find(uid)
	if inst == null:
		return Result.new(false, "No such card.")
	if inst.upgraded:
		return Result.new(false, "%s is already upgraded." % inst.card.display_name)
	if upgrade_gain(inst) <= 0:
		return Result.new(false, "%s has no upgrade to buy." % inst.card.display_name)
	# The random few are a real constraint of the visit, not a suggestion the
	# view happens to follow: a stale button, or a driver calling this
	# directly, must not reach a card that was never on offer.
	if not upgrade_offers.has(uid):
		return Result.new(false, "%s is not on offer this visit."
			% inst.card.display_name)
	var price := upgrade_price(inst)
	if run.money < price:
		return Result.new(false, "You cannot afford to upgrade the %s."
			% inst.card.display_name)
	run.money -= price
	run.deck.upgrade(uid)
	return Result.new(true, "You upgrade the %s." % inst.card.display_name,
		"upgrade", {"price": price})

func remove(uid: int) -> Result:
	var inst := find(uid)
	if inst == null:
		return Result.new(false, "No such card.")
	# Below a full hand, _draw_up cannot fill one - nothing to dig, and nothing
	# to wait for if you are seated. The shop must not be able to build that.
	if run.deck.cards.size() <= run.cfg.min_deck_size:
		return Result.new(false,
			"You need at least %d cards to work a floor." % run.cfg.min_deck_size)
	# margin_banked only moves through a placed product's Offer. Strip the deck
	# of products and the shop has $0 forever with no way to earn it back - the
	# run keeps playing but is already dead.
	if inst.is_product() and _product_count() <= run.cfg.min_products:
		return Result.new(false,
			"You need at least %d products in your toolkit to ever bank a dollar."
				% run.cfg.min_products)
	var price := remove_price()
	if run.money < price:
		return Result.new(false, "You cannot afford to drop the %s."
			% inst.card.display_name)
	run.money -= price
	run.deck.remove(uid)
	return Result.new(true, "You drop the %s." % inst.card.display_name,
		"remove", {"price": price})

func find(uid: int) -> CardInstance:
	for c in run.deck.cards:
		if c.uid == uid:
			return c
	return null

func _product_count() -> int:
	var n := 0
	for c in run.deck.cards:
		if c.is_product():
			n += 1
	return n
