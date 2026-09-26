class_name Shop extends RefCounted
## Between shifts. Every visit the house offers you a few cards and gives you
## ONE of them, free - pick one, or none. What else is on offer is what the
## shift you just worked earns: a
## midday shift puts one card up for sale, a night shift lets you upgrade one
## of your own. Nothing else - no relics, no run modifiers. GODOT_SPEC.md §4's
## "one system to balance instead of two", and everything here is legible as a
## card you can look at.
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
var free_taken: CardDef = null
## What you may BUY this visit: the card a midday shift puts up for sale, or
## nothing at all. A card leaves it the moment you buy it.
var offers: Array[CardDef] = []
## Which of your cards you may pick an upgrade from this visit, by uid - a
## random few, rolled once. Buying, upgrading or dropping never re-rolls it; a
## card that becomes upgraded (or leaves the deck) simply stops matching.
var upgrade_offers: Array[int] = []
## How many cards this visit put up for sale, and how many of yours it lets
## you upgrade - the tier's own shape, from its ShiftProfile, fixed for the
## visit. `offers` and `upgrades_left` are what is still left of each.
var cards_for_sale: int = 0
var upgrades: int = 0
var upgrades_left: int = 0

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
	upgrades_left = upgrades
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
	for _i in range(mini(run.cfg.free_card_choices, pool.size())):
		free_cards.append(pool.pop_at(_weighted_pick(pool)))
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
	## back half of a run. Capped and rolled at random instead, from the RUN's
	## seeded rng, so two runs from the same seed offer the same cards.
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
	var wanted: int = mini(run.cfg.shop_upgrade_slots, pool.size())
	for _i in range(wanted):
		upgrade_offers.append(pool.pop_at(run.rng.randi_range(0, pool.size() - 1)))

# --- prices ----------------------------------------------------------------

func buy_price(def: CardDef) -> int:
	return def.price

func upgrade_price(inst: CardInstance) -> int:
	return upgrade_gain(inst) * run.cfg.upgrade_price_multiple

func upgrade_gain(inst: CardInstance) -> int:
	## For a product this is real money per sale. A support card upgrades its
	## EFFECTS, which have no cash value to read, so its price is pinned to the
	## card's own price by the same quarter the product ladder uses.
	if not inst.is_product():
		var s := inst.card as SupportCardDef
		# product_card_def.gd's upgraded_margin == 0 means "no upgrade authored
		# yet", and card_instance.gd's margin() already guards for exactly that.
		# The support-card equivalent is an empty upgraded_effects - shift.gd and
		# card_text.gd both treat that as "no upgrade" too. Charging for either
		# here would be a purchase that changes nothing at all.
		if s.upgraded_effects.is_empty():
			return 0
		return int(round(float(inst.card.price) * 0.25))
	var p := inst.card as ProductCardDef
	if p.upgraded_margin <= 0:
		return 0
	return p.upgraded_margin - p.margin

func remove_price() -> int:
	return run.cfg.remove_price

## What this visit holds beyond the free card, in one line for the store's
## header - lives here, not in shop_screen.gd, so the wording can never drift
## from what the visit actually offers.
func perk_text() -> String:
	var extras: Array[String] = []
	if cards_for_sale == 1:
		extras.append("a card for sale")
	elif cards_for_sale > 1:
		extras.append("%d cards for sale" % cards_for_sale)
	if upgrades == 1:
		extras.append("an upgrade for one of your cards")
	elif upgrades > 1:
		extras.append("upgrades for %d of your cards" % upgrades)
	if extras.is_empty():
		return "Just your free card this visit - your bonus carries over."
	return "On top of your free card: %s." % " and ".join(extras)

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
	# ...and so is the number of them. "Upgrade ONE card" - the rest of the
	# few stay on show, but the visit's upgrade is spent.
	if upgrades_left <= 0:
		return Result.new(false, "You have used this visit's upgrade.")
	var price := upgrade_price(inst)
	if run.money < price:
		return Result.new(false, "You cannot afford to upgrade the %s."
			% inst.card.display_name)
	run.money -= price
	upgrades_left -= 1
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
