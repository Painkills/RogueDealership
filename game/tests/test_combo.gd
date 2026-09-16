extends RefCounted
## Shift.combo_streak / combo_events - the raw mechanic Score turns into
## points. Shift only tracks the streak and the order it grew in; it knows
## nothing about scoring, exactly the same split RunState.bonus_from() draws
## between "what happened" and "what it's worth".
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

func _at(s: Shift, chair: int) -> Customer:
	s.at = chair
	s.last_customer = s.chairs[chair]
	return s.chairs[chair]

func test_closes_build_a_streak_and_a_walkout_anywhere_breaks_it() -> void:
	var s := _shift([&"easygoing", &"easygoing", &"easygoing"])
	h.eq("a fresh shift's streak starts at zero", s.combo_streak, 0)
	h.eq("with nothing recorded yet", s.combo_events, [])

	_at(s, 0)
	h.check("closing chair A succeeds", s.close().ok)
	h.eq("the first close starts the streak at 1", s.combo_streak, 1)
	h.eq("recorded in order", s.combo_events, [1])

	_at(s, 1)
	h.check("closing chair B succeeds too", s.close().ok)
	h.eq("a second straight close climbs the streak", s.combo_streak, 2)
	h.eq("both closes kept, in order", s.combo_events, [1, 2])

	# Chair C walks - not closed, not even approached. The streak is a
	# floor-wide fact, so this breaks it even though neither close above
	# involved this chair at all.
	s.chairs[2].patience = 0
	s._settle_patience()
	h.eq("customer C actually walked", s.stat["customers_walked"], 1)
	h.eq("the walkout zeroes the streak", s.combo_streak, 0)
	h.eq("but does not erase closes already recorded", s.combo_events, [1, 2])

	# A fresh customer in the now-empty chair, spawned directly rather than
	# burning ticks through walk_up - this test is about the streak, not
	# about waiting.
	s.walk_up[2] = 0
	s._spawn(2)
	_at(s, 2)
	h.check("closing the new arrival succeeds", s.close().ok)
	h.eq("the streak starts back over at 1, not 3", s.combo_streak, 1)
	h.eq("appended after the walkout, not replacing what came before",
		s.combo_events, [1, 2, 1])

	var r := s.report()
	h.eq("the report carries the ending streak forward", r["combo_streak_end"], 1)
	h.eq("and the full event sequence", r["combo_events"], [1, 2, 1])

func test_a_shift_can_start_mid_streak_carried_in_from_the_run() -> void:
	var cfg: ShiftConfig = (load("res://data/shift_config.tres") as ShiftConfig).duplicate()
	cfg.patience_jitter = 0
	cfg.prior_slip = 0.0
	cfg.arrival_patience_min_fraction = 1.0
	var s := Shift.new(cfg, load("res://data/interests/interest_pool.tres"),
		load("res://data/card_pool.tres"), load("res://data/archetype_pool.tres"),
		1, [&"easygoing"], null, 0, 1, 0, 4)
	h.eq("a shift told it is continuing a streak starts there, not at zero",
		s.combo_streak, 4)
	_at(s, 0)
	h.check("closing continues it", s.close().ok)
	h.eq("the very next close climbs from the carried-in value", s.combo_streak, 5)
	h.eq("only THIS shift's own close is in its own event list",
		s.combo_events, [5])

func test_the_run_carries_the_streak_from_one_shift_into_the_next() -> void:
	var run := RunState.new(load("res://data/shift_config.tres"),
		load("res://data/interests/interest_pool.tres"),
		load("res://data/card_pool.tres"),
		load("res://data/archetype_pool.tres"), 7)
	h.eq("a new run has no streak yet", run.combo_streak, 0)
	run.finish_shift({"margin_banked": 0, "quota": 100, "standing_delta": 0,
		"combo_streak_end": 3})
	h.eq("the run remembers the streak the shift ended on", run.combo_streak, 3)
	var next_shift := run.start_shift()
	h.eq("and hands it to the next shift as its starting streak",
		next_shift.combo_streak, 3)
