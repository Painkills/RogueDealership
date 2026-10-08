extends RefCounted
## Two rules about closing and standing: a customer who wants more than one product
## before they sign, and the testing shortcut that ends a shift without costing
## any standing. Made-up archetypes throughout - nothing here names who ships.
var h: Harness

func _cfg() -> ShiftConfig:
	var cfg: ShiftConfig = (load("res://data/shift_config.tres") as ShiftConfig).duplicate()
	cfg.patience_jitter = 0
	cfg.action_cadence_jitter_ticks = 0
	cfg.arrival_patience_min_fraction = 1.0
	cfg.shift_ticks = 99
	return cfg

func _shift(seed_value: int = 5) -> Shift:
	var s := Shift.new(_cfg(), load("res://data/interests/interest_pool.tres"),
		load("res://data/card_pool.tres"), load("res://data/archetype_pool.tres"), seed_value)
	for i in range(s.chairs.size()):
		s.chairs[i] = null
	return s

func _arch(min_products: int) -> CustomerArchetype:
	var a := CustomerArchetype.new()
	a.id = &"made_up"
	a.display_name = "Made-up"
	a.line = 0
	a.patience = 99
	a.min_products_to_sign = min_products
	return a

func _products() -> Array:
	var out := []
	for def in (load("res://data/card_pool.tres") as CardPool).cards:
		if def is ProductCardDef:
			out.append(def)
	return out

## Puts a product from the pool in front of them and asks for the business.
func _sell(s: Shift, c: Customer, def: CardDef, uid: int) -> void:
	s.at = 0
	s.hand.clear()
	s.hand.append(CardInstance.new(def, uid))
	s.place(0)
	s.offer()

# --------------------------------------------------------- more than one product
func test_someone_who_wants_two_products_does_not_sign_for_one() -> void:
	var s := _shift()
	s._spawn(0, _arch(2))
	var c: Customer = s.chairs[0]
	var products := _products()
	_sell(s, c, products[0], 901)
	h.eq("one product agreed", c.unsigned.size(), 1)
	h.check("something is left to sell them, so they will not sign", s.needs_more_products(c))
	h.check("and the table says closing is blocked", s.signing_blocked(c))
	var refused := s.close()
	h.check("closing is refused (%s)" % refused.msg, not refused.ok)
	h.check("and says why", refused.msg.contains("2 products") and refused.msg.contains("1 so far"))
	_sell(s, c, products[1], 902)
	h.eq("two agreed", c.unsigned.size(), 2)
	h.check("now they will", not s.needs_more_products(c) and not s.signing_blocked(c))
	h.check("and signing works", s.close().ok)

func test_a_deck_with_nothing_more_to_sell_them_signs_them_as_they_are() -> void:
	var s := _shift()
	s._spawn(0, _arch(2))
	var c: Customer = s.chairs[0]
	_sell(s, c, _products()[0], 901)
	s.hand.clear()
	s.draw.clear()
	s.discard.clear()
	h.check("nothing left to sell, so nothing in the way", not s.needs_more_products(c))
	h.check("and one product signs", s.close().ok)

func test_nobody_else_is_held_to_it() -> void:
	var s := _shift()
	s._spawn(0, _arch(0))
	var c: Customer = s.chairs[0]
	_sell(s, c, _products()[0], 901)
	h.check("a customer with no minimum signs for one", not s.signing_blocked(c) and s.close().ok)

# ------------------------------------------------- the shortcut costs no standing
func test_a_shift_skipped_for_testing_loses_no_standing_to_walkouts() -> void:
	var control := _shift()
	control._spawn(0, _arch(0))
	control.chairs[0].patience = 0
	control._settle_patience()
	h.check("normally a walkout costs standing",
		control.standing < control._initial_standing)
	var s := _shift()
	s._spawn(0, _arch(0))
	s.testing_skip = true
	s.chairs[0].patience = 0
	s._settle_patience()
	h.eq("skipped, it costs none", s.standing, s._initial_standing)
	h.eq("and none is reported as lost to walkouts",
		s.report()["standing_lost_to_walkouts"], 0)

func test_a_shift_skipped_for_testing_does_not_pay_for_the_missed_quota_either() -> void:
	var control := _shift()
	h.check("normally missing the quota costs standing", control.report()["standing_delta"] < 0)
	var s := _shift()
	s.testing_skip = true
	h.eq("skipped, the run's standing carries on as it was", s.report()["standing_delta"], 0)

func test_nothing_lowers_standing_on_a_skipped_shift_but_it_can_still_rise() -> void:
	var s := _shift()
	s.testing_skip = true
	var before := s.standing
	s.standing -= 30
	h.eq("a hit does not land", s.standing, before)
	s.standing = 0
	h.eq("not even to nothing", s.standing, before)
	s.standing = before + 3
	h.eq("while a rise is allowed", s.standing, before + 3)
	var normal := _shift()
	normal.standing -= 30
	h.eq("and on any other shift it drops, as ever", normal.standing, normal._initial_standing - 30)
