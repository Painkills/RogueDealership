extends RefCounted
## What an archetype can ask of you beyond its actions - see
## CustomerArchetype: waving cards off, one category only, a hurry, prized
## products - and the answers and asks they come with. Made-up archetypes and
## cards, so none of it rides on who ships or what they are tuned to.
var h: Harness

func _cfg() -> ShiftConfig:
	var cfg: ShiftConfig = (load("res://data/shift_config.tres") as ShiftConfig).duplicate()
	cfg.patience_jitter = 0
	cfg.action_cadence_jitter_ticks = 0
	cfg.arrival_patience_min_fraction = 1.0
	return cfg

func _interests() -> InterestPool:
	return load("res://data/interests/interest_pool.tres")

func _arch() -> CustomerArchetype:
	var a := CustomerArchetype.new()
	a.id = &"made_up"
	a.display_name = "Made-up buyer"
	a.line = 20
	a.patience = 16
	a.line_per_sale = 0
	a.combo_step = 0.0
	return a

## [shift, customer]: `arch` alone on a one-chair floor, you standing with
## them, and nothing in your hand yet.
func _seated(arch: CustomerArchetype) -> Array:
	var s := Shift.new(_cfg(), _interests(), load("res://data/card_pool.tres"),
		load("res://data/archetype_pool.tres"), 7, [&"easygoing"],
		null, 0, 1, 0, 0, null, 1)
	s.chairs[0] = null
	s._spawn(0, arch)
	s.at = 0
	s.last_customer = s.chairs[0]
	s.hand.clear()
	return [s, s.chairs[0]]

func _calming(uid: int) -> CardInstance:
	var def := SupportCardDef.new()
	def.id = &"made_up_calm"
	def.display_name = "Made-up calming word"
	def.ticks = 1
	def.needs_offer = false
	var e := ChangePatience.new()
	e.amount = 1
	var effects: Array[Effect] = [e]
	def.effects = effects
	return CardInstance.new(def, uid)

func _product(interest: Interest, uid: int, margin: int = 1000) -> CardInstance:
	var def := ProductCardDef.new()
	def.id = StringName("made_up_%d" % uid)
	def.display_name = "Made-up product %d" % uid
	def.interest = interest
	def.margin = margin
	return CardInstance.new(def, uid)

func _index(s: Shift, uid: int) -> int:
	for i in range(s.hand.size()):
		if s.hand[i].uid == uid:
			return i
	return -1

func test_every_nth_card_played_on_them_is_waved_off() -> void:
	var arch := _arch()
	arch.rejects_every_nth_card = 3
	var pair := _seated(arch)
	var s: Shift = pair[0]
	var c: Customer = pair[1]
	c.patience = 10
	var pool := _interests()
	var waved := _calming(803)
	s.hand.assign([_product(pool.interests[0], 801), _calming(802), waved,
		_calming(804), _calming(805), _product(pool.interests[1], 806)])
	h.check("nothing is waved off to start with", not c.next_card_rejected())
	h.check("a product counts as a card played on them", s.play_card(_index(s, 801)).ok)
	h.check("and so does a support card", s.play_card(_index(s, 802)).ok)
	h.check("two down, the next one is telegraphed", c.next_card_rejected())
	var patience := c.patience
	var tick := s.tick
	var r := s.play_card(_index(s, 803))
	h.eq("the third is waved off", r.kind, "rejected")
	h.eq("and nothing it does happens - only its tick passes", c.patience,
		patience - waved.ticks())
	h.check("but it is spent all the same",
		_index(s, 803) == -1 and s.discard.has(waved) and s.tick == tick + waved.ticks())
	h.check("and the count starts over", not c.next_card_rejected())
	s.drop_offer()
	s.play_card(_index(s, 804))
	s.play_card(_index(s, 805))
	r = s.play_card(_index(s, 806))
	h.check("a product waved off never reaches the table",
		r.kind == "rejected" and c.offer == null)

func test_someone_who_takes_one_category_wants_it_most_and_will_not_look_at_another() -> void:
	var pool := _interests()
	var only: Category = pool.categories[1]
	var arch := _arch()
	arch.only_category = only
	var pair := _seated(arch)
	var s: Shift = pair[0]
	var c: Customer = pair[1]
	var ranks: Array = []
	for i in pool.in_category(only):
		ranks.append(int(c.ranks[i.id]))
	ranks.sort()
	h.eq("their category takes the top ranks", ranks, range(1, ranks.size() + 1))
	var other: Interest = null
	for i in pool.interests:
		if i.category.id != only.id:
			other = i
			break
	s.hand.assign([_product(other, 811), _product(pool.in_category(only)[0], 812)])
	var tick := s.tick
	var r := s.play_card(_index(s, 811))
	h.check("anything else is refused, and costs nothing (%s)" % r.msg,
		not r.ok and c.offer == null and s.tick == tick and _index(s, 811) >= 0)
	h.check("while their own category goes on the table",
		s.play_card(_index(s, 812)).ok and c.offer != null)

func test_someone_in_a_hurry_sits_down_with_their_share_of_patience() -> void:
	var arch := _arch()
	arch.arrival_patience_share = 0.5
	var c: Customer = _seated(arch)[1]
	h.eq("half of it", c.patience, roundi(c.max_patience * 0.5))

func test_patience_can_be_built_up_to_an_archetypes_own_ceiling() -> void:
	var arch := _arch()
	arch.arrival_patience_share = 1.0
	var plain: Customer = _seated(arch)[1]
	h.eq("with no ceiling set, they sit down at the most they can have",
		plain.patience, plain.max_patience)
	var started := plain.patience
	arch = _arch()
	arch.arrival_patience_share = 1.0
	arch.max_patience = started * 2 + 5
	var c: Customer = _seated(arch)[1]
	h.eq("sits down with the patience they always did", c.patience, started)
	h.eq("under a ceiling of their own, scaled like the rest of it", c.max_patience,
		arch.max_patience)
	c.add_patience(1000)
	h.eq("and it builds up to that and no further", c.patience, c.max_patience)
	arch = _arch()
	arch.max_patience = 1
	var low: Customer = _seated(arch)[1]
	h.check("a ceiling under where they start changes nothing (%d of %d)"
		% [low.patience, low.max_patience], low.max_patience >= low.patience)

func test_someone_in_a_hurry_pays_for_the_patience_they_have_left() -> void:
	var arch := _arch()
	arch.pays_per_patience_left = 100
	var pair := _seated(arch)
	var s: Shift = pair[0]
	var c: Customer = pair[1]
	var sold := _product(_interests().interests[0], 821)
	c.unsigned.append({"product": sold.card, "margin": 500, "bonus": 0})
	c.patience = 7
	var before := s.margin_banked
	h.check("they sign", s.close().ok)
	h.eq("for their deal, plus $100 a point of patience left",
		s.margin_banked - before, 500 + 7 * 100)

func test_a_product_they_prize_pays_its_multiple() -> void:
	var pool := _interests()
	var arch := _arch()
	arch.premium_interests.assign([pool.interests[0]])
	arch.premium_margin_scale = 2.0
	var pair := _seated(arch)
	var s: Shift = pair[0]
	var c: Customer = pair[1]
	s.hand.assign([_product(pool.interests[0], 831), _product(pool.interests[1], 832)])
	for uid in [831, 832]:
		s.play_card(_index(s, uid))
		c.offer.appeal = c.line
		s.offer()
	var margins: Array = c.unsigned.map(func(u): return int(u["margin"]))
	h.eq("a prized product pays double, anything else its margin", margins, [2000, 1000])

func test_an_appeal_card_answers_explain_it_to_me() -> void:
	var r := PlayAppealCard.new()
	var up := ChangeAppeal.new()
	up.amount = 4
	var down := ChangeAppeal.new()
	down.amount = -2
	var per_sale := ScaleBySales.new()
	per_sale.inner = up
	var calm := ChangePatience.new()
	calm.amount = 3
	h.check("a card that adds appeal answers it",
		r.satisfied(DemandResolve.SUPPORT, {"effects": [up]}))
	h.check("so does one that adds it per sale",
		r.satisfied(DemandResolve.SUPPORT, {"effects": [per_sale]}))
	h.check("one that takes appeal away does not",
		not r.satisfied(DemandResolve.SUPPORT, {"effects": [down]}))
	h.check("nor one that does something else",
		not r.satisfied(DemandResolve.SUPPORT, {"effects": [calm]}))
	h.check("nor anything but a card played on them",
		not r.satisfied(DemandResolve.OFFER, {"effects": [up]}))

func test_an_urgent_demand_is_held_back_only_by_one_already_live() -> void:
	var pair := _seated(_arch())
	var s: Shift = pair[0]
	var c: Customer = pair[1]
	var urgent := Demand.new()
	urgent.urgent = true
	urgent.resolve = MakeAnOffer.new()
	var plain := Demand.new()
	plain.resolve = MakeAnOffer.new()
	c.ticks_on_floor = 0
	h.check("straight off the street, only the urgent one may be asked",
		s.can_take_a_demand(c, urgent) and not s.can_take_a_demand(c, plain))
	c.ticks_on_floor = s.cfg.demand_grace_ticks
	c.demand_settled_tick = s.tick
	h.check("and the same straight after their last ask",
		s.can_take_a_demand(c, urgent) and not s.can_take_a_demand(c, plain))
	h.check("but never over one already live",
		s.raise_demand(c, urgent) and not s.can_take_a_demand(c, urgent))

func test_a_customer_who_opens_up_says_what_they_want_but_not_their_line() -> void:
	var c: Customer = _seated(_arch())[1]
	var tell := RevealRoom.new()
	tell.line = false
	var ctx := EffectContext.new()
	ctx.customer = c
	tell.apply(ctx)
	h.eq("what they want most is known, with its rank",
		c.known_ranks.get(c.top_interest_id(), -1), int(c.ranks[c.top_interest_id()]))
	h.check("their Line is not", not c.known_line)
