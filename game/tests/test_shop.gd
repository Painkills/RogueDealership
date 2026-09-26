extends RefCounted
## The whole meta layer: a free card every visit, and whatever the shift you
## just worked adds to it - a card to buy, or one of yours to upgrade - plus
## dropping a card you no longer want.
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

func _shipped(id: StringName) -> ShiftProfile:
	return (load("res://data/shift_profile_pool.tres") as ShiftProfilePool).by_id(id)

func test_every_card_carries_a_price() -> void:
	## Support cards have no margin to derive a price from, so it is authored.
	var pool: CardPool = load("res://data/card_pool.tres")
	for c in pool.cards:
		h.check("%s is priced" % c.id, c.price > 0)

# ------------------------------------------------------------- the free card
func test_every_visit_offers_three_free_cards_to_pick_one_from() -> void:
	## "The free offer should offer three card options, out of which the player
	## picks ONE." Whatever the tier - even none at all.
	h.eq("three options, as asked",
		(load("res://data/shift_config.tres") as ShiftConfig).free_card_choices, 3)
	for p in [null, _shipped(&"morning"), _shipped(&"midday"), _shipped(&"night")]:
		var shop := Shop.new(_run(), p)
		var which: String = "no tier" if p == null else String(p.id)
		h.eq("%s: three cards on the house" % which, shop.free_cards.size(), 3)
		h.eq("%s: and one pick of them" % which, shop.free_picks_left, 1)
	var r := _run()
	var shop := Shop.new(r)
	var known := {}
	for c in r.card_pool.cards:
		known[c.id] = true
	var seen := {}
	for c in shop.free_cards:
		h.check("%s is a real card" % c.id, known.has(c.id))
		h.check("%s is offered only once" % c.id, not seen.has(c.id))
		seen[c.id] = true

func test_the_free_cards_are_never_starter_cards() -> void:
	## Every run already opens with the starter deck - handing it out as well
	## would stack duplicates of what everyone starts with, instead of this
	## being where a run diverges from every other run's.
	var r := _run(1000000)
	for _visit in range(30):
		var shop := Shop.new(r, _profile(1))
		for c in shop.free_cards + shop.offers:
			h.check("%s on offer is not a starter card" % c.id, not c.starter)

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
	h.eq("of three more", next.free_cards.size(), 3)

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

func test_leaving_the_free_cards_is_allowed() -> void:
	## Pick one, or none. A deckbuilder that forced a card on you every visit
	## would thin nothing and bloat everything.
	var r := _run()
	var before: int = r.deck.cards.size()
	var _shop := Shop.new(r)
	h.eq("visiting and walking out changes nothing", r.deck.cards.size(), before)

# ----------------------------------------------------------- what each tier adds
func test_the_shipped_tiers_add_what_was_asked_for() -> void:
	## "At the end of midday shift, offer a chance to buy one card (on top of
	## the single free card). At the end of night shift offer the chance to
	## upgrade one card (on top of the single free card)." The literal numbers,
	## not the profiles read back against themselves.
	var morning := _shipped(&"morning")
	var midday := _shipped(&"midday")
	var night := _shipped(&"night")
	h.eq("morning: nothing for sale", morning.cards_for_sale, 0)
	h.eq("morning: no upgrade", morning.upgrades, 0)
	h.eq("midday: one card for sale", midday.cards_for_sale, 1)
	h.eq("midday: no upgrade", midday.upgrades, 0)
	h.eq("night: nothing for sale", night.cards_for_sale, 0)
	h.eq("night: one upgrade", night.upgrades, 1)

func test_no_tier_means_the_free_card_and_nothing_else() -> void:
	var shop := Shop.new(_run())
	h.check("nothing for sale", shop.offers.is_empty())
	h.check("nothing of yours to upgrade", shop.upgrade_offers.is_empty())
	h.eq("and no upgrade to spend", shop.upgrades_left, 0)

func test_a_card_for_sale_is_one_card_and_not_the_free_one() -> void:
	for seed_value in range(1, 40):
		var shop := Shop.new(_run(10000, seed_value), _profile(1))
		h.eq("seed %d: exactly one for sale" % seed_value, shop.offers.size(), 1)
		h.check("seed %d: and never one you could have had free" % seed_value,
			not shop.free_cards.has(shop.offers[0]))

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
	h.eq("priced at its sticker price", price, def.price)
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

func test_perk_text_says_what_the_visit_holds_beyond_the_free_card() -> void:
	h.check("no tier: just the free card (%s)" % Shop.new(_run()).perk_text(),
		Shop.new(_run()).perk_text().contains("free card"))
	var midday := Shop.new(_run(), _shipped(&"midday")).perk_text()
	h.check("midday: a card for sale (%s)" % midday, midday.contains("for sale"))
	var night := Shop.new(_run(), _shipped(&"night")).perk_text()
	h.check("night: an upgrade (%s)" % night, night.contains("upgrade"))

func test_the_picker_previews_the_same_visit() -> void:
	for id in [&"morning", &"midday", &"night"]:
		h.check("%s promises the free card (%s)" % [id, _shipped(id).reward_preview()],
			_shipped(id).reward_preview().contains("free card"))
	h.check("midday promises a card to buy",
		_shipped(&"midday").reward_preview().contains("buy"))
	h.check("night promises an upgrade",
		_shipped(&"night").reward_preview().contains("upgrade"))
	h.check("and morning promises neither",
		not _shipped(&"morning").reward_preview().contains("buy")
			and not _shipped(&"morning").reward_preview().contains("upgrade"))

# ---------------------------------------------------------------- the upgrade
func test_upgrading_costs_a_multiple_of_what_it_gains() -> void:
	## Both the gain and the price scale with the card, so a percentage upgrade
	## is value-neutral across the margin ladder - the decision is which product
	## you actually sell, not which number is biggest.
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
	var gain: int = p.upgraded_margin - p.margin
	h.eq("priced at the multiple of the gain", shop.upgrade_price(product),
		gain * r.cfg.upgrade_price_multiple)

	var res := shop.upgrade(product.uid)
	h.check("upgraded (%s)" % res.msg, res.ok)
	h.check("the instance knows", product.upgraded)
	h.eq("and it now earns the upgraded margin", product.margin(), p.upgraded_margin)
	h.eq("and it was paid for", r.money, 10000 - gain * r.cfg.upgrade_price_multiple)

func test_a_night_upgrades_one_card_and_only_one() -> void:
	## "The chance to upgrade ONE card." A few of yours are on show to choose
	## from; once one is upgraded, the visit's upgrade is spent.
	var r := _run(1000000)
	var shop := Shop.new(r, _profile(0, 1))
	h.check("a choice of cards to upgrade (%d)" % shop.upgrade_offers.size(),
		shop.upgrade_offers.size() >= 2)
	var first := shop.upgrade(shop.upgrade_offers[0])
	h.check("the first goes through (%s)" % first.msg, first.ok)
	h.eq("and spends the visit's upgrade", shop.upgrades_left, 0)
	var money_after: int = r.money
	var second_uid: int = shop.upgrade_offers[1]
	var second := shop.upgrade(second_uid)
	h.check("a second is refused (%s)" % second.msg, not second.ok)
	h.check("because the upgrade is used, not for any other reason",
		second.msg.to_lower().contains("used"))
	h.eq("and charged nothing", r.money, money_after)
	h.check("and left that card as it was", not shop.find(second_uid).upgraded)
	h.check("the rest stay on show - nothing re-rolled",
		shop.upgrade_offers.has(second_uid))

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
	var shop := Shop.new(r, _profile(0, 1))
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
	var shop := Shop.new(r, _profile(0, 1))
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

func test_upgrade_offers_are_capped_at_the_configured_slot_count() -> void:
	var r := _run()
	var shop := Shop.new(r, _profile(0, 1))
	h.eq("a few to choose from, not the whole toolkit", shop.upgrade_offers.size(),
		r.cfg.shop_upgrade_slots)

func test_upgrade_offers_shrink_gracefully_when_fewer_cards_are_eligible() -> void:
	## mini(), not a hard slot count - fewer eligible cards than slots must not
	## crash trying to pop more than exist from the pool.
	var r := _run(10000000)
	var shop := Shop.new(r, _profile(0, 99))
	# Upgrade everything eligible except ONE, so the next shop's pool of
	# eligible cards is down to exactly one - well under the configured 3.
	var left_eligible: CardInstance = null
	for inst in r.deck.cards:
		if shop.upgrade_gain(inst) <= 0:
			continue
		if left_eligible == null:
			left_eligible = inst
			continue
		shop.upgrade_offers = [inst.uid]   # imposed, so every upgrade lands
		shop.upgrade(inst.uid)
	h.check("left exactly one eligible card behind", left_eligible != null)

	var fresh := Shop.new(r, _profile(0, 1))
	h.eq("offers exactly the one that is left, not the full slot count",
		fresh.upgrade_offers.size(), 1)
	h.eq("and it is that one", fresh.upgrade_offers, [left_eligible.uid])

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

func test_upgrade_offers_never_repeat_the_same_card_twice() -> void:
	var r := _run()
	var shop := Shop.new(r, _profile(0, 1))
	var seen := {}
	for uid in shop.upgrade_offers:
		h.check("uid %d offered only once" % uid, not seen.has(uid))
		seen[uid] = true

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
	h.check("the starter deck has more upgradeable cards than slots, so one exists",
		not_offered != null)
	var res := shop.upgrade(not_offered.uid)
	h.check("refused (%s)" % res.msg, not res.ok)
	h.check("and says it is not on offer, not that it has no upgrade",
		res.msg.to_lower().contains("not on offer"))
	h.eq("and nothing was spent", r.money, 10000)

# ------------------------------------------------------------------- dropping
func test_removing_thins_the_toolkit() -> void:
	var r := _run()
	var shop := Shop.new(r)
	var uid: int = r.deck.cards[0].uid
	var before: int = r.deck.cards.size()
	var res := shop.remove(uid)
	h.check("removed (%s)" % res.msg, res.ok)
	h.eq("the toolkit shrank by one", r.deck.cards.size(), before - 1)
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

# --------------------------------------------------------------- rarity odds
func test_the_cards_on_offer_favor_lower_rarity_tiers_over_many_rolls() -> void:
	## RARITY_WEIGHTS puts Economy at 3x Preferred's weight, Value in between -
	## not a promise about any one visit, but over enough visits a lower tier
	## should turn up more often than a higher one, not just an even split
	## across whichever tier a card happens to be.
	var counts := {
		CardDef.Rarity.ECONOMY: 0,
		CardDef.Rarity.VALUE: 0,
		CardDef.Rarity.PREFERRED: 0,
	}
	for seed_value in range(300):
		var shop := Shop.new(_run(10000, seed_value), _profile(1))
		for c in shop.free_cards + shop.offers:
			counts[c.rarity] = counts.get(c.rarity, 0) + 1
	h.check("economy turns up more than value (%d vs %d)"
		% [counts[CardDef.Rarity.ECONOMY], counts[CardDef.Rarity.VALUE]],
		counts[CardDef.Rarity.ECONOMY] > counts[CardDef.Rarity.VALUE])
	h.check("value turns up more than preferred (%d vs %d)"
		% [counts[CardDef.Rarity.VALUE], counts[CardDef.Rarity.PREFERRED]],
		counts[CardDef.Rarity.VALUE] > counts[CardDef.Rarity.PREFERRED])
