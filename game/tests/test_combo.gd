extends RefCounted
## The per-customer combo multiplier: Shift._settle() rewards chaining sales
## onto the same customer with a margin multiplier that grows with
## Customer.combo_step (copied from CustomerArchetype.combo_step). Unrelated
## to Shift.sale_streak (see test_sale_streak.gd) - that is a floor-wide,
## cross-shift streak; this is per-customer, resets every new visit.
var h: Harness

func _shift(floor_ids: Array, overrides: Dictionary = {}) -> Shift:
	var cfg: ShiftConfig = (load("res://data/shift_config.tres") as ShiftConfig).duplicate()
	cfg.patience_jitter = 0
	cfg.prior_slip = 0.0
	cfg.arrival_patience_min_fraction = 1.0
	for k in overrides:
		cfg.set(k, overrides[k])
	return Shift.new(cfg,
		load("res://data/interests/interest_pool.tres"),
		load("res://data/card_pool.tres"),
		load("res://data/archetype_pool.tres"), 1, floor_ids)

## Places and offers one product, bypassing the rank/appeal read entirely by
## re-zeroing the Line before every call - every offer's appeal is >= 0, so
## it always clears, even though _settle() keeps raising c.line on its own
## with every sale (line_per_sale is a separate, already-tested knob these
## combo tests have no business depending on). Returns offer()'s Result.
func _sell(s: Shift, c: Customer, product_id: StringName, seed: int) -> Result:
	c.line = 0
	var product := s.card_pool.by_id(product_id)
	s.hand.append(CardInstance.new(product, seed))
	s.place(s.hand.size() - 1)
	return s.offer()

func test_the_first_sale_this_visit_carries_no_combo_bonus() -> void:
	var s := _shift([&"easygoing"])
	var c: Customer = s.chairs[0]
	s.at = 0
	s.last_customer = c
	c.combo_step = 0.5   # exaggerated, so a bug would be obvious
	var vsc_margin: int = s.card_pool.by_id(&"vsc").margin
	s.hand.clear()
	_sell(s, c, &"vsc", 901)
	h.eq("no prior sales yet, so the multiplier is exactly 1.0",
		c.unsigned[0]["margin"], vsc_margin)
	h.eq("and it records zero combo contribution",
		c.unsigned[0]["combo_margin"], 0)

func test_each_further_sale_multiplies_by_the_archetypes_combo_step() -> void:
	var s := _shift([&"easygoing"])
	var c: Customer = s.chairs[0]
	s.at = 0
	s.last_customer = c
	c.combo_step = 0.5
	s.hand.clear()
	var ids: Array[StringName] = [&"vsc", &"gap", &"theft"]
	var seed := 901
	for n in range(ids.size()):
		var base: int = s.card_pool.by_id(ids[n]).margin
		_sell(s, c, ids[n], seed)
		seed += 1
		var expected := roundi(base * (1.0 + c.combo_step * n))
		h.eq("sale #%d (n=%d prior) prices at base x (1 + combo_step * n)"
				% [n + 1, n], c.unsigned[n]["margin"], expected)

func test_a_zeroed_combo_step_never_multiplies_no_matter_how_long_the_chain() -> void:
	var s := _shift([&"easygoing"])
	var c: Customer = s.chairs[0]
	s.at = 0
	s.last_customer = c
	c.combo_step = 0.0
	s.hand.clear()
	for pair in [[&"vsc", 901], [&"gap", 902], [&"theft", 903]]:
		var base: int = s.card_pool.by_id(pair[0]).margin
		_sell(s, c, pair[0], pair[1])
		h.eq("combo_step of 0 means every sale prices at exactly its base margin",
			c.unsigned[c.unsigned.size() - 1]["margin"], base)

func test_offers_result_reports_the_multiplied_margin_not_the_sticker_price() -> void:
	## The exact shape of the bug this session chased down live: a relief or
	## a sale can claim one number in the log/result while the model holds
	## another. Checked directly against the Result offer() returns, not just
	## against c.unsigned, since that Result is what actually reaches a player.
	var s := _shift([&"easygoing"])
	var c: Customer = s.chairs[0]
	s.at = 0
	s.last_customer = c
	c.combo_step = 1.0
	var vsc_margin: int = s.card_pool.by_id(&"vsc").margin
	var gap_margin: int = s.card_pool.by_id(&"gap").margin
	s.hand.clear()
	var first := _sell(s, c, &"vsc", 901)
	h.eq("first sale's Result carries the unmultiplied margin",
		int(first.data["margin"]), vsc_margin)
	var second := _sell(s, c, &"gap", 902)
	h.eq("second sale's Result already reflects the x2.0 combo",
		int(second.data["margin"]), gap_margin * 2)

func test_customer_copies_its_archetypes_combo_step_on_arrival() -> void:
	var s := _shift([&"karen"])
	var c: Customer = s.chairs[0]
	h.eq("the customer's own combo_step matches their archetype's",
		c.combo_step, c.archetype.combo_step)
	h.check("and it is not just a coincidental zero",
		c.archetype.combo_step > 0.0)

func test_peak_combo_multiplier_remembers_the_highest_reached_not_the_last() -> void:
	var s := _shift([&"easygoing", &"easygoing"])
	s.hand.clear()

	s.at = 0
	s.last_customer = s.chairs[0]
	var a: Customer = s.chairs[0]
	a.combo_step = 1.0
	_sell(s, a, &"vsc", 901)   # x1.0
	_sell(s, a, &"gap", 902)   # x2.0 - the run's peak so far
	h.eq("the peak climbs to the highest multiplier reached", s.peak_combo_multiplier, 2.0)

	s.at = 1
	s.last_customer = s.chairs[1]
	var b: Customer = s.chairs[1]
	b.combo_step = 1.0
	_sell(s, b, &"theft", 903)   # this customer's own first sale - x1.0
	h.eq("a LATER, lower multiplier does not erase an earlier, higher peak",
		s.peak_combo_multiplier, 2.0)

func test_a_fresh_shift_starts_the_peak_at_the_no_combo_baseline() -> void:
	var s := _shift([&"easygoing"])
	h.eq("nobody has sold anything yet, so the peak is the 1.0 floor, not 0",
		s.peak_combo_multiplier, 1.0)
