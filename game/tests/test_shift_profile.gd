extends RefCounted
## The trailing Shift.new() knobs a picked ShiftProfile threads through -
## floor size, patience scale, walk-up scale. All three default to their
## no-op value (0, 1.0, 1.0), so every pre-existing Shift.new() call site is
## unaffected - that is what the "falls back" tests below pin down.
##
## The archetype-pool unlock has its own coverage, alongside the rest of the
## min_shift ladder it overrides, in test_archetype_gating.gd. RunState
## actually threading a ShiftProfile's fields through start_shift() has its
## own coverage in test_run_state.gd.
var h: Harness

func _cfg() -> ShiftConfig:
	var cfg: ShiftConfig = (load("res://data/shift_config.tres") as ShiftConfig).duplicate()
	cfg.patience_jitter = 0
	cfg.action_cadence_jitter_ticks = 0
	cfg.prior_slip = 0.0
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

func test_default_patience_scale_matches_the_unscaled_shift() -> void:
	var a := _shift()
	var b := _shift(0, 1.0)
	for i in range(a.seated().size()):
		h.eq("chair %d: 1.0 changes nothing" % i,
			b.seated()[i].max_patience, a.seated()[i].max_patience)

func test_walk_up_scale_stretches_the_wait_before_a_chair_refills() -> void:
	## Called directly, right after construction - both shifts have consumed
	## the identical rng history up to this point (patience_scale and
	## walk_up_scale change what is done WITH a roll, never how many rolls
	## happen), so the raw wait each draws is the same number before scaling.
	var baseline := _shift()
	var scaled := _shift(0, 1.0, 2.0)
	baseline._vacate(0)
	scaled._vacate(0)
	h.eq("scaled wait is exactly double the unscaled one, rounded",
		scaled.walk_up[0], roundi(baseline.walk_up[0] * 2.0))

func test_default_walk_up_scale_matches_the_unscaled_shift() -> void:
	var a := _shift()
	var b := _shift(0, 1.0, 1.0)
	a._vacate(0)
	b._vacate(0)
	h.eq("1.0 changes nothing", b.walk_up[0], a.walk_up[0])
