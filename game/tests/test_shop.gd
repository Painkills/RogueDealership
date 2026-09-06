extends RefCounted
## The whole meta layer: add a card, remove a card, upgrade a card.
var h: Harness

func _run(money: int = 10000) -> RunState:
	var r := RunState.new(load("res://data/shift_config.tres"),
		load("res://data/interests/interest_pool.tres"),
		load("res://data/card_pool.tres"),
		load("res://data/archetype_pool.tres"), 7)
	r.money = money
	return r

func test_every_card_carries_a_price() -> void:
	## Support cards have no margin to derive a price from, so it is authored.
	var pool: CardPool = load("res://data/card_pool.tres")
	for c in pool.cards:
		h.check("%s is priced" % c.id, c.price > 0)

func test_the_shop_offers_cards_and_they_come_from_the_pool() -> void:
	var r := _run()
	var shop := Shop.new(r)
	h.eq("three on offer", shop.offers.size(), r.cfg.shop_offers)
	var known := {}
	for c in r.card_pool.cards:
		known[c.id] = true
	for c in shop.offers:
		h.check("%s is a real card" % c.id, known.has(c.id))
	var seen := {}
	for c in shop.offers:
		h.check("%s is offered only once" % c.id, not seen.has(c.id))
		seen[c.id] = true

func test_two_shops_from_one_seed_offer_the_same_cards() -> void:
	var a := Shop.new(_run())
	var b := Shop.new(_run())
	var ids_a: Array[String] = []
	var ids_b: Array[String] = []
	for c in a.offers:
		ids_a.append(String(c.id))
	for c in b.offers:
		ids_b.append(String(c.id))
	h.eq("the same shelf", ids_a, ids_b)

func test_buying_adds_the_card_and_debits_the_money() -> void:
	var r := _run()
	var shop := Shop.new(r)
	var def: CardDef = shop.offers[0]
	var before: int = r.deck.cards.size()
	var price: int = shop.buy_price(def)
	var res := shop.buy(def)
	h.check("bought (%s)" % res.msg, res.ok)
	h.eq("the deck grew by one", r.deck.cards.size(), before + 1)
	h.eq("and the money went down by the price", r.money, 10000 - price)
	h.check("it is off the shelf", not shop.offers.has(def))

func test_you_cannot_buy_what_you_cannot_afford() -> void:
	var r := _run(0)
	var shop := Shop.new(r)
	var def: CardDef = shop.offers[0]
	var before: int = r.deck.cards.size()
	var res := shop.buy(def)
	h.check("refused", not res.ok)
	h.eq("and nothing was spent", r.money, 0)
	h.eq("nor added", r.deck.cards.size(), before)

func test_upgrading_costs_a_multiple_of_what_it_gains() -> void:
	## Both the gain and the price scale with the card, so a percentage upgrade
	## is value-neutral across the margin ladder - the decision is which product
	## you actually sell, not which number is biggest.
	var r := _run()
	var shop := Shop.new(r)
	var product: CardInstance = null
	for c in r.deck.cards:
		if c.is_product():
			product = c
			break
	h.check("there is a product in the starter deck", product != null)
	var p := product.card as ProductCardDef
	var gain: int = p.upgraded_margin - p.margin
	h.eq("priced at the multiple of the gain", shop.upgrade_price(product),
		gain * r.cfg.upgrade_price_multiple)

	var res := shop.upgrade(product.uid)
	h.check("upgraded (%s)" % res.msg, res.ok)
	h.check("the instance knows", product.upgraded)
	h.eq("and it now earns the upgraded margin", product.margin(), p.upgraded_margin)

func test_a_card_cannot_be_upgraded_twice() -> void:
	var r := _run()
	var shop := Shop.new(r)
	var uid: int = r.deck.cards[0].uid
	shop.upgrade(uid)
	var money_after_first: int = r.money
	var res := shop.upgrade(uid)
	h.check("refused", not res.ok)
	h.eq("and charged nothing", r.money, money_after_first)

func test_a_product_with_no_authored_upgrade_cannot_be_bought() -> void:
	## upgraded_margin = 0 is product_card_def.gd's documented "no upgrade
	## authored yet" sentinel, and card_instance.gd's margin() already guards
	## for it. Without the same guard here, upgrade_gain() returns a NEGATIVE
	## number, upgrade_price() prices it negative too, the affordability check
	## passes at any balance, and run.money -= (negative price) CREDITS money.
	##
	## A fresh Resource, never a loaded .tres: Resources are cached
	## project-wide, so mutating one would corrupt every later test in the run.
	var r := _run()
	var shop := Shop.new(r)
	var def := ProductCardDef.new()
	def.id = &"test_no_upgrade_product"
	def.display_name = "Test Product"
	def.price = 100
	def.margin = 200
	def.upgraded_margin = 0
	var inst := r.deck.add(def)
	var money_before: int = r.money
	var res := shop.upgrade(inst.uid)
	h.check("refused (%s)" % res.msg, not res.ok)
	h.check("and says there is nothing to upgrade",
		res.msg.to_lower().contains("no upgrade"))
	h.eq("and nothing was spent", r.money, money_before)
	h.check("and the instance stayed un-upgraded", not inst.upgraded)

func test_a_support_card_with_no_authored_upgrade_cannot_be_bought() -> void:
	## shift.gd and card_text.gd both already treat an empty upgraded_effects as
	## "no upgrade" - the shop must not be the one place that still charges for it.
	var r := _run()
	var shop := Shop.new(r)
	var def := SupportCardDef.new()
	def.id = &"test_no_upgrade_support"
	def.display_name = "Test Support"
	def.price = 100
	def.effects = []
	def.upgraded_effects = []
	var inst := r.deck.add(def)
	var money_before: int = r.money
	var res := shop.upgrade(inst.uid)
	h.check("refused (%s)" % res.msg, not res.ok)
	h.check("and says there is nothing to upgrade",
		res.msg.to_lower().contains("no upgrade"))
	h.eq("and nothing was spent", r.money, money_before)
	h.check("and the instance stayed un-upgraded", not inst.upgraded)

func test_removing_thins_the_deck() -> void:
	var r := _run()
	var shop := Shop.new(r)
	var uid: int = r.deck.cards[0].uid
	var before: int = r.deck.cards.size()
	var res := shop.remove(uid)
	h.check("removed (%s)" % res.msg, res.ok)
	h.eq("the deck shrank by one", r.deck.cards.size(), before - 1)
	h.eq("and the money went down", r.money, 10000 - r.cfg.remove_price)

func test_the_deck_can_never_be_thinned_into_a_softlock() -> void:
	## Strip the deck below hand_size and _draw_up cannot fill a hand: you have
	## nothing to dig, and if you are seated you cannot wait either. That is the
	## exact softlock wait() was written to fix, reachable through the shop.
	var r := _run(1000000)
	var shop := Shop.new(r)
	var guard := 0
	while r.deck.cards.size() > 1 and guard < 100:
		guard += 1
		shop.remove(r.deck.cards[0].uid)
	h.check("the deck stopped shrinking at the floor (%d cards)"
		% r.deck.cards.size(), r.deck.cards.size() >= r.cfg.min_deck_size)
	h.check("which is at least a full hand", r.cfg.min_deck_size >= r.cfg.hand_size)

func test_the_deck_can_never_be_stripped_of_products() -> void:
	## margin_banked only moves through a placed product's Offer, and money is
	## what margin_banked clears the quota BY - so a deck with zero products left
	## can never bank another dollar, and the shop then has $0 forever with no
	## other income.
	## The run keeps playing but is already dead. Same shape as the softlock
	## test above, guarded on composition rather than size.
	var r := _run(1000000)
	var shop := Shop.new(r)
	var guard := 0
	var last_refusal := ""
	while guard < 100:
		guard += 1
		var product: CardInstance = null
		for c in r.deck.cards:
			if c.is_product():
				product = c
				break
		if product == null:
			break
		var res := shop.remove(product.uid)
		if not res.ok:
			last_refusal = res.msg
			break
	var remaining := 0
	for c in r.deck.cards:
		if c.is_product():
			remaining += 1
	h.check("the deck stopped losing products at the floor (%d products)"
		% remaining, remaining >= r.cfg.min_products)
	h.check("and the refusal says something useful (%s)" % last_refusal,
		last_refusal.to_lower().contains("product"))
