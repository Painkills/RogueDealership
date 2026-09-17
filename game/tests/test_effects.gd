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
	# One application always, plus one more per product already taken -
	# four applications total at 3 sales, not three.
	h.eq("+4 once, then +4 per product already taken", ctx.offer.appeal, 30 + 16)

func test_scale_by_sales_still_applies_once_on_a_first_offer() -> void:
	var inner := ChangeAppeal.new()
	inner.amount = 4
	var e := ScaleBySales.new()
	e.inner = inner
	var ctx := _offer_ctx()
	ctx.sales_so_far = 0
	e.apply(ctx)
	h.eq("the base application still lands with no sales yet",
		ctx.offer.appeal, 30 + 4)

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

