extends RefCounted
## A walkout used to be free until the report screen, five minutes after it
## happened. "If you let too many people leave on you you will get fired" only
## means anything if it lands the moment they leave - so standing takes the hit
## immediately, in _walk(), and Shift.is_over() checks it on the spot.
var h: Harness

func _cfg(overrides: Dictionary = {}) -> ShiftConfig:
	var cfg: ShiftConfig = (load("res://data/shift_config.tres") as ShiftConfig).duplicate()
	for k in overrides:
		cfg.set(k, overrides[k])
	return cfg

func _shift(overrides: Dictionary = {}, p_standing: int = 0) -> Shift:
	return Shift.new(_cfg(overrides), load("res://data/interests/interest_pool.tres"),
		load("res://data/card_pool.tres"), load("res://data/archetype_pool.tres"),
		7, [], null, 0, 1, p_standing)

func _walk_everyone(s: Shift) -> void:
	for c in s.chairs:
		if c != null:
			c.patience = 0
	s._settle_patience()

func test_a_walkout_docks_standing_immediately_mid_shift() -> void:
	## Not "eventually, once report() is called" - the number itself has to
	## have already moved by the time _walk() returns, with the shift still
	## very much in progress.
	var s := _shift({"standing_cost_per_walkout": 8})
	var before: int = s.standing
	s.chairs[0].patience = 0
	s._settle_patience()
	h.eq("standing dropped by the configured cost, right now", s.standing, before - 8)
	h.check("mid-shift - the clock has plenty of ticks left",
		s.tick < s.tick_budget and not s.is_over())

func test_enough_walkouts_end_the_shift_immediately_regardless_of_the_clock() -> void:
	## The literal ask: hit 0 standing from a walkout and the run is over THEN,
	## not when the tick budget eventually runs out.
	var s := _shift({"standing_cost_per_walkout": 50}, 60)
	h.check("plenty of clock left", s.tick < s.tick_budget - 1)
	h.check("a floor to actually empty, or the rest of this test is theatre",
		s.chairs[0] != null and s.chairs[1] != null)
	s.chairs[0].patience = 0
	s._settle_patience()
	h.check("one walkout at this cost is not quite enough", not s.is_over())
	s.chairs[1].patience = 0
	s._settle_patience()
	h.check("a second walkout takes standing to 0 and ends it on the spot",
		s.is_over())
	h.check("with ticks that were never spent", s.tick < s.tick_budget)
	h.eq("standing reads exactly 0, never negative", s.standing, 0)

func test_a_walkout_never_reads_standing_negative() -> void:
	var s := _shift({"standing_cost_per_walkout": 9999}, 5)
	s.chairs[0].patience = 0
	s._settle_patience()
	h.eq("clamped at the floor, not -9994", s.standing, 0)
	h.eq("and the report only credits the 5 that were actually there to lose",
		int(s.report()["standing_lost_to_walkouts"]), 5)

func test_the_walkout_and_its_standing_cost_both_reach_the_log() -> void:
	var s := _shift({"standing_cost_per_walkout": 8})
	var before: int = s.events.size()
	s.chairs[0].patience = 0
	s._settle_patience()
	var added: String = " ".join(s.events.slice(before))
	h.check("the walkout itself is logged (%s)" % added, added.contains("walks out"))
	h.check("and so is what it cost (%s)" % added,
		added.contains("Standing") and added.contains("-8"))

func test_a_customer_about_to_leave_is_warned_in_the_log_once() -> void:
	var s := _shift({"leaving_soon_at": 5})
	var c: Customer = null
	for chair in s.chairs:
		if chair != null:
			c = chair
			break
	h.check("there is someone seated to warn about", c != null)

	var before: int = s.events.size()
	c.patience = 5
	s._settle_patience()
	var first_batch: String = " ".join(s.events.slice(before))
	h.check("crossing the threshold logs a warning (%s)" % first_batch,
		first_batch.contains("losing patience"))

	before = s.events.size()
	s._settle_patience()
	h.eq("staying below it does not warn again every pass",
		s.events.slice(before).size(), 0)

	c.add_patience(20)
	s._settle_patience()
	c.patience = 5
	before = s.events.size()
	s._settle_patience()
	var second_batch: String = " ".join(s.events.slice(before))
	h.check("recovering and dropping back below it warns again (%s)" % second_batch,
		second_batch.contains("losing patience"))

func test_shift_new_seeds_standing_from_the_run_or_falls_back_to_config() -> void:
	var seeded := _shift({}, 42)
	h.eq("an explicit standing is honored", seeded.standing, 42)
	var fresh := _shift({}, 0)
	h.eq("0 means unset - falls back to the config default",
		fresh.standing, fresh.cfg.standing_start)

func test_run_state_hands_its_own_current_standing_into_the_next_shift() -> void:
	var r := RunState.new(load("res://data/shift_config.tres"),
		load("res://data/interests/interest_pool.tres"),
		load("res://data/card_pool.tres"),
		load("res://data/archetype_pool.tres"), 7)
	r.standing = 63
	var s := r.start_shift(ShiftProfile.new())
	h.eq("the new shift starts counting from exactly where the run left off",
		s.standing, 63)
