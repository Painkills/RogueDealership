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

func test_the_shop_never_offers_a_starter_card() -> void:
	## Every run already opens with the starter deck - offering it too would
	## let a run stack duplicates of a card everyone already starts with,
	## instead of the shop being where a run diverges from every other run's.
	var r := _run(1000000)
	var seen_ids := {}
	for _visit in range(30):
		var shop := Shop.new(r)
		for c in shop.offers:
			h.check("%s on the shelf is not a starter card" % c.id, not c.starter)
			seen_ids[c.id] = true
	h.check("this swept at least one real offer across all those visits",
		not seen_ids.is_empty())

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
	# Upgrade offers are a random subset now - imposed here rather than hoped
	# for, since this test is about the PRICE formula, not about whether this
	# particular seed happened to roll a product into the offer.
	shop.upgrade_offers = [product.uid]
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
	# Imposed onto the offer list: the point of this test is "twice", and that
	# needs the FIRST upgrade to actually succeed regardless of what this seed
	# happened to roll.
	shop.upgrade_offers = [uid]
	var first := shop.upgrade(uid)
	h.check("the first one goes through (%s)" % first.msg, first.ok)
	var money_after_first: int = r.money
	var res := shop.upgrade(uid)
	h.check("refused", not res.ok)
	h.check("because it is already upgraded, not because it fell off the offer (%s)"
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
	## margin_banked only moves through a placed product's Offer, and the shop
	## budget only ever grows by what margin_banked clears the quota BY - so a
	## deck with zero products left can never bank another dollar, and that
	## budget is frozen forever with no other income.
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

# --------------------------------------------------------------- rarity odds
func test_shop_offers_favor_lower_rarity_tiers_over_many_rolls() -> void:
	## RARITY_WEIGHTS puts Economy at 3x Preferred's weight, Value in between -
	## not a promise about any one visit, but over enough visits a lower tier
	## should turn up more often than a higher one, not just an even split
	## across whichever tier a card happens to be.
	var counts := {
		CardDef.Rarity.ECONOMY: 0,
		CardDef.Rarity.VALUE: 0,
		CardDef.Rarity.PREFERRED: 0,
	}
	for seed in range(300):
		var r := RunState.new(load("res://data/shift_config.tres"),
			load("res://data/interests/interest_pool.tres"),
			load("res://data/card_pool.tres"),
			load("res://data/archetype_pool.tres"), seed)
		var shop := Shop.new(r)
		for c in shop.offers:
			counts[c.rarity] = counts.get(c.rarity, 0) + 1
	h.check("economy turns up more than value (%d vs %d)"
		% [counts[CardDef.Rarity.ECONOMY], counts[CardDef.Rarity.VALUE]],
		counts[CardDef.Rarity.ECONOMY] > counts[CardDef.Rarity.VALUE])
	h.check("value turns up more than preferred (%d vs %d)"
		% [counts[CardDef.Rarity.VALUE], counts[CardDef.Rarity.PREFERRED]],
		counts[CardDef.Rarity.VALUE] > counts[CardDef.Rarity.PREFERRED])

# --------------------------------------------------------- random upgrade offers
func test_upgrade_offers_are_capped_at_the_configured_slot_count() -> void:
	var r := _run()
	var shop := Shop.new(r)
	h.eq("three slots, like shop_offers", shop.upgrade_offers.size(),
		r.cfg.shop_upgrade_slots)

func test_upgrade_offers_shrink_gracefully_when_fewer_cards_are_eligible() -> void:
	## mini(), not a hard slot count - fewer eligible cards than slots must not
	## crash trying to pop more than exist from the pool.
	var r := _run(10000000)
	var shop := Shop.new(r)
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

	var fresh := Shop.new(r)
	h.eq("offers exactly the one that is left, not the full slot count",
		fresh.upgrade_offers.size(), 1)
	h.eq("and it is that one", fresh.upgrade_offers, [left_eligible.uid])

func test_every_upgrade_offer_is_a_real_eligible_uid() -> void:
	var r := _run()
	var shop := Shop.new(r)
	for uid in shop.upgrade_offers:
		var inst := shop.find(uid)
		h.check("uid %d is a real card in the deck" % uid, inst != null)
		if inst == null:
			continue
		h.check("%s is not already upgraded" % inst.card.display_name,
			not inst.upgraded)
		h.check("%s actually has an upgrade to sell" % inst.card.display_name,
			shop.upgrade_gain(inst) > 0)

func test_upgrade_offers_never_repeat_the_same_card_twice() -> void:
	var r := _run()
	var shop := Shop.new(r)
	var seen := {}
	for uid in shop.upgrade_offers:
		h.check("uid %d offered only once" % uid, not seen.has(uid))
		seen[uid] = true

func test_two_shops_from_one_seed_offer_the_same_upgrades() -> void:
	var a := Shop.new(_run())
	var b := Shop.new(_run())
	h.eq("identical upgrade offers", a.upgrade_offers, b.upgrade_offers)

func test_upgrade_offers_do_not_reroll_across_a_visit() -> void:
	## The same stability `offers` already has: a visit is a handful of clicks,
	## and the shelf must not shuffle itself out from under a decision the
	## player is still making.
	var r := _run()
	var shop := Shop.new(r)
	var before := shop.upgrade_offers.duplicate()
	shop.buy(shop.offers[0])
	h.eq("buying a new card does not reroll it", shop.upgrade_offers, before)
	if not shop.upgrade_offers.is_empty():
		var uid: int = shop.upgrade_offers[0]
		shop.upgrade(uid)
		h.eq("neither does upgrading one of the offered cards",
			shop.upgrade_offers, before)

func test_a_card_not_on_this_visits_upgrade_offer_refuses_the_upgrade() -> void:
	## Same rule buy() already enforces against `offers` - the random subset is
	## a real constraint of the shop, not a suggestion only the view follows.
	var r := _run()
	var shop := Shop.new(r)
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

# --------------------------------------------------- ShiftProfile reward gating

func test_a_profile_with_upgrades_disabled_leaves_upgrade_offers_empty() -> void:
	## Morning's own setting - the rng is never even touched for this roll,
	## but that is an implementation detail; what a caller can observe is that
	## nothing ends up on offer.
	var profile := ShiftProfile.new()
	profile.allow_upgrades_in_shop = false
	var shop := Shop.new(_run(), profile)
	h.check("no upgrades on offer", shop.upgrade_offers.is_empty())

func test_a_null_profile_behaves_exactly_like_todays_default_shop() -> void:
	var shop := Shop.new(_run())
	h.check("upgrades still roll with no profile at all",
		not shop.upgrade_offers.is_empty())
	h.eq("buy_price is the sticker price", shop.buy_price(shop.offers[0]),
		shop.offers[0].price)

func test_dedicated_free_pools_pay_for_their_own_verb_independent_of_order() -> void:
	## Night: a guaranteed free purchase AND a guaranteed free upgrade, no
	## matter which one you reach for first.
	var profile := ShiftProfile.new()
	profile.free_purchases = 1
	profile.free_upgrades = 1
	var r := _run()
	var shop := Shop.new(r, profile)
	var bought: CardDef = shop.offers[0]
	var upgraded_uid: int = shop.upgrade_offers[0]
	h.eq("marked free on the shelf before anything happens",
		shop.buy_price(bought), 0)
	h.eq("marked free on the deck row before anything happens",
		shop.upgrade_price(shop.find(upgraded_uid)), 0)

	var money_before := r.money
	var buy_res := shop.buy(bought)
	h.check("the purchase went through (%s)" % buy_res.msg, buy_res.ok)
	h.eq("and cost nothing", r.money, money_before)
	h.eq("the dedicated purchase pool is spent", shop.free_purchases, 0)

	var upgrade_res := shop.upgrade(upgraded_uid)
	h.check("the upgrade went through too (%s)" % upgrade_res.msg, upgrade_res.ok)
	h.eq("and it ALSO cost nothing - a separate pool, not the same freebie",
		r.money, money_before)
	h.eq("the dedicated upgrade pool is spent", shop.free_upgrades, 0)

func test_shared_free_choice_pays_for_whichever_verb_spends_it_first() -> void:
	## Midday: not pre-marked on any one offer - see Shop.buy_price()'s own
	## comment on why - only resolved the moment you actually buy or upgrade.
	var profile := ShiftProfile.new()
	profile.free_choices = 1
	var r := _run()
	var shop := Shop.new(r, profile)
	var bought: CardDef = shop.offers[0]
	var upgraded_uid: int = shop.upgrade_offers[0]
	h.check("not marked free on the shelf ahead of time",
		shop.buy_price(bought) > 0)
	h.check("not marked free on the deck row ahead of time",
		shop.upgrade_price(shop.find(upgraded_uid)) > 0)

	var money_before := r.money
	var buy_res := shop.buy(bought)
	h.check("the purchase went through (%s)" % buy_res.msg, buy_res.ok)
	h.eq("the first pick is free", r.money, money_before)
	h.eq("the shared pool is now spent", shop.free_choices, 0)

	var upgrade_price_after: int = shop.upgrade_price(shop.find(upgraded_uid))
	var upgrade_res := shop.upgrade(upgraded_uid)
	h.check("the upgrade also goes through (%s)" % upgrade_res.msg, upgrade_res.ok)
	h.eq("but the second pick pays full price - the freebie is already spent",
		r.money, money_before - upgrade_price_after)

func test_shared_free_choice_can_be_spent_on_an_upgrade_first_instead() -> void:
	## The same scenario as above with the two verbs reversed - proving this is
	## genuinely "whichever happens first," not buy() quietly winning ties.
	var profile := ShiftProfile.new()
	profile.free_choices = 1
	var r := _run()
	var shop := Shop.new(r, profile)
	var upgraded_uid: int = shop.upgrade_offers[0]
	var bought: CardDef = shop.offers[0]

	var money_before := r.money
	var upgrade_res := shop.upgrade(upgraded_uid)
	h.check("the upgrade went through (%s)" % upgrade_res.msg, upgrade_res.ok)
	h.eq("upgrading first is free instead", r.money, money_before)

	var buy_price_after: int = shop.buy_price(bought)
	var buy_res := shop.buy(bought)
	h.check("the purchase still goes through (%s)" % buy_res.msg, buy_res.ok)
	h.eq("and now pays full price", r.money, money_before - buy_price_after)

func test_missing_quota_forfeits_every_free_pool_but_keeps_the_tiers_own_shape() -> void:
	## The reward is EARNED, not just picked - see run_controller.gd's own
	## comment on why a free upgrade for failing a harder tier would make
	## failing it better than succeeding at an easier one.
	var profile := ShiftProfile.new()
	profile.allow_upgrades_in_shop = false
	profile.free_purchases = 1
	profile.free_upgrades = 1
	profile.free_choices = 1
	var shop := Shop.new(_run(), profile, false)
	h.eq("no dedicated purchase pool", shop.free_purchases, 0)
	h.eq("no dedicated upgrade pool", shop.free_upgrades, 0)
	h.eq("no shared pool either", shop.free_choices, 0)
	h.check("but the tier's own shop shape is untouched - still purchases only",
		shop.upgrade_offers.is_empty())

func test_missing_quota_still_grants_the_reward_when_told_it_was_earned() -> void:
	## p_earned_reward defaults true - every OTHER reward-gating test above
	## constructs Shop.new(run, profile) with no third argument at all, and
	## this pins down that omitting it still means "the reward applies."
	var profile := ShiftProfile.new()
	profile.free_choices = 1
	var shop := Shop.new(_run(), profile)
	h.eq("the default is earned", shop.free_choices, 1)

func test_perk_text_says_why_the_reward_is_missing_on_a_failed_quota() -> void:
	var profile := ShiftProfile.new()
	profile.free_choices = 1
	var shop := Shop.new(_run(), profile, false)
	h.check("names the reason (%s)" % shop.perk_text(),
		shop.perk_text().to_lower().contains("missed quota"))
