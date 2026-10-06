extends RefCounted
## A budget shift (ShiftProfile.budget_scale): every customer comes in with a
## budget, will not take what costs more than they have left, and the shift has
## no clock - it is over when its lineup is. Made-up archetypes and cards, so
## none of it rides on who ships or what they are tuned to.
var h: Harness

func _cfg() -> ShiftConfig:
	var cfg: ShiftConfig = (load("res://data/shift_config.tres") as ShiftConfig).duplicate()
	cfg.patience_jitter = 0
	cfg.action_cadence_jitter_ticks = 0
	cfg.arrival_patience_min_fraction = 1.0
	return cfg

func _interests() -> InterestPool:
	return load("res://data/interests/interest_pool.tres")

func _arch(budget: int) -> CustomerArchetype:
	var a := CustomerArchetype.new()
	a.id = &"made_up"
	a.display_name = "Made-up buyer"
	a.line = 20
	a.patience = 500
	a.line_per_sale = 0
	a.combo_step = 0.0
	a.budget = budget
	return a

## `lineup` on `chairs` chairs, at `scale` - 0 for an ordinary shift on the clock.
func _shift(lineup: Array, scale: float, chairs: int) -> Shift:
	return Shift.new(_cfg(), _interests(), load("res://data/card_pool.tres"),
		load("res://data/archetype_pool.tres"), 11, [], null, 0, 1, 0, 0, null,
		chairs, 1.0, 1.0, false, [], lineup, [], {}, [], scale)

func _product(uid: int, margin: int) -> CardInstance:
	var def := ProductCardDef.new()
	def.id = StringName("made_up_%d" % uid)
	def.display_name = "Made-up product %d" % uid
	def.interest = _interests().interests[uid % _interests().interests.size()]
	def.margin = margin
	return CardInstance.new(def, uid)

func _discount(uid: int, amount: int) -> CardInstance:
	var def := SupportCardDef.new()
	def.id = &"made_up_discount"
	def.display_name = "Made-up discount"
	var e := ChangeMargin.new()
	e.amount = -amount
	var effects: Array[Effect] = [e]
	def.effects = effects
	return CardInstance.new(def, uid)

func _index(s: Shift, uid: int) -> int:
	for i in range(s.hand.size()):
		if s.hand[i].uid == uid:
			return i
	return -1

## Puts `uid` on the table already as warm as their Line asks, and asks.
func _offer_it(s: Shift, uid: int) -> Result:
	var c: Customer = s.chairs[0]
	s.play_card(_index(s, uid))
	c.offer.appeal = c.line
	return s.offer()

func test_a_customer_will_not_take_what_costs_more_than_they_have_left() -> void:
	var lineup: Array = [_arch(1500)]
	var s := _shift(lineup, 1.0, 1)
	var c: Customer = s.chairs[0]
	s.at = 0
	s.hand.assign([_product(901, 1000), _product(902, 1000), _discount(903, 700)])
	h.eq("they come in with their budget", c.budget_left(), 1500)
	h.eq("the first fits, and they take it", _offer_it(s, 901).kind, "sale")
	h.eq("and it comes off what they have", c.budget_left(), 500)
	var r := _offer_it(s, 902)
	h.eq("the second clears their Line but not their budget", r.kind, "over_budget")
	h.check("so there is no second sale, and it stays on the table",
		c.unsigned.size() == 1 and c.offer != null)
	var cut := s.play_card(_index(s, 903))
	h.check("a card that brings the price down to what they have (%s)" % cut.msg, cut.ok)
	h.eq("makes it fit", s.offer().kind, "sale")
	h.eq("and spends the rest", c.budget_left(), 200)

func test_a_budget_shift_has_no_clock_and_is_over_when_its_lineup_is() -> void:
	var lineup: Array = [_arch(1500), _arch(1500)]
	var ordinary := _shift(lineup, 0.0, 2)
	for _i in range(ordinary.cfg.shift_ticks):
		ordinary._burn(1, "wait")
	h.check("an ordinary shift runs out of ticks", ordinary.is_over())

	var s := _shift(lineup, 1.0, 2)
	for _i in range(ordinary.cfg.shift_ticks * 3):
		s._burn(1, "wait")
	h.check("a budget shift is not over for being slow", not s.is_over())
	for chair in [0, 1]:
		s.chairs[chair].unsigned.append({"product": _product(990 + chair, 700).card,
			"margin": 700, "bonus": 0, "price": 700})
		s.at = chair
		h.check("everyone signs", s.close().ok)
	h.check("and it is over the moment the last of them has", s.is_over())
	var report := s.report()
	h.eq("the report says how much of the room's money came in", report["budget_seen"], 3000)
	h.eq("and how much of it you got", report["budget_captured"], 1400)

func test_every_budget_shift_has_a_lineup_of_customers_with_budgets() -> void:
	var pool: ShiftProfilePool = load("res://data/shift_profile_pool.tres")
	var shifts: Array[ShiftProfile] = pool.profiles.duplicate()
	for category in pool.categories:
		shifts.append_array(category.shifts)
	var offenders: Array[String] = []
	for p in shifts:
		if p.budget_scale <= 0.0:
			continue
		if p.lineup.is_empty():
			offenders.append("%s has no lineup, so nothing would end it" % p.id)
		for a in p.lineup:
			if a.budget <= 0:
				offenders.append("%s sends %s, who has no budget" % [p.id, a.id])
	h.check("budget shifts are well formed (%s)" % "; ".join(offenders), offenders.is_empty())
