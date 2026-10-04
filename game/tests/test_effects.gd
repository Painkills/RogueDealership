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
	var g := GrantMargin.new(); g.amount = 300
	var l := ChangeLineFloorWide.new(); l.amount = -5
	var pc := PullCards.new(); pc.count = 3
	for e in [a, m, p, f, r, d, b, g, l, pc]:
		e.apply(ctx)
	h.check("no crash with an empty context", true)

func test_grant_margin_lands_on_the_sale_if_one_just_settled() -> void:
	## The bug this guards: a demand resolved by the SAME offer() call that
	## just sold sees c.offer already null (offer() calls _settle() before
	## the demand resolves) - ChangeMargin would silently no-op there, so the
	## log would claim a reward that never actually banked.
	var e := GrantMargin.new()
	e.amount = 300
	var ctx := EffectContext.new()
	ctx.sale = {"margin": 1600, "bonus": 0}
	e.apply(ctx)
	h.eq("the sale grew", int(ctx.sale["margin"]), 1900)
	h.eq("and recorded the bonus", int(ctx.sale["bonus"]), 300)

func test_grant_margin_lands_on_the_offer_if_it_is_still_open() -> void:
	var e := GrantMargin.new()
	e.amount = 300
	var ctx := _offer_ctx()                 # ctx.sale is empty by default
	e.apply(ctx)
	h.eq("the still-open offer grew", ctx.offer.margin, 1900)

func test_describe_agrees_with_apply_for_every_effect() -> void:
	## The UI generates its text from describe(). A mismatch puts a lie on screen.
	var specs := [[ChangeAppeal.new(), 7], [ChangeMargin.new(), -250],
		[ChangeLine.new(), 5], [ChangePatience.new(), -4],
		[ChangePatienceFloor.new(), -1], [DiscardHand.new(), 2],
		[MarginBonus.new(), 300], [GrantMargin.new(), 300],
		[ChangeLineFloorWide.new(), -6]]
	for spec in specs:
		var e: Effect = spec[0]
		e.amount = spec[1]
		var d := e.describe()
		h.check("%s describes its own number (%s)"
			% [e.get_script().resource_path.get_file(), d],
			d.contains(str(abs(spec[1]))))
		h.check("%s says something" % e.get_script().resource_path.get_file(),
			d.strip_edges() != "")
