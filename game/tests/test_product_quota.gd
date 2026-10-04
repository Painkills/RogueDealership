extends RefCounted
## The boss's product quota: from the week ShiftConfig names, every shift but a
## boss day's has to sell so many products from the day's category, or lose
## standing at the end of it. Checked against a made-up config, so no tuning is
## pinned here.
var h: Harness

func _cfg(by_week: Array[int], cost: int = 7) -> ShiftConfig:
	var cfg := (load("res://data/shift_config.tres") as ShiftConfig).duplicate() as ShiftConfig
	cfg.category_quota_by_week = by_week
	cfg.category_quota_standing = cost
	return cfg

func _run(cfg: ShiftConfig, seed_value: int = 11) -> RunState:
	return RunState.new(cfg, load("res://data/interests/interest_pool.tres"),
		load("res://data/card_pool.tres"), load("res://data/archetype_pool.tres"), seed_value)

## A product whose interest is (or, with `inside` false, is not) in `category`.
func _product(s: Shift, category: StringName, inside: bool) -> CardDef:
	for c in s.card_pool.cards:
		if c is ProductCardDef and ((c as ProductCardDef).interest.category.id == category) == inside:
			return c
	return null

## Sells `def` to whoever sits in `chair` and has them sign - Line at nothing,
## so it is a sale whatever they think of it.
func _sell(s: Shift, chair: int, def: CardDef) -> void:
	s.at = chair
	var c: Customer = s.chairs[chair]
	c.line = 0
	s.hand.clear()
	s.hand.append(CardInstance.new(def, 900 + chair))
	s.place(0)
	s.offer()
	s.close()

func test_a_day_keeps_its_category_and_asking_never_moves_the_dice() -> void:
	var r := _run(_cfg([3]))
	var state := r.rng.state
	var first = r.category_quota(4)["category"]
	for _i in range(5):
		h.check("asked again, the same category", r.category_quota(4)["category"] == first)
	h.eq("and the run's own generator never moved", r.rng.state, state)

func test_a_shift_carries_it_but_a_boss_day_does_not() -> void:
	var r := _run(_cfg([2]))
	var s := r.start_shift(ShiftProfile.new())
	h.eq("the shift asks for the day's number", s.category_quota_count, 2)
	h.eq("of the day's category", s.category_quota,
		(r.category_quota(1)["category"] as Category).id)
	var boss := ShiftProfile.new()
	var category := ShiftCategory.new()
	category.boss_day = true
	boss.dealt_by = category
	h.eq("a boss day has none", r.start_shift(boss).category_quota_count, 0)

func test_only_its_category_counts() -> void:
	var r := _run(_cfg([2]))
	var s := r.start_shift(ShiftProfile.new())
	_sell(s, 0, _product(s, s.category_quota, false))
	h.eq("a product from another category does not count", s.category_sold, 0)
	_sell(s, 1, _product(s, s.category_quota, true))
	h.eq("one from the day's does", s.category_sold, 1)

func test_a_product_agreed_to_shows_as_unsigned_and_counts_only_once_signed() -> void:
	## "I sold WALKAWAY GAP, a Deal product, and had 0/2": agreeing to a product
	## leaves it unsigned until the customer is closed. It must show, and not
	## count - unsigned deals are lost at the bell.
	var r := _run(_cfg([2]))
	var s := r.start_shift(ShiftProfile.new())
	var inside := _product(s, s.category_quota, true)
	s.at = 0
	var c: Customer = s.chairs[0]
	c.line = 0
	s.hand.clear()
	s.hand.append(CardInstance.new(inside, 900))
	s.place(0)
	s.offer()
	h.eq("agreed to: it shows as unsigned", s.category_unsigned(), 1)
	h.eq("but is not counted yet", s.category_sold, 0)
	s.close()
	h.eq("signed: it counts", s.category_sold, 1)
	h.eq("and is no longer unsigned", s.category_unsigned(), 0)

func test_missing_it_costs_standing_and_meeting_it_does_not() -> void:
	var r := _run(_cfg([2], 7))
	var short := r.start_shift(ShiftProfile.new())
	var report := short.report()
	h.eq("nothing sold: it costs the configured standing", report["category_quota_cost"], 7)
	var with_cost: int = short._standing_delta()
	short.category_quota_count = 0
	h.eq("and that much comes off the shift's standing", short._standing_delta() - with_cost, 7)

	var met := _run(_cfg([2], 7)).start_shift(ShiftProfile.new())
	var inside := _product(met, met.category_quota, true)
	_sell(met, 0, inside)
	_sell(met, 1, inside)
	h.eq("two from the day's category: met", met.category_sold, 2)
	h.eq("and free", met.report()["category_quota_cost"], 0)
