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
		h.check("%s combos by the shared step x their weight, to the nearest 5%% (%.3f)"
			% [c.key, c.combo_step],
			is_equal_approx(c.combo_step, roundf(0.4 * c.archetype.combo_weight * 20.0) / 20.0))
	var lower: Customer = _shift([&"easygoing"], {"combo_step": 0.1}).chairs[0]
	h.check("a change to the shared step reaches every customer",
		is_equal_approx(lower.combo_step, roundf(0.1 * lower.archetype.combo_weight * 20.0) / 20.0))

func _made_up_floor(step: float, weight: float) -> Shift:
	var cfg: ShiftConfig = (load("res://data/shift_config.tres") as ShiftConfig).duplicate()
	cfg.patience_jitter = 0
	cfg.action_cadence_jitter_ticks = 0
	cfg.combo_step = step
	var a := CustomerArchetype.new()
	a.id = &"made_up_customer"
	a.display_name = "Made-up"
	a.line = 0
	a.patience = 40
	a.line_per_sale = 0
	a.combo_weight = weight
	var lineup: Array[CustomerArchetype] = [a]
	var s := Shift.new(cfg, load("res://data/interests/interest_pool.tres"),
		load("res://data/card_pool.tres"), load("res://data/archetype_pool.tres"),
		3, [], null, 1500, 1, 0, 0, null, 1, 1.0, 1.0, [], lineup, [], {})
	s.at = 0
	s.last_customer = s.chairs[0]
	s.hand.clear()
	return s

func test_a_step_is_rounded_to_the_nearest_five_percent() -> void:
	## "Make it round to a 5 (33 is 35, 28 is 30)": what the tablet says is paid.
	for pair in [[0.33, 0.35], [0.28, 0.30], [0.125, 0.15], [0.3125, 0.30], [0.375, 0.40],
			[0.25, 0.25], [0.5, 0.5], [0.02, 0.0]]:
		var c: Customer = _made_up_floor(float(pair[0]), 1.0).chairs[0]
		h.check("%.4f becomes %.2f (got %.3f)" % [pair[0], pair[1], c.combo_step],
			is_equal_approx(c.combo_step, float(pair[1])))
	# The weight is applied before it is rounded, and an upgrade's own after.
	var weighted: Customer = _made_up_floor(0.25, 0.5).chairs[0]
	h.check("a weight is applied first (0.25 x 0.5 = 0.125, up to 0.15)",
		is_equal_approx(weighted.combo_step, 0.15))

func _played(s: Shift, effect_amount: int) -> void:
	var def := SupportCardDef.new()
	def.id = &"made_up_combo_card"
	def.display_name = "Made-up combo card"
	def.needs_offer = false
	def.ticks = 1
	var e := ChangeCombo.new()
	e.amount = effect_amount
	var effects: Array[Effect] = [e]
	def.effects = effects
	s.hand.clear()
	s.hand.append(CardInstance.new(def, 7001))
	var res := s.play_card(0)
	assert(res.ok)

func test_a_card_that_raises_the_combo_adds_to_the_multiplier_for_good() -> void:
	## A 150% multiplier becomes 175% - and the next sale's 200% becomes 225%.
	var s := _made_up_floor(0.5, 1.0)
	var c: Customer = s.chairs[0]
	_sell(s, c, &"vsc", 901)
	h.eq("their next sale is 150%", c.combo_multiplier(), 1.5)
	_played(s, 25)
	h.eq("the card makes it 175%", c.combo_multiplier(), 1.75)
	var second := _sell(s, c, &"gap", 902)
	h.eq("and that is what it sells at", float(second.data["multiplier"]), 1.75)
	h.eq("the one after is 225%, not 200%", c.combo_multiplier(), 2.25)
	_played(s, 25)
	h.eq("played again, it goes on adding", c.combo_multiplier(), 2.5)

func test_the_combo_card_works_on_a_customer_with_nothing_sold_and_only_theirs() -> void:
	var s := _made_up_floor(0.25, 1.0)
	var c: Customer = s.chairs[0]
	_played(s, 50)
	h.eq("before any sale, their first is already 150%", c.combo_multiplier(), 1.5)
	var fresh := _made_up_floor(0.25, 1.0)
	h.eq("and nobody else's moved", fresh.chairs[0].combo_multiplier(), 1.0)

func test_a_card_that_raises_the_combo_shows_it_as_a_popup_number() -> void:
	## "All cards should show what they've done": +25 percentage points.
	var s := _made_up_floor(0.25, 1.0)
	_played(s, 25)
	var entry: Dictionary = s.action_log.filter(
		func(e): return e["name"] == "Made-up combo card")[-1]
	h.eq("combo +25", int(entry["fx"]["combo"]), 25)

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
		c.combo_multiplier())

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
