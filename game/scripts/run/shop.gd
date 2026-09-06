class_name Shop extends RefCounted
## Between shifts: add a card, remove a card, upgrade a card. Nothing else - no
## relics, no run modifiers. GODOT_SPEC.md §4's "one system to balance instead
## of two", and every purchase is legible as a card you can look at.
##
## Every action returns a Result, and a refusal spends nothing - not the money,
## not the card. Same convention as every model command.

var run: RunState
var offers: Array[CardDef] = []      ## what you may buy this visit

func _init(p_run: RunState) -> void:
	run = p_run
	_roll_offers()

func _roll_offers() -> void:
	## Drawn from the RUN's seeded rng, never the global one: two runs from the
	## same seed must put the same cards on the shelf.
	var pool: Array[CardDef] = []
	for c in run.card_pool.cards:
		pool.append(c)
	offers.clear()
	var wanted: int = mini(run.cfg.shop_offers, pool.size())
	for _i in range(wanted):
		offers.append(pool.pop_at(run.rng.randi_range(0, pool.size() - 1)))

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
		return int(round(float(inst.card.price) * 0.25))
	var p := inst.card as ProductCardDef
	return p.upgraded_margin - p.margin

func remove_price() -> int:
	return run.cfg.remove_price

# --- the three verbs -------------------------------------------------------

func buy(def: CardDef) -> Result:
	if not offers.has(def):
		return Result.new(false, "%s is not on the shelf." % def.display_name)
	var price := buy_price(def)
	if run.money < price:
		return Result.new(false, "You cannot afford the %s." % def.display_name)
	run.money -= price
	run.deck.add(def)
	offers.erase(def)
	return Result.new(true, "You add the %s to the deck." % def.display_name,
		"buy", {"price": price})

func upgrade(uid: int) -> Result:
	var inst := find(uid)
	if inst == null:
		return Result.new(false, "No such card.")
	if inst.upgraded:
		return Result.new(false, "%s is already upgraded." % inst.card.display_name)
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
