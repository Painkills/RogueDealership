extends RefCounted
## What a customer's action did, logged for the floor to show happening - the
## "fx" on its action_log entry. Made-up actions only.
var h: Harness

func _shift() -> Shift:
	return Shift.new(load("res://data/shift_config.tres"),
		load("res://data/interests/interest_pool.tres"),
		load("res://data/card_pool.tres"), load("res://data/archetype_pool.tres"), 3)

## Gives `c` exactly one action - on a copy of their archetype, never the
## shared resource.
func _give(c: Customer, effects: Array[Effect]) -> void:
	var act := CustomerAction.new()
	act.id = &"made_up"
	act.display_name = "Does a thing"
	act.trigger = OnPlace.new()
	act.effects = effects
	c.archetype = c.archetype.duplicate()
	var acts: Array[CustomerAction] = [act]
	c.archetype.actions = acts

func _place_a_product(s: Shift) -> void:
	var product: CardDef = s.card_pool.cards.filter(func(d): return d is ProductCardDef)[0]
	s.hand[0] = CardInstance.new(product, 999)
	s.place(0)

func test_an_action_logs_the_money_it_moved_and_a_product_it_swept() -> void:
	var s := _shift()
	var c: Customer = s.chairs[0]
	var money := GrantMargin.new()
	money.amount = 300
	var standing := ChangeStanding.new()
	standing.amount = -3
	_give(c, [money, standing])
	_place_a_product(s)
	var fx: Dictionary = s.action_log.filter(func(e): return e["name"] == "Does a thing")[-1]["fx"]
	h.eq("the money it added", int(fx["margin"]), 300)
	h.eq("the standing it cost", int(fx["standing"]), -3)
	h.eq("and no sweep", int(fx["swept"]), -1)

	var s2 := _shift()
	var c2: Customer = s2.chairs[0]
	_give(c2, [DropOffer.new()])
	_place_a_product(s2)
	var fx2: Dictionary = s2.action_log.filter(func(e): return e["name"] == "Does a thing")[-1]["fx"]
	h.eq("the product it swept, by uid", int(fx2["swept"]), 999)
	h.eq("and a product off the table is not money lost", int(fx2["margin"]), 0)
