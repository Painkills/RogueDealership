extends RefCounted
## What an upgrade changes, said in words for the store (CardText.upgrade_changes())
## - "in case someone doesn't notice that it's not the effect that changes but
## the cost." Made-up cards, so it stays true whatever the shipped ones become.
var h: Harness

func _support(ticks: int, upgraded_ticks: int, amount: int, upgraded_amount: int) -> SupportCardDef:
	var d := SupportCardDef.new()
	d.id = &"made_up_support"
	d.display_name = "Made-up Support"
	d.ticks = ticks
	d.upgraded_ticks = upgraded_ticks
	var e := ChangeAppeal.new()
	e.amount = amount
	d.effects = [e]
	if upgraded_amount != amount:
		var u := ChangeAppeal.new()
		u.amount = upgraded_amount
		d.upgraded_effects = [u]
	return d

func _pair(def: CardDef) -> Array:
	var before := CardInstance.new(def, 1)
	var after := CardInstance.new(def, 1)
	after.upgraded = true
	return [before, after]

func test_a_cheaper_card_says_only_the_cost_changed() -> void:
	var p := _pair(_support(1, 0, 4, 4))
	var changes := CardText.upgrade_changes(p[0], p[1])
	h.eq("one change", changes.size(), 1)
	h.eq("the cost", changes[0], "costs 0 ticks instead of 1")

func test_a_stronger_card_says_what_it_does_now() -> void:
	var p := _pair(_support(1, -1, 4, 6))
	var changes := CardText.upgrade_changes(p[0], p[1])
	h.eq("one change", changes.size(), 1)
	h.check("what it does, then and now (%s)" % changes[0],
		changes[0].contains(CardText.body(p[1])) and changes[0].contains(CardText.body(p[0])))

func test_a_product_says_what_it_pays_now() -> void:
	var d := ProductCardDef.new()
	d.id = &"made_up_product"
	d.display_name = "Made-up Product"
	d.interest = (load("res://data/interests/interest_pool.tres") as InterestPool).interests[0]
	d.margin = 1000
	d.upgraded_margin = 1250
	var p := _pair(d)
	var changes := CardText.upgrade_changes(p[0], p[1])
	h.eq("the price, then and now", changes,
		["pays %s instead of %s" % [Format.money(1250), Format.money(1000)]])
