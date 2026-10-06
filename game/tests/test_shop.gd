extends RefCounted
## The whole meta layer: a free card every visit, then a store stocked by the
## shift you just worked - cards to buy and cards of yours to upgrade, as many
## as you can afford - plus dropping a card you no longer want. Checked against
## each shift's own numbers, never today's tuning of them.
var h: Harness

func _run(money: int = 10000, seed_value: int = 7) -> RunState:
	var r := RunState.new(load("res://data/shift_config.tres"),
		load("res://data/interests/interest_pool.tres"),
		load("res://data/card_pool.tres"),
		load("res://data/archetype_pool.tres"), seed_value)
	r.money = money
	return r

## A tier that adds `for_sale` cards for sale and `ups` upgrades - fresh, never
## a loaded .tres, so nothing here can leak into the shipped profiles.
func _profile(for_sale: int = 0, ups: int = 0) -> ShiftProfile:
	var p := ShiftProfile.new()
	p.cards_for_sale = for_sale
	p.upgrades = ups
	return p


func test_taking_one_adds_it_and_costs_nothing() -> void:
	var r := _run()
	var shop := Shop.new(r)
	var def: CardDef = shop.free_cards[1]
	var before: int = r.deck.cards.size()
	var res := shop.take_free(def)
	h.check("taken (%s)" % res.msg, res.ok)
	h.eq("the toolkit grew by one", r.deck.cards.size(), before + 1)
	h.check("by the card picked", r.deck.cards.any(func(c): return c.card == def))
	h.eq("and not a dollar went", r.money, 10000)
	h.eq("the visit's pick is spent", shop.free_picks_left, 0)
	h.eq("on that card", shop.free_taken, def)

func test_once_one_is_picked_the_others_wait_for_the_next_shift() -> void:
	## "Once they've picked one, they can't pick any more of these free ones
	## until the next shift, when they get 3 more options to pick from."
	var r := _run()
	var shop := Shop.new(r)
	shop.take_free(shop.free_cards[0])
	var size: int = r.deck.cards.size()
	var res := shop.take_free(shop.free_cards[1])
	h.check("a second pick is refused (%s)" % res.msg, not res.ok)
	h.check("because the pick is spent", res.msg.to_lower().contains("already taken"))
	h.check("and so is taking the same one again", not shop.take_free(shop.free_cards[0]).ok)
	h.eq("neither added anything", r.deck.cards.size(), size)
	var next := Shop.new(r)
	h.eq("the next visit brings a fresh pick", next.free_picks_left, 1)
	h.eq("from a fresh set", next.free_cards.size(), r.cfg.free_card_choices)

func test_only_the_cards_on_offer_can_be_taken_free() -> void:
	var r := _run()
	var shop := Shop.new(r)
	var other: CardDef = null
	for c in r.card_pool.shoppable_cards():
		if not shop.free_cards.has(c):
			other = c
			break
	var res := shop.take_free(other)
	h.check("a card not offered is refused (%s)" % res.msg, not res.ok)
	h.check("and saying why", res.msg.contains("not one of the free cards"))
	h.eq("and the pick is still there to make", shop.free_picks_left, 1)

func test_the_free_card_comes_even_when_you_cannot_afford_anything() -> void:
	## Free means free: a missed quota leaves the bonus pot empty, and the
	## house still hands you the card.
	var r := _run(0)
	var shop := Shop.new(r)
	var res := shop.take_free(shop.free_cards[0])
	h.check("taken with $0 (%s)" % res.msg, res.ok)
	h.eq("and $0 it stays", r.money, 0)

func test_passing_on_the_free_cards_spends_the_pick_and_nothing_else() -> void:
	## The popup's "no thanks": pick one, or none - and the store after it is
	## the same either way.
	var r := _run()
	var shop := Shop.new(r, _profile(1, 1))
	var before: int = r.deck.cards.size()
	var res := shop.pass_on_free()
	h.check("passing is allowed (%s)" % res.msg, res.ok)
	h.eq("and spends the visit's pick", shop.free_picks_left, 0)
	h.eq("adding nothing", r.deck.cards.size(), before)
	h.check("so taking one after is refused", not shop.take_free(shop.free_cards[0]).ok)
	h.check("and the store is still stocked",
		not shop.offers.is_empty() and not shop.upgrade_offers.is_empty())

func test_two_shops_from_one_seed_offer_the_same_cards() -> void:
	var a := Shop.new(_run(), _profile(1, 1))
	var b := Shop.new(_run(), _profile(1, 1))
	h.eq("the same free cards", a.free_cards, b.free_cards)
	h.eq("the same card for sale", a.offers, b.offers)
	h.eq("the same cards of yours to upgrade", a.upgrade_offers, b.upgrade_offers)

func test_buying_adds_the_card_and_debits_the_money() -> void:
	var r := _run()
	var shop := Shop.new(r, _profile(1))
	var def: CardDef = shop.offers[0]
	var before: int = r.deck.cards.size()
	var price: int = shop.buy_price(def)
	h.eq("priced at its rarity's rung", price, r.cfg.card_prices[int(def.rarity)])
	var res := shop.buy(def)
	h.check("bought (%s)" % res.msg, res.ok)
	h.eq("the toolkit grew by one", r.deck.cards.size(), before + 1)
	h.eq("and the money went down by the price", r.money, 10000 - price)
	h.check("it is off the shelf", not shop.offers.has(def))

func test_you_cannot_buy_what_is_not_for_sale() -> void:
	var r := _run()
	var shop := Shop.new(r, _profile(1))
	var res := shop.buy(shop.free_cards[0])
	h.check("a free card is not for sale - it is free (%s)" % res.msg, not res.ok)
	h.eq("and nothing was spent", r.money, 10000)

func test_you_cannot_buy_what_you_cannot_afford() -> void:
	var r := _run(0)
	var shop := Shop.new(r, _profile(1))
	var def: CardDef = shop.offers[0]
	var before: int = r.deck.cards.size()
	var res := shop.buy(def)
	h.check("refused", not res.ok)
	h.eq("and nothing was spent", r.money, 0)
	h.eq("nor added", r.deck.cards.size(), before)

# ---------------------------------------------------------------- the upgrade
func test_upgrading_costs_a_share_of_buying_the_card() -> void:
	## An upgrade costs ShiftConfig.upgrade_price_share of what buying that very
	## card costs on the ladder, whatever the upgrade gains. How big a share is
	## tuning - this checks the formula, not the number.
	var r := _run()
	var shop := Shop.new(r, _profile(0, 1))
	var product: CardInstance = null
	for c in r.deck.cards:
		if c.is_product():
			product = c
			break
	h.check("there is a product in the starter deck", product != null)
	# Imposed rather than hoped for: this is about the PRICE formula, not about
	# whether this seed happened to roll a product into the offer.
	shop.upgrade_offers = [product.uid]
	var p := product.card as ProductCardDef
	var cost: int = roundi(shop.buy_price(p) * r.cfg.upgrade_price_share)
	h.eq("priced at the share of its purchase price", shop.upgrade_price(product), cost)

	var res := shop.upgrade(product.uid)
	h.check("upgraded (%s)" % res.msg, res.ok)
	h.check("the instance knows", product.upgraded)
	h.eq("and it now earns the upgraded margin", product.margin(), p.upgraded_margin)
	h.eq("and it was paid for", r.money, 10000 - cost)

func test_a_card_cannot_be_upgraded_twice() -> void:
	var r := _run()
	var shop := Shop.new(r, _profile(0, 2))
	var uid: int = r.deck.cards[0].uid
	shop.upgrade_offers = [uid]
	var first := shop.upgrade(uid)
	h.check("the first one goes through (%s)" % first.msg, first.ok)
	var money_after_first: int = r.money
	var res := shop.upgrade(uid)
	h.check("refused", not res.ok)
	h.check("because it is already upgraded, not for any other reason (%s)"
		% res.msg, res.msg.to_lower().contains("already upgraded"))
	h.eq("and charged nothing", r.money, money_after_first)

func test_every_upgrade_offer_is_a_real_eligible_uid() -> void:
	var r := _run()
	var shop := Shop.new(r, _profile(0, 1))
	for uid in shop.upgrade_offers:
		var inst := shop.find(uid)
		h.check("uid %d is a real card in the toolkit" % uid, inst != null)
		if inst == null:
			continue
		h.check("%s is not already upgraded" % inst.card.display_name,
			not inst.upgraded)
		h.check("%s actually has an upgrade to sell" % inst.card.display_name,
			shop.upgrade_gain(inst) > 0)

func test_nothing_the_visit_does_rerolls_it() -> void:
	## A visit is a handful of clicks, and the cards on offer must not shuffle
	## themselves out from under a decision the player is still making.
	var r := _run()
	var shop := Shop.new(r, _profile(1, 1))
	var ups := shop.upgrade_offers.duplicate()
	var for_sale := shop.offers.duplicate()
	shop.take_free(shop.free_cards[0])
	h.eq("taking the free card rerolls nothing of yours", shop.upgrade_offers, ups)
	h.eq("or on the shelf", shop.offers, for_sale)
	shop.buy(shop.offers[0])
	h.eq("buying rerolls nothing of yours", shop.upgrade_offers, ups)
	shop.upgrade(ups[0])
	h.eq("and neither does upgrading one of them", shop.upgrade_offers, ups)

func test_a_card_not_on_this_visits_upgrade_offer_refuses_the_upgrade() -> void:
	## Same rule buy() already enforces against `offers` - the random few are
	## a real constraint of the visit, not a suggestion only the view follows.
	var r := _run()
	var shop := Shop.new(r, _profile(0, 1))
	var not_offered: CardInstance = null
	for inst in r.deck.cards:
		if not shop.upgrade_offers.has(inst.uid) and shop.upgrade_gain(inst) > 0:
			not_offered = inst
			break
	h.check("the starter deck has more upgradeable cards than are offered, so one exists",
		not_offered != null)
	var res := shop.upgrade(not_offered.uid)
	h.check("refused (%s)" % res.msg, not res.ok)
	h.check("and says it is not on offer, not that it has no upgrade",
		res.msg.to_lower().contains("not on offer"))
	h.eq("and nothing was spent", r.money, 10000)

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
	## margin_banked only moves through a placed product's Offer, and the shop
	## budget only ever grows by what margin_banked clears the quota BY - so a
	## deck with zero products left can never bank another dollar, and that
	## budget is frozen forever with no other income.
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
