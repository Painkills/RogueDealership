extends RefCounted
## The trailing Shift.new() knobs a picked ShiftProfile threads through -
## floor size, patience scale, walk-up scale. All three default to their
## no-op value (0, 1.0, 1.0), so every pre-existing Shift.new() call site is
## unaffected - that is what the "falls back" tests below pin down.
##
## Who may come in, and from which week, has its own coverage in
## test_archetype_gating.gd. RunState actually threading a ShiftProfile's
## fields through start_shift() has its own coverage in test_run_state.gd,
## and a premade shift's own rules in test_shift_limits.gd.
var h: Harness

func _cfg() -> ShiftConfig:
	var cfg: ShiftConfig = (load("res://data/shift_config.tres") as ShiftConfig).duplicate()
	cfg.patience_jitter = 0
	cfg.action_cadence_jitter_ticks = 0
	cfg.arrival_patience_min_fraction = 1.0
	return cfg

func _shift(p_floor_size: int = 0, p_patience_scale: float = 1.0,
		p_walk_up_scale: float = 1.0, seed_value: int = 7) -> Shift:
	return Shift.new(_cfg(), load("res://data/interests/interest_pool.tres"),
		load("res://data/card_pool.tres"), load("res://data/archetype_pool.tres"),
		seed_value, [], null, 0, 1, 0, 0, null,
		p_floor_size, p_patience_scale, p_walk_up_scale)

func test_floor_size_override_seats_exactly_that_many_chairs() -> void:
	var s := _shift(2)
	h.eq("only the overridden number of chairs exist", s.chairs.size(), 2)
	h.eq("and every one of them sat someone", s.seated().size(), 2)

func test_zero_floor_size_falls_back_to_the_configs_own_default() -> void:
	var cfg := _cfg()
	var s := _shift(0)
	h.eq("0 means unchanged", s.chairs.size(), cfg.floor_size)

func test_patience_scale_shrinks_every_seated_customers_own_ceiling() -> void:
	var baseline := _shift()
	var scaled := _shift(0, 0.5)
	h.eq("same seed, same floor size", scaled.seated().size(), baseline.seated().size())
	for i in range(baseline.seated().size()):
		var base_c: Customer = baseline.seated()[i]
		var scaled_c: Customer = scaled.seated()[i]
		h.eq("chair %d: same archetype, same seed" % i,
			scaled_c.archetype.id, base_c.archetype.id)
		h.eq("chair %d: patience ceiling is exactly halved and rounded" % i,
			scaled_c.max_patience, roundi(base_c.max_patience * 0.5))

func test_walk_up_scale_stretches_the_gap_between_customers() -> void:
	## Read straight after construction - both shifts have consumed the
	## identical rng history up to this point (patience_scale and
	## walk_up_scale change what is done WITH a roll, never how many rolls
	## happen), so the raw gap each draws is the same number before scaling.
	var baseline := _shift()
	var scaled := _shift(0, 1.0, 2.0)
	h.eq("scaled gap is exactly double the unscaled one, rounded",
		scaled.next_arrival, roundi(baseline.next_arrival * 2.0))

func test_the_shop_preview_lists_only_what_this_shifts_store_adds() -> void:
	## Every shift ends with a free card - the calendar has no room to say so
	## on every event.
	var p := ShiftProfile.new()
	h.eq("a store that adds nothing says nothing", p.reward_preview(), "")
	p.cards_for_sale = 2
	p.upgrades = 3
	var stocked := p.reward_preview()
	h.check("cards to buy and to upgrade (%s)" % stocked,
		stocked.contains("2 to buy") and stocked.contains("3 to upgrade"))
	h.check("and never the free card itself", not stocked.to_lower().contains("free card"))
	var boss := ShiftProfile.new()
	boss.free_pick_min_rarity = 2
	boss.dealership_upgrades = 1
	var better := boss.reward_preview()
	h.check("a better free card is worth saying (%s)" % better,
		better.contains(String(CardDef.Rarity.keys()[2]).capitalize()))
	h.check("and so is what making quota earns", better.contains("Make quota"))
