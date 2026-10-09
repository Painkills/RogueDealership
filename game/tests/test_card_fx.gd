extends RefCounted
## Nothing you play is silent: a card of yours records what it did - to the
## customer it was for and to anyone else it touched - the way a customer's own
## actions do, for the view to show as numbers. Built from made-up cards and
## customers.
var h: Harness

func _arch(who: String) -> CustomerArchetype:
	var a := CustomerArchetype.new()
	a.id = StringName(who)
	a.display_name = who
	a.line = 20
	a.patience = 20
	a.line_per_sale = 0
	a.combo_step = 0.0
	return a

## Two customers on the floor, you at the first, with a product on their table.
## [shift, first, second].
func _floor() -> Array:
	var cfg: ShiftConfig = (load("res://data/shift_config.tres") as ShiftConfig).duplicate()
	cfg.patience_jitter = 0
	cfg.action_cadence_jitter_ticks = 0
	cfg.arrival_patience_min_fraction = 1.0
	var lineup: Array[CustomerArchetype] = [_arch("first"), _arch("second")]
	var s := Shift.new(cfg, load("res://data/interests/interest_pool.tres"),
		load("res://data/card_pool.tres"), load("res://data/archetype_pool.tres"),
		7, [], null, 1500, 1, 0, 0, null, 2, 1.0, 1.0, [], lineup, [], {})
	s.at = 0
	s.last_customer = s.chairs[0]
	var product: ProductCardDef = null
	for def in (load("res://data/card_pool.tres") as CardPool).cards:
		if def is ProductCardDef:
			product = def
			break
	s.hand.clear()
	s.hand.append(CardInstance.new(product, 900))
	var placed := s.place(0)
	assert(placed.ok)
	return [s, s.chairs[0], s.chairs[1]]

func _play(s: Shift, effects: Array[Effect]) -> Dictionary:
	var def := SupportCardDef.new()
	def.id = &"made_up_card"
	def.display_name = "Made-up card"
	def.ticks = 1
	def.effects = effects
	s.hand.clear()
	s.hand.append(CardInstance.new(def, 901))
	var played := s.play_card(0)
	assert(played.ok)
	return s.action_log.filter(func(e): return e["name"] == "Made-up card")[-1]

func _effect(e: Effect, amount: int) -> Effect:
	e.amount = amount
	return e

func test_a_card_says_what_it_moved_on_the_customer_it_was_for() -> void:
	var pair := _floor()
	var s: Shift = pair[0]
	var c: Customer = pair[1]
	c.patience = 5
	var effects: Array[Effect] = [_effect(ChangePatience.new(), 3), _effect(ChangeLine.new(), -2),
		_effect(ChangeMargin.new(), 300)]
	var entry := _play(s, effects)
	var fx: Dictionary = entry["fx"]
	h.check("marked as yours", bool(entry.get("yours", false)))
	h.eq("the patience it gave", int(fx["patience"]), 3)
	h.eq("the Line it lowered, though the Line is hidden", int(fx["line"]), -2)
	h.eq("the money it put on the product", int(fx["margin"]), 300)

func test_a_card_that_costs_standing_says_so() -> void:
	var pair := _floor()
	var s: Shift = pair[0]
	var effects: Array[Effect] = [_effect(ChangeStanding.new(), -1)]
	h.eq("standing, once", int(_play(s, effects)["fx"]["standing"]), -1)

func test_a_card_that_hits_the_whole_floor_says_what_it_did_to_each_of_them() -> void:
	var pair := _floor()
	var s: Shift = pair[0]
	var other: Customer = pair[2]
	var effects: Array[Effect] = [_effect(ChangePatienceFloor.new(), -2)]
	var entry := _play(s, effects)
	var others: Array = entry["fx_others"]
	h.eq("one other customer touched", others.size(), 1)
	h.eq("the right one", str(others[0]["key"]), other.key)
	h.eq("by what it did to them", int(others[0]["fx"]["patience"]), -2)
	h.eq("and the standing is not counted twice", int(others[0]["fx"]["standing"]), 0)

func test_a_card_that_moves_no_number_still_logs_what_it_does() -> void:
	var pair := _floor()
	var s: Shift = pair[0]
	var none: Array[Effect] = []
	var entry := _play(s, none)
	h.check("no numbers", int(entry["fx"]["patience"]) == 0 and int(entry["fx"]["line"]) == 0
		and int(entry["fx"]["margin"]) == 0)
	h.check("and words to say so instead", not (entry["descriptions"] as Array).is_empty())
	h.eq("and nobody else was touched", (entry["fx_others"] as Array).size(), 0)
