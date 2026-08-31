extends RefCounted
var h: Harness

func _pool() -> CardPool:
	return load("res://data/card_pool.tres")

func _offer_ctx() -> EffectContext:
	var ctx := EffectContext.new()
	ctx.offer = Offer.new(CardInstance.new(_pool().by_id(&"vsc"), 1), 30, 1600)
	return ctx

func test_change_appeal_moves_the_offer_and_says_so() -> void:
	var e := ChangeAppeal.new()
	e.amount = 4
	var ctx := _offer_ctx()
	e.apply(ctx)
	h.eq("appeal moved", ctx.offer.appeal, 34)
	h.check("and describes itself", e.describe().contains("4"))

func test_change_margin_moves_money() -> void:
	var e := ChangeMargin.new()
	e.amount = -300
	var ctx := _offer_ctx()
	e.apply(ctx)
	h.eq("margin conceded", ctx.offer.margin, 1300)

func test_effects_that_need_an_offer_are_safe_without_one() -> void:
	var ctx := EffectContext.new()          # nothing on the table
	var a := ChangeAppeal.new(); a.amount = 4
	var m := ChangeMargin.new(); m.amount = -300
	var p := ChangePatience.new(); p.amount = 5
	var f := ChangePatienceFloor.new(); f.amount = -1
	var r := RevealRoom.new()
	var d := DiscardHand.new(); d.amount = 1
	var b := MarginBonus.new(); b.amount = 300
	for e in [a, m, p, f, r, d, b]:
		e.apply(ctx)
	h.check("no crash with an empty context", true)

func test_scale_by_sales_multiplies_the_wrapped_effect() -> void:
	var inner := ChangeAppeal.new()
	inner.amount = 4
	var e := ScaleBySales.new()
	e.inner = inner
	var ctx := _offer_ctx()
	ctx.sales_so_far = 3
	e.apply(ctx)
	h.eq("+4 per product already taken", ctx.offer.appeal, 30 + 12)

func test_scale_by_sales_is_worth_nothing_on_a_first_offer() -> void:
	var inner := ChangeAppeal.new()
	inner.amount = 4
	var e := ScaleBySales.new()
	e.inner = inner
	var ctx := _offer_ctx()
	ctx.sales_so_far = 0
	e.apply(ctx)
	h.eq("nothing yet", ctx.offer.appeal, 30)

func test_margin_bonus_lands_on_the_sale_not_the_offer() -> void:
	var e := MarginBonus.new()
	e.amount = 300
	var ctx := _offer_ctx()
	ctx.sale = {"margin": 1600, "bonus": 0}
	e.apply(ctx)
	h.eq("the sale grew", int(ctx.sale["margin"]), 1900)
	h.eq("and recorded the bonus", int(ctx.sale["bonus"]), 300)
	h.eq("the offer is untouched", ctx.offer.margin, 1600)

func test_describe_agrees_with_apply_for_every_effect() -> void:
	## The UI generates its text from describe(). A mismatch puts a lie on screen.
	var specs := [[ChangeAppeal.new(), 7], [ChangeMargin.new(), -250],
		[ChangeLine.new(), 5], [ChangePatience.new(), -4],
		[ChangePatienceFloor.new(), -1], [DiscardHand.new(), 2],
		[MarginBonus.new(), 300]]
	for spec in specs:
		var e: Effect = spec[0]
		e.amount = spec[1]
		var d := e.describe()
		h.check("%s describes its own number (%s)"
			% [e.get_script().resource_path.get_file(), d],
			d.contains(str(abs(spec[1]))))
		h.check("%s says something" % e.get_script().resource_path.get_file(),
			d.strip_edges() != "")

func test_the_starter_deck_is_fourteen_cards() -> void:
	var total := 0
	var products := 0
	for c in _pool().starter_cards():
		total += c.copies
		if c is ProductCardDef:
			products += c.copies
	h.eq("fourteen cards", total, 14)
	h.eq("six of them products", products, 6)
	h.eq("eight support", total - products, 8)

func test_no_starter_card_moves_a_full_place_on_their_list_for_free() -> void:
	## m2's rule: a card worth a whole rank step becomes a substitute for
	## reading the customer, and diagnosis stops paying.
	## appeal_step lives on ShiftConfig from Task 6; pinned here so the rule is
	## enforced from the moment cards exist.
	var appeal_step := 5
	for c in _pool().cards:
		if not (c is SupportCardDef):
			continue
		var free := true
		var appeal := 0
		for e in (c as SupportCardDef).effects:
			if e is ChangeAppeal:
				appeal += e.amount
			elif e is ChangeMargin and e.amount < 0:
				free = false
			elif e is ChangePatience and e.amount < 0:
				free = false
		if free and c.ticks <= 1:
			h.check("%s moves less than one place (%d < %d)"
				% [c.id, appeal, appeal_step], appeal < appeal_step)
