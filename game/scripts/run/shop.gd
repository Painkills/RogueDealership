class_name Shop extends RefCounted
## Between shifts: add a card, remove a card, upgrade a card. Nothing else - no
## relics, no run modifiers. GODOT_SPEC.md §4's "one system to balance instead
## of two", and every purchase is legible as a card you can look at.
##
## Every action returns a Result, and a refusal spends nothing - not the money,
## not the card. Same convention as every model command.

var run: RunState
var offers: Array[CardDef] = []      ## what you may buy this visit
## Which cards in the DECK may be upgraded this visit, by uid. Rolled once,
## here, and never again for the life of this Shop - the same stability
## `offers` already has. Buying, upgrading or dropping a card never re-rolls
## this list; a card that becomes upgraded (or leaves the deck entirely)
## simply stops matching anything the render loop iterates, without needing
## its uid actively removed.
var upgrade_offers: Array[int] = []

## Reward gating from the ShiftProfile picked for the shift that just ended -
## see ShiftProfile's own fields. A dedicated pool only ever pays for its own
## verb; the shared pool pays for whichever of buy()/upgrade() spends it
## first. Defaults (a null profile) are every existing Shop.new(run) test
## call site's old behavior: upgrades allowed, nothing free.
var _allow_upgrades := true
var free_purchases: int = 0
var free_upgrades: int = 0
var free_choices: int = 0

## p_earned_reward: the shift that just ended actually made quota. A tier's
## SHOP SHAPE (whether upgrades are on offer at all) is what that tier always
## looks like, win or lose - but the FREE pools are what missing quota costs
## you, on top of the standing hit and the empty bonus pot finish_shift()
## already applies. True by default so every existing Shop.new(run, profile)
## call site (including tests that are not about this gate at all) keeps
## meaning "the reward applies."
var _reward_forfeited := false

func _init(p_run: RunState, p_profile: ShiftProfile = null,
		p_earned_reward: bool = true) -> void:
	run = p_run
	if p_profile != null:
		_allow_upgrades = p_profile.allow_upgrades_in_shop
		if p_earned_reward:
			free_purchases = p_profile.free_purchases
			free_upgrades = p_profile.free_upgrades
			free_choices = p_profile.free_choices
		elif p_profile.free_purchases > 0 or p_profile.free_upgrades > 0 \
				or p_profile.free_choices > 0:
			_reward_forfeited = true
	_roll_offers()
	_roll_upgrade_offers()

func _roll_offers() -> void:
	## Drawn from the RUN's seeded rng, never the global one: two runs from the
	## same seed must put the same cards on the shelf. Starter cards are
	## excluded - every run already opens with one, so the shop is where a run
	## diverges, not where it doubles up on its own starting deck.
	var pool: Array[CardDef] = []
	for c in run.card_pool.shoppable_cards():
		pool.append(c)
	offers.clear()
	var wanted: int = mini(run.cfg.shop_offers, pool.size())
	for _i in range(wanted):
		offers.append(pool.pop_at(run.rng.randi_range(0, pool.size() - 1)))

func _roll_upgrade_offers() -> void:
	## Every un-upgraded card with a real upgrade to sell used to get a button,
	## unconditionally, all at once - eight or more rows deep by the back half
	## of a run, since the render loop never pre-checked upgrade_gain() at all
	## (only the click did). Capped and rolled at random instead, from the RUN's
	## seeded rng so two runs from the same seed offer the same upgrades, in the
	## same shape _roll_offers() already uses for new cards.
	##
	## By UID, not by CardDef: two copies of the same card (three Explains in
	## the starter deck) are different CardInstances that can be upgraded
	## independently, and the offer has to pick a specific COPY, not a card
	## identity that would ambiguously match all three.
	##
	## A morning ShiftProfile turns upgrades off for this visit entirely -
	## skipped before touching the rng at all, not just hidden, so nothing
	## about a later roll in the same run depends on whether this one ran.
	if not _allow_upgrades:
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

## Reflects the DEDICATED pool only, never the shared one - night guarantees
## a free purchase and a free upgrade regardless of order, so it is honest to
## mark a slot FREE before you have touched anything. The shared pool (first
## pick of either kind, midday) is only resolved at the moment you actually
## buy or upgrade something - see buy()/upgrade() - so pre-marking one
## specific offer here would be a guess this shop cannot actually promise.
func buy_price(def: CardDef) -> int:
	return 0 if free_purchases > 0 else def.price

func upgrade_price(inst: CardInstance) -> int:
	return 0 if free_upgrades > 0 else upgrade_gain(inst) * run.cfg.upgrade_price_multiple

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

## One line summarizing this visit's reward gating, for the shop header -
## lives here, not duplicated into shop_screen.gd, so the wording can never
## drift from what buy()/upgrade() actually grant.
func perk_text() -> String:
	if free_purchases > 0 and free_upgrades > 0:
		return "Tonight's perk: one free purchase and one free upgrade."
	if free_purchases > 0:
		return "One free purchase this visit."
	if free_upgrades > 0:
		return "One free upgrade this visit."
	if free_choices > 0:
		return "Your first purchase or upgrade this visit is free."
	if _reward_forfeited:
		return "No reward this visit - you missed quota."
	if not _allow_upgrades:
		return "Purchases only this visit - no upgrades on offer."
	return ""

# --- the three verbs -------------------------------------------------------

func buy(def: CardDef) -> Result:
	if not offers.has(def):
		return Result.new(false, "%s is not on the shelf." % def.display_name)
	# Dedicated pool first (guaranteed, whichever verb you reach for), then the
	# shared one (first verb wins) - see buy_price()'s own comment on why only
	# the dedicated pool is reflected in the price shown BEFORE this runs.
	var dedicated := free_purchases > 0
	var shared := not dedicated and free_choices > 0
	var price := 0 if (dedicated or shared) else def.price
	if run.money < price:
		return Result.new(false, "You cannot afford the %s." % def.display_name)
	if dedicated:
		free_purchases -= 1
	elif shared:
		free_choices -= 1
	run.money -= price
	run.deck.add(def)
	offers.erase(def)
	var msg := "You add the %s to the deck." % def.display_name
	if shared:
		msg += " First pick free today!"
	elif dedicated:
		msg += " On the house."
	return Result.new(true, msg, "buy", {"price": price})

func upgrade(uid: int) -> Result:
	var inst := find(uid)
	if inst == null:
		return Result.new(false, "No such card.")
	if inst.upgraded:
		return Result.new(false, "%s is already upgraded." % inst.card.display_name)
	if upgrade_gain(inst) <= 0:
		return Result.new(false, "%s has no upgrade to buy." % inst.card.display_name)
	# Same rule buy() already enforces against offers: the random subset is a
	# real constraint of the shop, not a suggestion the view happens to follow.
	# Without this, a stale button reference or a driver calling upgrade()
	# directly could upgrade a card that was never actually on offer.
	if not upgrade_offers.has(uid):
		return Result.new(false, "%s is not on offer this visit."
			% inst.card.display_name)
	var dedicated := free_upgrades > 0
	var shared := not dedicated and free_choices > 0
	var price := 0 if (dedicated or shared) else upgrade_price(inst)
	if run.money < price:
		return Result.new(false, "You cannot afford to upgrade the %s."
			% inst.card.display_name)
	if dedicated:
		free_upgrades -= 1
	elif shared:
		free_choices -= 1
	run.money -= price
	run.deck.upgrade(uid)
	var msg := "You upgrade the %s." % inst.card.display_name
	if shared:
		msg += " First pick free today!"
	elif dedicated:
		msg += " On the house."
	return Result.new(true, msg, "upgrade", {"price": price})

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
			"You need at least %d products in the deck to ever bank a dollar."
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
