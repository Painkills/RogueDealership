extends RefCounted
## Asking for the business: only once they would say yes. An offer short of the
## Line is refused outright - at no cost - and what it would once have taught is
## on the grid from the moment the product is placed. Built from a made-up
## customer and any product in the pool, with every number read off the customer
## it is for.
var h: Harness

func _cfg() -> ShiftConfig:
	var cfg: ShiftConfig = (load("res://data/shift_config.tres") as ShiftConfig).duplicate()
	cfg.patience_jitter = 0
	cfg.action_cadence_jitter_ticks = 0
	cfg.arrival_patience_min_fraction = 1.0
	return cfg

## A plain customer alone on the floor, and a product of yours in hand - any from
## the pool, never one named. [shift, customer, product card]. Their Line sits
## `over` above what the product opens at, once it is on the table.
func _with_a_product_on_the_table(over: int, concession_past_rank: int = 0) -> Array:
	var arch := CustomerArchetype.new()
	arch.id = &"made_up_customer"
	arch.display_name = "Made-up Customer"
	arch.line = 20
	arch.patience = 20
	arch.line_per_sale = 0
	arch.combo_step = 0.0
	arch.needs_concession_past_rank = concession_past_rank
	var lineup: Array[CustomerArchetype] = [arch]
	var s := Shift.new(_cfg(), load("res://data/interests/interest_pool.tres"),
		load("res://data/card_pool.tres"), load("res://data/archetype_pool.tres"),
		7, [], null, 1500, 1, 0, 0, null, 1, 1.0, 1.0, [], lineup, [], {})
	var c: Customer = s.chairs[0]
	s.at = 0
	s.last_customer = c
	var product: ProductCardDef = null
	for def in (load("res://data/card_pool.tres") as CardPool).cards:
		if def is ProductCardDef:
			product = def
			break
	s.hand.clear()
	s.hand.append(CardInstance.new(product, 900))
	c.line = c.appeal_for(product.interest.id) + over
	var placed := s.place(0)
	assert(placed.ok)
	return [s, c, product]

func test_an_offer_short_of_the_line_is_refused_and_costs_nothing() -> void:
	var pair := _with_a_product_on_the_table(1)
	var s: Shift = pair[0]
	var c: Customer = pair[1]
	var patience: int = c.patience
	var tick: int = s.tick
	var banked: int = s.margin_banked
	var r := s.offer()
	h.check("refused", not r.ok)
	h.check("with words to say why", r.msg != "")
	h.eq("no patience lost", c.patience, patience)
	h.eq("no tick spent", s.tick, tick)
	h.eq("nothing signed or sold", [c.unsigned.size(), s.margin_banked], [0, banked])
	h.check("the product is still on the table", c.offer != null)

func test_the_refusal_does_not_give_the_number_away() -> void:
	var pair := _with_a_product_on_the_table(7)
	var r: Result = (pair[0] as Shift).offer()
	h.check("no figure for how far short it is", not r.msg.contains("7"))
	h.check("and none in the result's data", not r.data.has("short"))

func test_an_offer_at_the_line_goes_through() -> void:
	var pair := _with_a_product_on_the_table(0)
	var c: Customer = pair[1]
	var r: Result = (pair[0] as Shift).offer()
	h.check("accepted", r.ok)
	h.eq("and agreed to", c.unsigned.size(), 1)

func test_asking_too_soon_is_counted_but_never_as_a_sale() -> void:
	var pair := _with_a_product_on_the_table(2)
	var s: Shift = pair[0]
	s.offer()
	s.offer()
	var report := s.report()
	h.eq("two attempts", report["offers"], 2)
	h.eq("both turned away", report["failed_offers"], 2)
	h.eq("and no sales", report["sales"], 0)

func test_a_refused_offer_does_not_answer_a_demand_to_be_asked() -> void:
	var pair := _with_a_product_on_the_table(2)
	var s: Shift = pair[0]
	var c: Customer = pair[1]
	var d := Demand.new()
	d.id = &"made_up_ask"
	d.display_name = "Made-up ask"
	d.telegraph = "ASK"
	d.ticks = 5
	d.resolve = MakeAnOffer.new()
	c.ticks_on_floor = 10   # long enough in the chair to be asked anything
	h.check("raised", s.raise_demand(c, d))
	s.offer()
	h.check("still waiting to be asked", c.demand == d)
	# Lift them over the line and ask for real.
	c.offer.appeal = c.line
	s.offer()
	h.check("answered once it was a real offer", c.demand == null)

func test_a_customer_who_holds_out_for_a_concession_refuses_until_one_is_made() -> void:
	# Past the very first rank, whatever the product is: any rank but their number
	# one needs a concession, so the made-up customer is sure to want one.
	var pair := _with_a_product_on_the_table(0, 1)
	var s: Shift = pair[0]
	var c: Customer = pair[1]
	var product: ProductCardDef = pair[2]
	c.ranks[product.interest.id] = 2
	h.check("a product ranked second, past their first", s.holds_out_for_a_concession(c))
	var tick: int = s.tick
	var r := s.offer()
	h.check("is refused even though it clears the Line", not r.ok)
	h.eq("at no cost", [c.unsigned.size(), s.tick], [0, tick])
	c.offer.conceded = true
	h.check("and goes through once something has been conceded", s.offer().ok)

func test_where_it_ranks_is_known_the_moment_it_is_placed() -> void:
	var pair := _with_a_product_on_the_table(3)
	var c: Customer = pair[1]
	var product: ProductCardDef = pair[2]
	h.check("on the grid without having asked", c.known_ranks.has(product.interest.id))
	h.eq("at the rank it really has", c.known_ranks[product.interest.id],
		int(c.ranks[product.interest.id]))
	h.check("but not their Line", not c.known_line)
