extends RefCounted
## A boss fight - the Whale's rules, built from made-up bosses and moves so none
## of it rides on what ships or how it is tuned: a budget you sell down to
## nothing, telegraphed moves that hit your standing, patience as the shield
## those hits come out of first, the rounds that make it harder, and a shift
## with no clock that ends when the boss is dealt with.
var h: Harness

func _cfg() -> ShiftConfig:
	var cfg: ShiftConfig = (load("res://data/shift_config.tres") as ShiftConfig).duplicate()
	cfg.patience_jitter = 0
	cfg.action_cadence_jitter_ticks = 0
	cfg.arrival_patience_min_fraction = 1.0
	return cfg

func _move(id: StringName, hit: int, fuse: int, resolve: DemandResolve = null,
		needs_offer: bool = false, line: int = 0) -> Demand:
	var d := Demand.new()
	d.id = id
	d.display_name = String(id).capitalize()
	d.telegraph = String(id).to_upper()
	d.ticks = fuse
	d.resolve = resolve
	d.needs_offer_on_table = needs_offer
	if hit > 0:
		var e := Hit.new()
		e.amount = hit
		d.effects.append(e)
	if line != 0:
		var l := ChangeLine.new()
		l.amount = line
		d.effects.append(l)
	return d

func _budget_move(share: float, d: Demand) -> BudgetMove:
	var b := BudgetMove.new()
	b.at_share = share
	b.move = d
	return b

func _boss(moves: Array = [], shield: bool = true, budget_share: float = 0.0,
		budget_moves: Array = []) -> CustomerArchetype:
	var a := CustomerArchetype.new()
	a.id = &"made_up_boss"
	a.display_name = "Made-up Boss"
	a.line = 0
	a.patience = 20
	a.line_per_sale = 0
	a.combo_step = 0.0
	a.arrival_patience_share = 1.0
	a.patience_is_shield = shield
	a.budget_share = budget_share
	a.moves.assign(moves)
	a.budget_moves.assign(budget_moves)
	a.move_gap_ticks = 1
	a.escalate_damage = 2
	a.escalate_fuse = 1
	a.min_move_fuse = 1
	return a

## The boss alone in one chair, a shift with no clock, you standing with them,
## and nothing in your hand yet. [shift, customer].
func _fight(boss: CustomerArchetype, quota: int = 1500, seed_value: int = 7,
		no_clock: bool = true) -> Array:
	var lineup: Array[CustomerArchetype] = [boss]
	var s := Shift.new(_cfg(), load("res://data/interests/interest_pool.tres"),
		load("res://data/card_pool.tres"), load("res://data/archetype_pool.tres"),
		seed_value, [], null, quota, 1, 0, 0, null, 1, 1.0, 1.0, [], lineup, [],
		{"no_clock": no_clock})
	s.at = 0
	s.hand.clear()
	return [s, s.chairs[0]]

## A product of yours in hand - any from the pool, never one named.
func _products() -> Array:
	var out := []
	for def in (load("res://data/card_pool.tres") as CardPool).cards:
		if def is ProductCardDef:
			out.append(def)
	return out

func _hand(s: Shift, def: CardDef, uid: int) -> int:
	s.hand.append(CardInstance.new(def, uid))
	return s.hand.size() - 1

# ------------------------------------------------------------------ the shield
func test_a_hit_comes_out_of_the_shield_first_and_the_rest_off_your_standing() -> void:
	var pair := _fight(_boss())
	var s: Shift = pair[0]
	var c: Customer = pair[1]
	var ctx := EffectContext.new()
	ctx.shift = s
	ctx.customer = c
	var hit := Hit.new()
	hit.amount = 6
	c.patience = 10
	var standing := s.standing
	hit.apply(ctx)
	h.eq("a full shield takes all of it", c.patience, 4)
	h.eq("and your standing none", s.standing, standing)
	hit.apply(ctx)
	h.eq("what it cannot cover comes off your standing", s.standing, standing - 2)
	h.eq("and the shield is gone", c.patience, 0)
	hit.apply(ctx)
	h.eq("with no shield, all of it lands", s.standing, standing - 8)

func test_without_a_shield_a_hit_goes_straight_to_your_standing() -> void:
	var pair := _fight(_boss([], false))
	var s: Shift = pair[0]
	var c: Customer = pair[1]
	var ctx := EffectContext.new()
	ctx.shift = s
	ctx.customer = c
	var hit := Hit.new()
	hit.amount = 6
	var patience := c.patience
	var standing := s.standing
	hit.apply(ctx)
	h.eq("all of it off your standing", s.standing, standing - 6)
	h.eq("their patience untouched", c.patience, patience)

func test_a_shield_runs_out_but_never_walks_out() -> void:
	var pair := _fight(_boss())
	var s: Shift = pair[0]
	var c: Customer = pair[1]
	c.patience = -5
	s._settle_patience()
	h.check("still in the chair", s.chairs[0] == c)
	h.eq("at 0, never below", c.patience, 0)
	h.check("and never 'leaving soon'", not c.leaving_soon())

# ------------------------------------------------------------------ the moves
func test_a_boss_telegraphs_as_they_sit_down_and_moves_one_at_a_time() -> void:
	var a := _move(&"move_a", 6, 3)
	var b := _move(&"move_b", 6, 3)
	var pair := _fight(_boss([a, b]))
	var s: Shift = pair[0]
	var c: Customer = pair[1]
	h.check("a move is up the moment they sit down", c.demand == a or c.demand == b)
	h.eq("on its fuse", c.demand_due_tick, 3)
	var first: Demand = c.demand
	var standing := s.standing
	c.patience = 0
	s._burn(3, "cards")
	h.eq("ignored, it lands on your standing", s.standing, standing - 6)
	h.check("and nothing new the same tick - there is a gap", c.demand == null)
	s._burn(1, "cards")
	h.check("then the other move of the round (%s)" % str(c.demand.id if c.demand else &""),
		c.demand != null and c.demand != first)

func test_every_move_comes_once_a_round_and_each_round_is_harder() -> void:
	var moves := [_move(&"move_a", 6, 4), _move(&"move_b", 6, 4), _move(&"move_c", 6, 4)]
	var orders := {}
	for seed_value in range(6):
		var pair := _fight(_boss(moves), 1500, seed_value)
		var s: Shift = pair[0]
		var c: Customer = pair[1]
		var seen: Array = []
		var fuses: Array = []
		var damage: Array = []
		for _i in range(6):
			seen.append(c.demand.id)
			fuses.append(c.demand_due_tick - s.tick)
			damage.append(c.move_damage(c.demand))
			c.patience = 99
			s._burn(c.demand_due_tick - s.tick, "cards")
			s._burn(1, "cards")
		# As text: StringNames do not sort alphabetically.
		var round_one: Array = seen.slice(0, 3).map(func(x): return String(x))
		var round_two: Array = seen.slice(3, 6).map(func(x): return String(x))
		round_one.sort()
		round_two.sort()
		h.eq("seed %d: each move once in round one" % seed_value, round_one, ["move_a", "move_b", "move_c"])
		h.eq("seed %d: and once in round two" % seed_value, round_two, ["move_a", "move_b", "move_c"])
		h.eq("seed %d: round two's fuses a tick shorter" % seed_value, fuses, [4, 4, 4, 3, 3, 3])
		h.eq("seed %d: and its hits harder" % seed_value, damage, [6, 6, 6, 8, 8, 8])
		orders[str(seen.slice(0, 3))] = true
	h.check("the order is drawn, not fixed (%d orders seen)" % orders.size(), orders.size() > 1)

func test_a_fuse_never_runs_shorter_than_the_floor() -> void:
	var boss := _boss([_move(&"only", 6, 2)])
	boss.min_move_fuse = 2
	var pair := _fight(boss)
	var s: Shift = pair[0]
	var c: Customer = pair[1]
	for _i in range(5):
		h.check("round %d: no shorter than 2 (%d)" % [c.move_round, c.demand_due_tick - s.tick],
			c.demand_due_tick - s.tick >= 2)
		c.patience = 99
		s._burn(c.demand_due_tick - s.tick, "cards")
		s._burn(1, "cards")

func test_a_move_that_needs_a_product_on_the_table_waits_for_one() -> void:
	var desk := _move(&"off_my_desk", 8, 2, ClearTheTable.new(), true)
	var plain := _move(&"plain", 6, 2)
	var pair := _fight(_boss([desk, plain]))
	var s: Shift = pair[0]
	var c: Customer = pair[1]
	var raised := {}
	var count := 0
	for _i in range(8):
		if c.demand != null:
			raised[c.demand.id] = true
			count += 1
			c.patience = 99
			s._burn(c.demand_due_tick - s.tick, "cards")
		s._burn(1, "cards")
	# And the one telegraphed after the last of those.
	if c.demand != null:
		count += 1
	h.check("with nothing on the table, never that one (%s)" % str(raised.keys()),
		raised.has(&"plain") and not raised.has(&"off_my_desk"))
	# The one it passed over is done for its round, so every move raised is a
	# round of its own - and no more rounds than that while it waits.
	h.eq("and no runaway rounds while it waits", c.move_round, count - 1)

func test_off_my_desk_is_answered_by_taking_the_product_back_or_it_lands() -> void:
	var desk := _move(&"off_my_desk", 8, 2, ClearTheTable.new(), true)
	var boss := _boss([desk])
	boss.line = 999
	var pair := _fight(boss)
	var s: Shift = pair[0]
	var c: Customer = pair[1]
	h.check("nothing to say with an empty table", c.demand == null)
	s.place(_hand(s, _products()[0], 901))
	h.eq("a product goes down, and they want it gone", c.demand, desk)
	var standing := s.standing
	h.check("you take it back", s.drop_offer().ok)
	h.check("answered", c.demand == null)
	h.eq("nothing lands", s.standing, standing)
	s._burn(1, "cards")
	s.place(_hand(s, _products()[1], 902))
	h.eq("down again, and again they want it gone", c.demand, desk)
	var hits := c.move_damage(desk)
	c.patience = 0
	s._burn(5, "cards")
	h.eq("left on the table, it lands", s.standing, standing - hits)

func test_off_my_desk_reads_the_table_when_it_lands_however_it_was_cleared() -> void:
	## A card that sweeps the offer away tells no demand anything - what counts
	## is whether the table is clear when the fuse runs out.
	var desk := _move(&"off_my_desk", 8, 2, ClearTheTable.new(), true)
	var boss := _boss([desk])
	boss.line = 999
	var pair := _fight(boss)
	var s: Shift = pair[0]
	var c: Customer = pair[1]
	s.place(_hand(s, _products()[0], 901))
	h.eq("they want it gone", c.demand, desk)
	s.discard.append(c.offer.instance)
	c.offer = null
	# Away from them, so nothing you do while it runs out tells it either.
	s.leave()
	var standing := s.standing
	c.patience = 0
	s._burn(5, "cards")
	h.eq("clear when it comes due, so it never lands", s.standing, standing)

func test_a_move_answered_in_time_does_not_land() -> void:
	var come_down := _move(&"come_down", 7, 3, PlayConcession.new())
	var pair := _fight(_boss([come_down]))
	var s: Shift = pair[0]
	var c: Customer = pair[1]
	var standing := s.standing
	h.eq("they want something off", c.demand, come_down)
	# Answered the way the engine reads every answer: the action, reported.
	var cut := ChangeMargin.new()
	cut.amount = -100
	s._demand_saw(c, DemandResolve.SUPPORT, {"effects": [cut]})
	h.check("answered", c.demand == null)
	c.patience = 0
	s._burn(5, "cards")
	h.eq("and it never lands", s.standing, standing)

func test_a_move_without_a_hit_does_what_it_says_when_it_lands() -> void:
	var stakes := _move(&"stakes", 0, 2, null, false, 3)
	var pair := _fight(_boss([stakes]))
	var s: Shift = pair[0]
	var c: Customer = pair[1]
	var line := c.line
	var standing := s.standing
	s._burn(2, "cards")
	h.eq("their Line goes up", c.line, line + 3)
	h.eq("and nothing hits you", s.standing, standing)

# ------------------------------------------------------------------ the budget
func test_a_budget_is_the_quota_and_selling_it_down_ends_the_fight() -> void:
	# The two cheapest products, and a quota the first cannot cover alone but
	# the second more than finishes.
	var products := _products()
	products.sort_custom(func(a, b): return a.margin < b.margin)
	var quota: int = products[0].margin + products[1].margin - 100
	var pair := _fight(_boss([], true, 1.0), quota)
	var s: Shift = pair[0]
	var c: Customer = pair[1]
	h.eq("they come in with the shift's quota to spend", c.budget, quota)
	s.place(_hand(s, products[0], 901))
	h.check("the first sale", s.offer().ok)
	var first: int = c.unsigned[0]["margin"]
	h.eq("spends from their budget", c.budget_left(), quota - first)
	s.place(_hand(s, products[1], 902))
	s.offer()
	h.eq("the last takes whatever is left", c.unsigned_margin(), quota)
	h.check("spent out", c.spent_out())
	var refused := s.place(_hand(s, products[2], 903))
	h.check("and they will take nothing more (%s)" % refused.msg, not refused.ok)
	h.check("you sign them", s.close().ok)
	h.check("which banks the quota exactly", s.margin_banked == quota and s.report()["made_quota"])
	h.check("and with nobody else coming, the fight is over", s.is_over())

func test_nobody_with_a_budget_can_be_signed_until_it_is_all_spent() -> void:
	var products := _products()
	products.sort_custom(func(a, b): return a.margin < b.margin)
	var quota: int = products[0].margin + products[1].margin
	var pair := _fight(_boss([], true, 1.0), quota)
	var s: Shift = pair[0]
	var c: Customer = pair[1]
	s.place(_hand(s, products[0], 901))
	s.offer()
	h.check("agreed to one, with budget left", not c.unsigned.is_empty() and not c.spent_out())
	var refused := s.close()
	h.check("you cannot sign them yet (%s)" % refused.msg, not refused.ok)
	h.check("and it says how much they still have to spend",
		refused.msg.contains("$%d" % c.budget_left()))
	h.check("they are still there, and so is the deal",
		s.chairs[0] == c and not c.unsigned.is_empty())
	s.place(_hand(s, products[1], 902))
	s.offer()
	h.check("spent out", c.spent_out())
	h.check("and now you can", s.close().ok)

func test_a_budget_that_cannot_be_spent_does_not_trap_you_on_the_floor() -> void:
	## Nothing left to sell them: the way out of a deck that cannot drain the
	## budget, or the fight would have no end but closing time.
	var products := _products()
	products.sort_custom(func(a, b): return a.margin < b.margin)
	var pair := _fight(_boss([], true, 1.0), products[0].margin + 5000)
	var s: Shift = pair[0]
	var c: Customer = pair[1]
	s.hand.clear()
	s.draw.clear()
	s.discard.clear()
	s.place(_hand(s, products[0], 901))
	h.check("a product on the table is something left to sell", s.has_something_left_to_sell(c))
	s.offer()
	h.check("sold, with most of the budget still to spend", not c.spent_out())
	h.check("and nothing left to sell them", not s.has_something_left_to_sell(c))
	h.check("so signing them is allowed", s.close().ok)

func test_a_product_in_the_draw_pile_or_discard_is_still_something_to_sell() -> void:
	var products := _products()
	var pair := _fight(_boss([], true, 1.0), 99999)
	var s: Shift = pair[0]
	var c: Customer = pair[1]
	s.hand.clear()
	s.draw.clear()
	s.discard.clear()
	h.check("an empty deck has nothing", not s.has_something_left_to_sell(c))
	s.draw.append(CardInstance.new(products[0], 901))
	h.check("a product in the draw pile counts", s.has_something_left_to_sell(c))
	s.draw.clear()
	s.discard.append(CardInstance.new(products[0], 902))
	h.check("and one in the discard", s.has_something_left_to_sell(c))
	c.unsigned.append({"product": products[0], "margin": 100})
	h.check("but not one they already took", not s.has_something_left_to_sell(c))

func test_someone_without_a_budget_is_signed_as_ever() -> void:
	var products := _products()
	var pair := _fight(_boss([], true, 0.0))
	var s: Shift = pair[0]
	var c: Customer = pair[1]
	h.check("no budget, nothing to hold them back", not s.budget_blocks_closing(c))
	s.place(_hand(s, products[0], 901))
	s.offer()
	h.check("so they sign when you like", s.close().ok)

func test_with_no_clock_the_shift_runs_until_the_boss_is_dealt_with() -> void:
	var pair := _fight(_boss([], true, 1.0))
	var s: Shift = pair[0]
	h.eq("only the closing-time backstop counts", s.tick_budget, s.cfg.no_clock_closing_ticks)
	s._burn(s.cfg.shift_ticks + 5, "cards")
	h.check("past a normal shift's length, still on", not s.is_over())
	h.check("and no clock warning", not s.ticks_running_low())
	var clocked: Shift = _fight(_boss([], true, 1.0), 1500, 7, false)[0]
	h.eq("a shift with a clock keeps it", clocked.tick_budget, clocked.cfg.shift_ticks)

func test_a_picked_profile_with_no_clock_reaches_the_shift() -> void:
	var run := RunState.new(load("res://data/shift_config.tres"),
		load("res://data/interests/interest_pool.tres"),
		load("res://data/card_pool.tres"),
		load("res://data/archetype_pool.tres"), 7)
	var p := ShiftProfile.new()
	p.no_clock = true
	h.check("no clock on the floor", not run.start_shift(p).has_clock)
	h.check("and the calendar says so", p.rules_preview().contains("No clock"))
	h.check("so a shorter-day complicator never joins it", p.touches().has(&"ticks"))

# --------------------------------------------------------------- the big hit
func test_a_hit_that_goes_through_patience_lands_on_you_whole() -> void:
	var pair := _fight(_boss())
	var s: Shift = pair[0]
	var c: Customer = pair[1]
	var ctx := EffectContext.new()
	ctx.shift = s
	ctx.customer = c
	var truck := Hit.new()
	truck.amount = 20
	truck.through_patience = true
	c.patience = 22
	var standing := s.standing
	truck.apply(ctx)
	h.eq("all of it off your standing", s.standing, standing - 20)
	h.eq("their patience untouched", c.patience, 22)
	var soft := Hit.new()
	soft.amount = 20
	soft.apply(ctx)
	h.eq("a plain hit of the same size is soaked up by it", c.patience, 2)

func test_a_move_knows_whether_it_pierces_patience() -> void:
	var plain := _move(&"plain", 6, 3)
	h.check("a plain hit does not", not plain.pierces_patience())
	var truck := _move(&"truck", 0, 2)
	var hit := Hit.new()
	hit.amount = 20
	hit.through_patience = true
	truck.effects.append(hit)
	h.check("a hit marked to go through does", truck.pierces_patience())
	h.eq("and says what it hits for", truck.hit_damage(), 20)

# ---------------------------------------------------------- moves at a budget
func test_a_budget_move_comes_once_the_budget_is_down_and_waits_for_a_product() -> void:
	var truck := _move(&"truck", 20, 2, ClearTheTable.new(), true)
	var products := _products()
	products.sort_custom(func(a, b): return a.margin < b.margin)
	var quota: int = products[0].margin + products[1].margin + products[2].margin
	var boss := _boss([], true, 1.0, [_budget_move(0.8, truck)])
	var pair := _fight(boss, quota)
	var s: Shift = pair[0]
	var c: Customer = pair[1]
	h.check("not due while the budget is whole", c.due_budget_move() == null)
	h.eq("and it is the next thing to come", c.next_budget_move().move, truck)
	s.place(_hand(s, products[0], 901))
	s.offer()
	h.check("down by the first sale, it is due", c.due_budget_move() != null)
	s._burn(3, "cards")
	h.check("but with nothing on the table there is nothing to take off it", c.demand == null)
	s.place(_hand(s, products[1], 902))
	h.eq("the moment a product is on the table, it comes", c.demand, truck)
	h.eq("and is marked as done", c.budget_moves_done, [0])
	h.check("it is one of their moves", c.is_a_move(truck))
	h.check("and nothing is due after it", c.due_budget_move() == null
		and c.next_budget_move() == null)

func test_budget_moves_come_due_one_by_one_as_the_budget_runs_down() -> void:
	var first := _move(&"first", 10, 2)
	var second := _move(&"second", 10, 2)
	var boss := _boss([], true, 1.0, [_budget_move(0.25, second), _budget_move(0.75, first)])
	var c: Customer = _fight(boss, 1000)[1]
	var some_product: CardDef = _products()[0]
	h.eq("they come in with all of it", c.budget_left(), 1000)
	h.check("nothing due yet", c.due_budget_move() == null)
	h.eq("the one at 75% is next, whatever order they are listed in",
		c.next_budget_move().move, first)
	c.unsigned.append({"product": some_product, "margin": 300})
	h.eq("700 left is under 75%: the first is due", c.due_budget_move().move, first)
	c.budget_moves_done.append(boss.budget_moves.find(c.due_budget_move()))
	h.check("and not due again once it has come", c.due_budget_move() == null)
	h.eq("the one at 25% is next", c.next_budget_move().move, second)
	c.unsigned.append({"product": some_product, "margin": 500})
	h.eq("200 left is under 25%: the second is due", c.due_budget_move().move, second)
	c.budget_moves_done.append(boss.budget_moves.find(c.due_budget_move()))
	h.check("and then there is nothing left to come",
		c.due_budget_move() == null and c.next_budget_move() == null)

func test_the_rotation_goes_on_while_a_budget_move_waits_for_a_product() -> void:
	var truck := _move(&"truck", 20, 2, ClearTheTable.new(), true)
	var plain := _move(&"plain", 6, 3)
	var products := _products()
	products.sort_custom(func(a, b): return a.margin < b.margin)
	var boss := _boss([plain], true, 1.0, [_budget_move(1.0, truck)])
	var pair := _fight(boss, products[0].margin + products[1].margin)
	var s: Shift = pair[0]
	var c: Customer = pair[1]
	h.eq("due from the start, but nothing on the table: the rotation goes on", c.demand, plain)

func test_a_budget_move_does_not_wait_out_the_rotations_gap() -> void:
	## However long the quiet after an ordinary move, the big one comes the moment
	## it can - or a fight could end without it ever coming.
	var truck := _move(&"truck", 20, 2, ClearTheTable.new(), true)
	var plain := _move(&"plain", 6, 3)
	var products := _products()
	products.sort_custom(func(a, b): return a.margin < b.margin)
	var boss := _boss([plain], true, 1.0, [_budget_move(1.0, truck)])
	boss.move_gap_ticks = 40
	var pair := _fight(boss, products[0].margin + products[1].margin)
	var s: Shift = pair[0]
	var c: Customer = pair[1]
	s._burn(4, "cards")
	h.check("the ordinary move ran out", c.demand == null)
	h.check("and the quiet after it is a long one", c.next_move_tick > s.tick + 20)
	s.place(_hand(s, products[0], 911))
	h.eq("a product on the table brings the big one at once", c.demand, truck)

# ------------------------------------------------------------------ the words
func test_every_way_of_answering_says_how() -> void:
	for resolve in [MakeAnOffer.new(), PlayConcession.new(), PlayAppealCard.new(),
			PlayAnySupport.new(), IncreasePatience.new(), OfferSomethingGood.new(),
			LeaveThemAlone.new(), ClearTheTable.new()]:
		var how: String = resolve.how_to_answer()
		h.check("%s says how (%s)" % [resolve.get_script().get_global_name(), how], how != "")
	h.check("taking it off the table names the key and the pile",
		ClearTheTable.new().how_to_answer().contains("press D")
			and ClearTheTable.new().how_to_answer().contains("discard"))
