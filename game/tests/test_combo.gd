extends RefCounted
## The per-customer combo multiplier: Shift._settle() rewards chaining sales
## onto the same customer with a margin multiplier that grows with
## Customer.combo_step (ShiftConfig.combo_step x CustomerArchetype.combo_weight,
## set when they are seated). Unrelated
## to Shift.sale_streak (see test_sale_streak.gd) - that is a floor-wide,
## cross-shift streak; this is per-customer, resets every new visit.
var h: Harness

func _shift(floor_ids: Array, overrides: Dictionary = {}) -> Shift:
	var cfg: ShiftConfig = (load("res://data/shift_config.tres") as ShiftConfig).duplicate()
	cfg.patience_jitter = 0
	cfg.action_cadence_jitter_ticks = 0
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

func test_every_customer_combos_by_the_one_shared_step_times_their_weight() -> void:
	## "All customers give combo on every successive sale by the same amount" -
	## one step in the config, each archetype only a weight on it.
	var s := _shift([&"easygoing", &"easygoing"], {"combo_step": 0.4})
	for c in s.seated():
		h.check("%s combos by the shared step x their weight (%.3f)" % [c.key, c.combo_step],
			is_equal_approx(c.combo_step, 0.4 * c.archetype.combo_weight))
	var lower: Customer = _shift([&"easygoing"], {"combo_step": 0.1}).chairs[0]
	h.check("a change to the shared step reaches every customer",
		is_equal_approx(lower.combo_step, 0.1 * lower.archetype.combo_weight))

func test_a_sale_says_what_the_combo_made_of_it() -> void:
	## The view lights the combo up the moment an offer passes - from what the
	## sale itself reports, never re-derived.
	var s := _shift([&"easygoing"], {"combo_step": 0.5})
	s.at = 0
	s.last_customer = s.chairs[0]
	var c: Customer = s.chairs[0]
	s.hand.clear()
	_sell(s, c, &"vsc", 901)
	var second := _sell(s, c, &"gap", 902)
	h.eq("the multiplier it sold at", float(second.data["multiplier"]), 1.0 + c.combo_step)
	h.check("the product's own margin before it",
		int(second.data["base_margin"]) > 0)
	h.eq("and the multiplier the next sale will get", float(second.data["next_multiplier"]),
		1.0 + c.combo_step * 2)

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
