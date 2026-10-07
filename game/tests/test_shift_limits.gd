extends RefCounted
## A premade shift's own rules - hand size, Line shift, combo scale, product
## quota - and the complicators the calendar can deal it with, reaching the
## floor through RunState.start_shift(). Made-up profiles and complicators only:
## which shipped shift bends which rule is David's to change.
var h: Harness

func _run(seed_value: int = 7, owned: Array = []) -> RunState:
	var r := RunState.new(load("res://data/shift_config.tres"),
		load("res://data/interests/interest_pool.tres"),
		load("res://data/card_pool.tres"),
		load("res://data/archetype_pool.tres"), seed_value)
	r.dealership.assign(owned)
	return r

func _upgrade(field: StringName, value) -> DealershipUpgrade:
	var u := DealershipUpgrade.new()
	u.id = &"made_up"
	u.set(field, value)
	return u

func _complicator(field: StringName, value) -> ShiftComplicator:
	var c := ShiftComplicator.new()
	c.id = StringName("made_up_%s" % field)
	c.display_text = "Made-up %s" % field
	c.set(field, value)
	return c

func _category() -> Category:
	return (load("res://data/interests/interest_pool.tres") as InterestPool).categories[0]

func test_a_shift_deals_to_its_own_hand_size_and_an_upgrade_still_adds() -> void:
	var cfg: ShiftConfig = load("res://data/shift_config.tres")
	var p := ShiftProfile.new()
	p.hand_size = cfg.hand_size - 1
	var s := _run().start_shift(p)
	h.eq("the hand is drawn to the shift's size", s.hand.size(), p.hand_size)
	h.eq("and the run's own config is untouched", cfg.hand_size, p.hand_size + 1)
	var bigger := _run(7, [_upgrade(&"hand_size", 1)]).start_shift(p)
	h.eq("a bigger-hand upgrade adds to it", bigger.hand.size(), p.hand_size + 1)

func test_a_line_shift_moves_everyone_seated_at_open_and_never_below_zero() -> void:
	var plain := _run().start_shift(ShiftProfile.new())
	var p := ShiftProfile.new()
	p.line_offset = 5
	var tough := _run().start_shift(p)
	h.eq("same seed, same floor", tough.seated().size(), plain.seated().size())
	for i in range(plain.seated().size()):
		var a: Customer = plain.seated()[i]
		var b: Customer = tough.seated()[i]
		h.eq("chair %d: Line up by exactly the shift's" % i, b.line, a.line + 5)
		h.eq("chair %d: and where it started" % i, b.start_line, a.start_line + 5)
	p.line_offset = -999
	for c in _run().start_shift(p).seated():
		h.eq("an easy crowd stops at 0", c.line, 0)

func test_a_combo_scale_multiplies_each_customers_step_before_an_upgrade_adds() -> void:
	var p := ShiftProfile.new()
	p.combo_scale = 2.0
	for c in _run().start_shift(p).seated():
		h.eq("%s: step doubled" % c.key, c.combo_step, c.archetype.combo_step * 2.0)
	var with_perk := _run(7, [_upgrade(&"combo_step", 0.1)]).start_shift(p)
	for c in with_perk.seated():
		h.check("%s: then the upgrade's on top" % c.key,
			is_equal_approx(c.combo_step, c.archetype.combo_step * 2.0 + 0.1))
	p.combo_scale = 0.0
	for c in _run().start_shift(p).seated():
		h.eq("%s: 0 is no combo at all" % c.key, c.combo_step, 0.0)

func test_a_shifts_own_product_quota_replaces_the_days_boss_included() -> void:
	var p := ShiftProfile.new()
	p.product_quota_category = _category()
	p.product_quota_count = 2
	var s := _run().start_shift(p)
	h.eq("its category", s.category_quota, _category().id)
	h.eq("its count", s.category_quota_count, 2)
	var boss := ShiftCategory.new()
	boss.boss_day = true
	p.dealt_by = boss
	h.eq("a boss that names one has it too", _run().start_shift(p).category_quota_count, 2)
	var plain_boss := ShiftProfile.new()
	plain_boss.dealt_by = boss
	h.eq("a boss that names none has none", _run().start_shift(plain_boss).category_quota_count, 0)

func test_complicators_combine_with_the_shifts_own_rules() -> void:
	var cfg: ShiftConfig = load("res://data/shift_config.tres")
	var p := ShiftProfile.new()
	p.shift_ticks = 10
	p.line_offset = 2
	p.patience_scale = 0.5
	p.combo_scale = 2.0
	p.complicators.assign([_complicator(&"ticks_delta", -2), _complicator(&"line_offset", 1),
		_complicator(&"patience_scale", 0.5), _complicator(&"combo_scale", 0.5),
		_complicator(&"hand_size_delta", -1)])
	var s := _run().start_shift(p)
	h.eq("ticks add", s.tick_budget, 8)
	h.eq("hand sizes add, on the config's", s.hand.size(), cfg.hand_size - 1)
	h.eq("Line shifts add", s.line_offset, 3)
	h.eq("patience scales multiply", s.patience_scale, 0.25)
	h.eq("combo scales multiply", s.combo_scale, 1.0)
	h.check("and the run's config is untouched",
		cfg.shift_ticks != 8 and s.cfg != cfg)

func test_quota_steps_scale_the_days_quota_and_stack_with_the_slots_own() -> void:
	var p := ShiftProfile.new()
	h.eq("standard when nothing asks for more", p.quota_on(4000), 4000)
	p.complicators.assign([_complicator(&"quota_scale", 1.25)])
	h.eq("a step scales it", p.quota_on(4000), 5000)
	p.quota_scale = 0.5
	h.eq("on top of the shift's own scale", p.quota_on(4000), 2500)
	var s := _run().start_shift(p)
	h.eq("and the floor runs to it", s.quota, p.quota_on(_run().quota_for(1)))
	h.eq("a complicator that scales quota says so", _complicator(&"quota_scale", 1.25).touches(), [&"quota"])

func test_the_rules_line_lists_exactly_what_the_shift_changes() -> void:
	h.eq("a plain shift has nothing to say", ShiftProfile.new().rules_preview(), "")
	var p := ShiftProfile.new()
	p.hand_size = 4
	p.line_offset = 3
	p.combo_scale = 0.0
	p.product_quota_category = _category()
	p.product_quota_count = 2
	p.shift_ticks = 12
	p.seats = 1
	p.waiting_room = 2
	var twist := _complicator(&"line_offset", 1)
	p.complicators.assign([twist])
	var parts := p.rules_preview().split(", ")
	h.eq("one part per rule it sets, and per complicator (%s)" % p.rules_preview(),
		parts.size(), 8)
	h.check("a Line shift says which way", p.rules_preview().contains("+3"))
	h.check("the complicator says itself", parts.has(twist.display_text))
	h.check("the product quota names its category",
		p.rules_preview().contains(_category().display_name))
	var regular := ShiftProfile.new()
	regular.patience_scale = 0.8
	h.eq("a regular tier's patience is its blurb's business", regular.rules_preview(), "")

func test_a_complicator_says_which_rules_it_changes() -> void:
	h.eq("nothing set, nothing touched", ShiftComplicator.new().touches(), [])
	h.eq("each field its own rule", _complicator(&"hand_size_delta", -1).touches(), [&"hand"])
	var p := ShiftProfile.new()
	p.hand_size = 4
	p.line_offset = 2
	h.eq("and a shift says which it sets itself", p.touches(), [&"line", &"hand"])
