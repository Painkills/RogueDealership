extends RefCounted
## A run: five shifts, a shop between them, one deck through all of it.
var h: Harness

func _run(seed_value: int = 7) -> RunState:
	return RunState.new(load("res://data/shift_config.tres"),
		load("res://data/interests/interest_pool.tres"),
		load("res://data/card_pool.tres"),
		load("res://data/archetype_pool.tres"), seed_value)

## Mirrors Shift._standing_delta_from_quota() - an independent restatement of
## the rule, not a call into it, so a fabricated report can carry a genuinely
## correct standing_delta.
func _delta(margin: int, quota: int, cfg: ShiftConfig, week: int = 0) -> int:
	if margin >= quota:
		return roundi(float(margin - quota) / float(quota) * cfg.standing_heal_scale)
	var caps: Array[int] = cfg.miss_standing_max_by_week
	var cap: int = caps[mini(week, caps.size() - 1)] if not caps.is_empty() \
		else cfg.miss_standing_min
	var short := float(quota - margin) / float(quota)
	return -roundi(lerpf(float(cfg.miss_standing_min), float(cap), short))

func _report(margin: int, quota: int, cfg: ShiftConfig) -> Dictionary:
	return {"margin_banked": margin, "quota": quota, "made_quota": margin >= quota,
		"paycheck": cfg.paycheck, "standing_delta": _delta(margin, quota, cfg)}

func test_a_run_starts_on_shift_one_with_a_starter_deck_and_no_money() -> void:
	var r := _run()
	h.eq("first shift", r.shift_number, 1)
	h.eq("nothing banked yet", r.banked_total, 0)
	h.eq("and nothing to spend", r.money, 0)
	h.eq("standing starts full, from cfg rather than a hardcoded number",
		r.standing, r.cfg.standing_start)
	h.eq("with the starter deck", r.deck.cards.size(),
		Deck.build_starting(load("res://data/card_pool.tres")).cards.size())
	h.check("which is not over", not r.is_over())

func test_every_shift_pays_its_paycheck() -> void:
	## "There should be a 'paycheck'... You get that as long as you're not
	## fired" - made quota or not.
	var r := _run()
	var pay: int = r.cfg.paycheck
	r.finish_shift(_report(500, 3600, r.cfg))
	h.eq("missing quota still pays it", r.money, pay)
	h.eq("and the shift says so", r.last_bonus, pay)
	r.finish_shift(_report(4140, 4140, r.cfg))
	h.eq("landing exactly on quota pays it, no more", r.last_bonus, pay)
	h.eq("and paychecks stack in the pot", r.money, pay * 2)
	h.eq("while the lifetime total counts every dollar banked", r.banked_total, 4640)

func test_beating_quota_adds_a_commission_on_the_overage() -> void:
	## "Base salary plus X percent over quota (differentiated by shift type)."
	## Made-up reports, so no tuned number is pinned here.
	h.eq("a share of the dollars banked over quota, on top of the base", RunState.bonus_from(
		{"margin_banked": 1500, "quota": 1000, "paycheck": 1000, "commission": 0.3}), 1150)
	h.eq("a higher commission pays more for the same overage", RunState.bonus_from(
		{"margin_banked": 1500, "quota": 1000, "paycheck": 1000, "commission": 0.5}), 1250)
	h.eq("landing on quota pays the base alone", RunState.bonus_from(
		{"margin_banked": 1000, "quota": 1000, "paycheck": 1000, "commission": 0.5}), 1000)
	h.eq("never less than the base salary", RunState.bonus_from(
		{"margin_banked": 0, "quota": 1000, "paycheck": 1000, "commission": 0.5}), 1000)
	h.eq("and a report without one pays nothing extra", RunState.bonus_from(
		{"margin_banked": 100, "quota": 3600}), 0)

func test_repeated_total_failure_ends_the_run_before_it_would_naturally_end() -> void:
	## "You shouldn't be able to 'lose' and keep going."
	var r := _run()
	r.finish_shift(_report(0, r.quota_for(1), r.cfg))
	h.check("one wipeout survives", not r.is_over())
	h.eq("costing the week's whole cap",
		r.standing, r.cfg.standing_start - r.cfg.miss_standing_max_by_week[0])
	var guard := 0
	while not r.is_over() and guard < 20:
		r.finish_shift(_report(0, r.quota_for(r.shift_number), r.cfg))
		guard += 1
	h.check("enough wipeouts end the run", r.is_over() and r.standing == 0)
	h.check("before its last shift", r.shift_number <= r.cfg.shifts_in_run)

func test_standing_clamps_at_both_ends() -> void:
	var r := _run()
	r.finish_shift({"margin_banked": 0, "quota": 1000, "made_quota": false,
		"standing_delta": -30})
	h.eq("a partial wipeout", r.standing, r.cfg.standing_start - 30)
	r.finish_shift({"margin_banked": 0, "quota": 1000, "made_quota": false,
		"standing_delta": -9999})
	h.eq("a huge hit clamps at 0, not negative", r.standing, 0)
	r.finish_shift({"margin_banked": 9999, "quota": 1000, "made_quota": true,
		"standing_delta": 9999})
	h.eq("a huge heal clamps at the start value, not past it",
		r.standing, r.cfg.standing_start)

func test_the_shift_it_builds_carries_the_run_state() -> void:
	var r := _run()
	r.shift_number = 3
	var s := r.start_shift(ShiftProfile.new())
	h.eq("the shift knows which one it is", s.shift_number, 3)
	h.eq("and runs to that shift's quota", s.quota, r.quota_for(3))
	var uids := {}
	for c in r.deck.cards:
		uids[c.uid] = true
	for c in s.hand:
		h.check("it deals from the run's deck", uids.has(c.uid))

func test_start_shift_threads_the_picked_profiles_fields_through() -> void:
	var r := _run()
	var profile := ShiftProfile.new()
	profile.seats = 2
	profile.patience_scale = 0.5
	profile.walk_up_scale = 2.0
	profile.line_offset = 3
	profile.combo_scale = 2.0
	var s := r.start_shift(profile)
	h.eq("seats reached the shift", s.chairs.size(), 2)
	h.eq("patience_scale reached the shift", s.patience_scale, 0.5)
	h.eq("walk_up_scale reached the shift", s.walk_up_scale, 2.0)
	h.eq("line_offset reached the shift", s.line_offset, 3)
	h.eq("combo_scale reached the shift", s.combo_scale, 2.0)

func test_two_runs_from_one_seed_are_identical() -> void:
	## The whole reason the run owns a seeded rng instead of calling randi().
	var a := _run(4242)
	var b := _run(4242)
	var sa := a.start_shift(ShiftProfile.new())
	var sb := b.start_shift(ShiftProfile.new())
	var ids_a: Array[String] = []
	var ids_b: Array[String] = []
	for c in sa.seated():
		ids_a.append(String(c.archetype.id))
	for c in sb.seated():
		ids_b.append(String(c.archetype.id))
	h.eq("the same floor walks in", ids_a, ids_b)
