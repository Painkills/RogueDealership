extends RefCounted
## A menu run (ShiftConfig.products_on_board, RunState.menu): every product the
## deck holds is dealt face up beside the floor instead of drawn - one table at a
## time, back on the menu when it comes off one - the hand is support cards only,
## and the store swaps a product for its interest's slot instead of adding one.
## Made-up customers, and whatever products the pool has; never one named.
var h: Harness

func _cfg(menu: bool = true) -> ShiftConfig:
	var cfg: ShiftConfig = (load("res://data/shift_config.tres") as ShiftConfig).duplicate()
	cfg.patience_jitter = 0
	cfg.action_cadence_jitter_ticks = 0
	cfg.arrival_patience_min_fraction = 1.0
	cfg.products_on_board = menu
	if menu:
		cfg.hand_min_products = 0
	return cfg

func _arch(leaves_deck: bool = false) -> CustomerArchetype:
	var arch := CustomerArchetype.new()
	arch.id = &"made_up_customer"
	arch.display_name = "Made-up Customer"
	arch.line = 20
	arch.patience = 40
	arch.line_per_sale = 0
	arch.combo_weight = 0.0
	arch.sold_products_leave_deck = leaves_deck
	return arch

func _pool() -> CardPool:
	return load("res://data/card_pool.tres")

## Every product in the pool, one each, and a few support cards - a deck any
## pool can build.
func _deck(products: Array = []) -> Deck:
	var d := Deck.new()
	var supports := 0
	for def in _pool().cards:
		if def is ProductCardDef:
			if products.is_empty() or products.has(def):
				d.add(def)
		elif supports < 8:
			d.add(def)
			supports += 1
	return d

## Two made-up customers on the floor, you standing with the first.
func _shift(deck: Deck = null, menu: bool = true, leaves_deck: bool = false,
		seed_value: int = 7) -> Shift:
	var lineup: Array[CustomerArchetype] = [_arch(leaves_deck), _arch(leaves_deck)]
	var s := Shift.new(_cfg(menu), load("res://data/interests/interest_pool.tres"),
		_pool(), load("res://data/archetype_pool.tres"), seed_value, [],
		deck if deck != null else _deck(), 1500, 1, 0, 0, null, 2, 1.0, 1.0, [], lineup, [], {})
	s.at = 0
	s.last_customer = s.chairs[0]
	return s

func _any_product(s: Shift) -> CardInstance:
	return s.board[0]

func _products_in(pile: Array) -> int:
	return pile.filter(func(i): return i.is_product()).size()


func test_products_are_dealt_to_the_menu_and_never_drawn() -> void:
	var deck := _deck()
	var s := _shift(deck)
	h.eq("every product of the deck is on the menu", s.board.size(), _products_in(deck.cards))
	h.eq("none in the hand", _products_in(s.hand), 0)
	h.eq("none in the draw", _products_in(s.draw), 0)
	h.check("the hand is dealt all the same", not s.hand.is_empty())
	h.check("every product starts available", s.board.all(func(i): return s.board_available(i)))

func test_a_classic_shift_has_no_menu() -> void:
	var s := _shift(null, false)
	h.check("nothing on a menu", s.board.is_empty())
	h.check("products are drawn like any card",
		_products_in(s.hand) + _products_in(s.draw) > 0)
	h.check("and the grid keeps the pool's order", s.board_order().is_empty())

func test_placing_from_the_menu_puts_it_on_one_table_only() -> void:
	var s := _shift()
	var inst := _any_product(s)
	var hand_before := s.hand.size()
	var tick := s.tick
	var r := s.place_board(inst.card.id)
	h.check("placed (%s)" % r.msg, r.ok)
	h.eq("it is on their table", (s.chairs[0] as Customer).offer.instance, inst)
	h.check("and no longer available", not s.board_available(inst))
	h.eq("nothing left the hand", s.hand.size(), hand_before)
	h.eq("placing costs what it always did", s.tick - tick, s.cfg.place_ticks)
	var again := s.place_board(inst.card.id, 1)
	h.check("the other customer cannot have it too", not again.ok)
	h.check("with words to say why", again.msg != "")
	h.check("nothing on their table", (s.chairs[1] as Customer).offer == null)

## The clock moved on until `inst` has rested - the cooldown is read off the tick.
func _rest(s: Shift, inst: CardInstance) -> void:
	for _i in range(100):
		if s.board_cooldown_left(inst) == 0:
			return
		s.tick += 1

func test_a_dropped_product_goes_back_on_the_menu() -> void:
	var s := _shift()
	var inst := _any_product(s)
	s.place_board(inst.card.id)
	var r := s.drop_offer()
	h.check("dropped (%s)" % r.msg, r.ok)
	h.check("not in the discard", not s.discard.has(inst))
	h.eq("resting for the cooldown", s.board_cooldown_left(inst), s.cfg.menu_cooldown_ticks)
	_rest(s, inst)
	h.check("then available again", s.board_available(inst))

func test_a_sold_product_goes_back_on_the_menu() -> void:
	var s := _shift()
	var c: Customer = s.chairs[0]
	var inst := _any_product(s)
	s.place_board(inst.card.id)
	c.line = c.offer.appeal
	var r := s.offer()
	h.check("sold (%s)" % r.msg, r.ok)
	h.check("not in the discard", not s.discard.has(inst))
	_rest(s, inst)
	h.check("available for the next customer once rested", s.board_available(inst))
	h.check("but this customer will not take it twice", not s.place_board(inst.card.id).ok)

func test_a_product_rests_after_a_table_before_it_goes_on_another() -> void:
	var s := _shift()
	if s.cfg.menu_cooldown_ticks <= 0:
		h.check("no cooldown configured - nothing to rest", true)
		return
	var inst := _any_product(s)
	s.place_board(inst.card.id)
	s.drop_offer()
	var back_at := s.tick
	h.check("resting, it is not available", not s.board_available(inst))
	var r := s.place_board(inst.card.id, 1)
	h.check("and cannot go on another table yet", not r.ok)
	h.check("saying when it can (%s)" % r.msg, r.msg.contains(str(s.board_cooldown_left(inst))))
	s.tick += 1
	h.eq("each tick brings it closer", s.board_cooldown_left(inst),
		s.cfg.menu_cooldown_ticks - 1)
	_rest(s, inst)
	h.eq("it rests exactly the cooldown", s.tick - back_at, s.cfg.menu_cooldown_ticks)
	h.check("then it can (%s)" % s.place_board(inst.card.id, 1).msg,
		(s.chairs[1] as Customer).offer != null)

func test_a_resting_product_still_counts_as_something_to_sell() -> void:
	var s := _shift()
	var inst := _any_product(s)
	for other in s.board:
		if other != inst:
			s.exhausted.append(other)
	s.place_board(inst.card.id)
	s.drop_offer()
	h.check("resting", not s.board_available(inst))
	h.check("but it comes back, so there is still something to sell them",
		s.has_something_left_to_sell(s.chairs[0]))

func test_a_product_sold_out_of_the_shift_stays_off_the_menu() -> void:
	var s := _shift(null, true, true)
	var c: Customer = s.chairs[0]
	var inst := _any_product(s)
	s.place_board(inst.card.id)
	c.line = c.offer.appeal
	s.offer()
	h.check("exhausted", s.exhausted.has(inst))
	h.check("not available", not s.board_available(inst))
	h.check("and cannot be placed again", not s.place_board(inst.card.id, 1).ok)

func test_a_product_that_is_not_on_the_menu_cannot_be_placed() -> void:
	var deck := Deck.new()
	var products: Array = _pool().cards.filter(func(d): return d is ProductCardDef)
	deck.add(products[0])
	for def in _pool().cards:
		if def is SupportCardDef:
			deck.add(def)
	var s := _shift(deck)
	var r := s.place_board(products[1].id)
	h.check("refused", not r.ok)
	h.check("with words to say why", r.msg != "")

func test_replaying_the_commands_puts_the_menu_back() -> void:
	var s := _shift()
	var first := _any_product(s)
	s.place_board(first.card.id)
	s.drop_offer()
	var second: CardInstance = s.board[1]
	s.place_board(second.card.id, 1)
	var again := _shift()
	for cmd in s.commands:
		again.replay(cmd)
	var c: Customer = again.chairs[1]
	h.check("the same product on the same table",
		c.offer != null and c.offer.product.id == second.card.id)
	h.eq("the same clock", again.tick, s.tick)
	h.eq("the same availability",
		again.board.map(func(i): return again.board_available(i)),
		s.board.map(func(i): return s.board_available(i)))
	h.eq("its note names the card", String(s.command_notes[0].get("card", "")),
		String(first.card.id))

func test_a_budget_customer_sees_what_is_on_the_menu() -> void:
	var s := _shift()
	var c: Customer = s.chairs[0]
	h.check("something left to sell while the menu has it",
		s.has_something_left_to_sell(c))
	for inst in s.board:
		s.exhausted.append(inst)
	h.check("nothing once the whole menu is gone", not s.has_something_left_to_sell(c))

func test_the_grid_puts_your_products_first_and_the_empty_slots_last() -> void:
	var interests: InterestPool = load("res://data/interests/interest_pool.tres")
	var products: Array = _pool().cards.filter(func(d): return d is ProductCardDef)
	var few: Array = [products[0]]
	var s := _shift(_deck(few))
	var order := s.board_order()
	var filled := (products[0] as ProductCardDef).interest
	for cat in interests.categories:
		var ids: Array = order[cat.id]
		var all_of_it: Array = interests.in_category(cat).map(func(i): return i.id)
		h.eq("%s: every interest of it, once" % cat.id, ids.size(), all_of_it.size())
		h.check("%s: nothing but its own" % cat.id, ids.all(func(id): return all_of_it.has(id)))
		if cat == filled.category:
			h.eq("%s: the one you have is first" % cat.id, ids[0], filled.id)
		else:
			h.eq("%s: the rest keep the pool's order" % cat.id, ids, all_of_it)
	# A second product, for an interest after the first in its category, moves up.
	var later: ProductCardDef = null
	for p in products:
		var pp := p as ProductCardDef
		var row: Array = interests.in_category(pp.interest.category).map(func(i): return i.id)
		if pp.interest.category != filled.category and row.find(pp.interest.id) > 0:
			later = pp
			break
	if later != null:
		var t := _shift(_deck([products[0], later]))
		h.eq("filling a slot moves it to the front", t.board_order()[later.interest.category.id][0],
			later.interest.id)


# --- the run and the store ----------------------------------------------------

func _run(menu: bool = true, seed_value: int = 7) -> RunState:
	var r := RunState.new(load("res://data/shift_config.tres"),
		load("res://data/interests/interest_pool.tres"),
		_pool(), load("res://data/archetype_pool.tres"), seed_value)
	if menu:
		r.make_menu()
	r.money = 100000
	return r

func test_a_menu_run_deals_its_shifts_onto_the_menu() -> void:
	var r := _run()
	var profile := ShiftProfile.new()
	var s := r.start_shift(profile)
	h.check("its shifts use the menu", s.cfg.products_on_board)
	h.eq("with the menu's hand", s.cfg.hand_size, profile.hand_on(r.cfg.menu_hand_size))
	h.check("never touching the run's own config", not r.cfg.products_on_board)
	h.eq("its extra starters join the deck",
		r.deck.cards.size(), Deck.build_starting(r.card_pool).cards.size() + r.cfg.menu_starters.size())
	var classic := _run(false).start_shift(ShiftProfile.new())
	h.check("a classic run's shift has no menu", classic.board.is_empty())

func test_a_menu_run_survives_a_save() -> void:
	var r := _run()
	var back := _run(false)
	back.restore(r.snapshot())
	h.check("still a menu run", back.menu)
	var classic := _run(false)
	classic.restore(_run(false).snapshot())
	h.check("a classic one stays classic", not classic.menu)

func test_a_new_product_takes_its_interests_slot() -> void:
	var r := _run()
	var shop := Shop.new(r)
	var held: CardInstance = null
	var rival: ProductCardDef = null
	for inst in r.deck.cards:
		if not inst.is_product():
			continue
		for def in _pool().cards:
			if def is ProductCardDef and def != inst.card \
					and (def as ProductCardDef).interest == (inst.card as ProductCardDef).interest:
				held = inst
				rival = def
	if rival == null:
		h.check("no two products share an interest in this pool - nothing to swap", true)
		return
	h.eq("the store says which it replaces", shop.replaces(rival), held)
	shop.offers.append(rival)
	var products_before := r.deck.cards.filter(func(i): return i.is_product()).size()
	var res := shop.buy(rival)
	h.check("bought (%s)" % res.msg, res.ok)
	h.check("the old one is gone", shop.find(held.uid) == null)
	h.check("the new one is in", r.deck.cards.any(func(i): return i.card == rival))
	h.eq("the menu is no bigger", r.deck.cards.filter(func(i): return i.is_product()).size(),
		products_before)

func test_a_product_for_an_empty_slot_adds_one() -> void:
	var r := _run()
	var shop := Shop.new(r)
	var taken := {}
	for inst in r.deck.cards:
		if inst.is_product():
			taken[(inst.card as ProductCardDef).interest.id] = true
	var fresh: ProductCardDef = null
	for def in _pool().cards:
		if def is ProductCardDef and not taken.has((def as ProductCardDef).interest.id):
			fresh = def
			break
	if fresh == null:
		h.check("every interest already has a product - nothing to add", true)
		return
	h.check("it replaces nothing", shop.replaces(fresh) == null)
	shop.offers.append(fresh)
	var before := r.deck.cards.size()
	h.check("bought", shop.buy(fresh).ok)
	h.eq("the deck grew by one", r.deck.cards.size(), before + 1)

func test_a_menu_product_cannot_be_removed() -> void:
	var r := _run()
	var shop := Shop.new(r)
	var product: CardInstance = null
	for inst in r.deck.cards:
		if inst.is_product():
			product = inst
			break
	var res := shop.remove(product.uid)
	h.check("refused", not res.ok)
	h.check("with words to say why", res.msg != "")
	h.check("still in the deck", shop.find(product.uid) != null)

func test_support_cards_are_floored_in_a_menu_run() -> void:
	var r := _run()
	var shop := Shop.new(r)
	var removed := 0
	for _i in range(100):
		var support: CardInstance = null
		for inst in r.deck.cards:
			if not inst.is_product():
				support = inst
				break
		if support == null or not shop.remove(support.uid).ok:
			break
		removed += 1
	var left := r.deck.cards.filter(func(i): return not i.is_product()).size()
	h.check("removing stops at the floor (%d left)" % left, left >= r.cfg.menu_min_supports)

func test_a_menu_store_never_offers_a_classic_only_card_or_one_you_have() -> void:
	for seed_value in range(1, 30):
		var r := _run(true, seed_value)
		var shop := Shop.new(r)
		for def in shop.free_cards + shop.offers:
			h.check("seed %d: %s is no classic-only card" % [seed_value, def.id], not def.classic_only)
			if def is ProductCardDef:
				h.check("seed %d: %s is not already on the menu" % [seed_value, def.id],
					not r.deck.cards.any(func(i): return i.card == def))

func test_a_menu_runs_grid_keeps_the_menus_columns() -> void:
	var interests: InterestPool = load("res://data/interests/interest_pool.tres")
	var cat: Category = interests.categories[0]
	var row: Array = interests.in_category(cat).map(func(i): return i.id)
	var turned: Array = row.duplicate()
	turned.reverse()
	var laid := InterestGrid.fixed_order(interests, cat, turned)
	h.eq("the columns in the menu's order", laid.map(func(i): return i.id), turned)
	var short := InterestGrid.fixed_order(interests, cat, [row[row.size() - 1]])
	h.eq("one it was not told about still gets a column", short.size(), row.size())
	h.eq("after the ones it was", short[0].id, row[row.size() - 1])
