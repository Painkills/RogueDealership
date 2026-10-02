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

func test_the_quota_climbs_by_the_configured_growth_rate() -> void:
	## Restates run_state.gd's own quota_for() formula independently (the
	## same discipline _delta() above follows) instead of pinning today's
	## five dollar amounts, which move on every quota/quota_growth retune.
	var r := _run()
	h.eq("shift 1 is the config quota", r.quota_for(1), r.cfg.quota)
	for n in range(2, 6):
		var expected := roundi(float(r.cfg.quota) * pow(1.0 + r.cfg.quota_growth, n - 1))
		h.eq("shift %d compounds from cfg.quota by cfg.quota_growth" % n,
			r.quota_for(n), expected)

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

func test_base_pay_rises_each_week() -> void:
	## "Base pay should increase each week by a little bit."
	var r := _run()
	var cfg: ShiftConfig = r.cfg
	h.eq("week one is the base", cfg.paycheck_in_week(1), cfg.paycheck)
	h.eq("each week after adds the raise", cfg.paycheck_in_week(3),
		cfg.paycheck + 2 * cfg.paycheck_raise_per_week)
	var first_week := r.start_shift(ShiftProfile.new()).report()
	h.eq("a shift in week one carries week one's pay", first_week["paycheck"], cfg.paycheck)
	r.shift_number = cfg.days_per_week + 1
	h.eq("and one in week two carries week two's",
		r.start_shift(ShiftProfile.new()).report()["paycheck"], cfg.paycheck_in_week(2))

func test_missing_quota_costs_nothing_more_than_the_bonus() -> void:
	## Money's OWN floor, isolated from standing: standing_delta is pinned to 0
	## here on purpose, so this checks only that a miss never dips the bonus pot
	## below 0 - not whether repeated misses end the run, which is a different
	## invariant now (see test_repeated_total_failure_ends_the_run below) and was
	## in fact the exact behaviour this whole feature exists to change.
	var r := _run()
	for i in range(r.cfg.shifts_in_run):
		r.finish_shift({"margin_banked": 0, "quota": r.quota_for(i + 1),
			"made_quota": false, "standing_delta": 0})
	h.eq("a run of straight misses, still nothing to spend", r.money, 0)
	h.check("standing untouched by a neutral delta", r.standing == r.cfg.standing_start)
	h.check("so the run ran its full length", r.is_over())

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

func test_letting_customers_walk_can_end_a_run_on_its_own() -> void:
	## The literal ask: "if you let too many people leave on you you will get
	## fired." A shift that MEETS quota (no quota-side damage at all) still has
	## to be able to end the run if enough customers walk out of it.
	var r := _run()
	var quota := r.quota_for(1)
	var walkout_heavy := {"margin_banked": quota, "quota": quota, "made_quota": true,
		"customers_walked": 7, "standing_delta": -7 * r.cfg.standing_cost_per_walkout}
	r.finish_shift(walkout_heavy)
	h.check("meeting quota with a bled-dry floor still survives one shift",
		not r.is_over())
	h.eq("costing exactly the walkout rate, nothing from quota",
		r.standing, r.cfg.standing_start - 7 * r.cfg.standing_cost_per_walkout)
	r.finish_shift(walkout_heavy)
	h.check("a second walkout-heavy shift ends the run on its own",
		r.is_over())
	h.check("strictly before shift 5", r.shift_number <= r.cfg.shifts_in_run)

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
	profile.unlock_full_archetype_pool = true
	var s := r.start_shift(profile)
	h.eq("seats reached the shift", s.chairs.size(), 2)
	h.eq("patience_scale reached the shift", s.patience_scale, 0.5)
	h.eq("walk_up_scale reached the shift", s.walk_up_scale, 2.0)
	h.check("unlock_full_archetype_pool reached the shift",
		s.unlock_full_archetype_pool)

func test_a_shifts_quota_scale_and_offset_set_its_quota() -> void:
	## "Make the quota on morning a little higher" - "give morning the flat
	## quota increase": a scale on the run's own climbing quota, then a flat
	## amount on top.
	var r := _run()
	var p := ShiftProfile.new()
	p.quota_scale = 1.2
	h.eq("the run's quota, scaled by the shift's own",
		r.start_shift(p).quota, roundi(r.quota_for(r.shift_number) * 1.2))
	p.quota_offset = 250
	h.eq("and the flat offset on top",
		r.start_shift(p).quota, roundi(r.quota_for(r.shift_number) * 1.2) + 250)
	p.quota = 1234
	h.eq("a premade shift's own quota wins over the scale", r.start_shift(p).quota, 1234)

func test_a_shifts_commission_sets_what_beating_quota_pays() -> void:
	## Midday, night and the boss pay better for the same margin over quota.
	var r := _run()
	var p := ShiftProfile.new()
	p.commission = 0.4
	var report := r.start_shift(p).report()
	h.eq("the shift's report carries its commission", report["commission"], 0.4)
	h.eq("and the base salary", report["paycheck"], r.cfg.paycheck)
	report["margin_banked"] = int(report["quota"]) - 1
	h.eq("missing quota pays the base", RunState.bonus_from(report), r.cfg.paycheck)
	var over := 1000
	report["margin_banked"] = int(report["quota"]) + over
	var expected: int = r.cfg.paycheck + roundi(over * 0.4)
	h.eq("beating it pays the base plus the commission", RunState.bonus_from(report), expected)
	r.finish_shift(report)
	h.eq("and that is what goes in the pot", r.money, expected)

func test_a_shifts_pay_scale_sets_its_base_salary() -> void:
	## A night differential: a shift can pay more (or less) than the week's base,
	## made quota or not.
	var r := _run()
	var p := ShiftProfile.new()
	p.pay_scale = 1.5
	var report := r.start_shift(p).report()
	var base: int = roundi(r.cfg.paycheck_in_week(1) * 1.5)
	h.eq("the report carries the scaled base salary", report["paycheck"], base)
	report["margin_banked"] = 0
	h.eq("and a miss still pays it", RunState.bonus_from(report), base)
	var plain := r.start_shift(ShiftProfile.new()).report()
	h.eq("a shift that sets none pays the week's base", plain["paycheck"],
		r.cfg.paycheck_in_week(1))

func test_a_shift_with_a_heal_restores_standing_only_for_passing() -> void:
	## "You should only heal at the end of a boss fight if you pass quota."
	var r := _run()
	var p := ShiftProfile.new()
	p.heal_up_to = 0.25
	var s := r.start_shift(p)
	s.quota = 1000
	var full := roundi(0.25 * r.cfg.standing_start)
	s.margin_banked = 2000
	h.eq("passing heals all of it, and no more for beating it",
		int(s.report()["standing_healed"]), full)
	s.margin_banked = 999
	h.eq("a dollar short heals nothing", int(s.report()["standing_healed"]), 0)
	s.margin_banked = 1000
	h.eq("and the heal is in the standing the run is given",
		int(s.report()["standing_delta"]), full)
	h.eq("a shift without one heals nothing",
		int(r.start_shift(ShiftProfile.new()).report()["standing_healed"]), 0)

func test_the_run_knows_its_weeks() -> void:
	var r := _run()
	var per_week: int = r.cfg.days_per_week
	h.eq("day 1 is week 1", r.week_of(1), 1)
	h.eq("the week's last day still is", r.week_of(per_week), 1)
	h.eq("the next is week 2", r.week_of(per_week + 1), 2)
	h.check("the first day does not start a NEW week", not r.week_starts_today())
	r.shift_number = per_week + 1
	h.check("the day after the last of a week does", r.week_starts_today())
	r.shift_number = per_week + 2
	h.check("and the day after that does not", not r.week_starts_today())

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
