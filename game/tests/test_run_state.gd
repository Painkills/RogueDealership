extends RefCounted
## A run: five shifts, a shop between them, one deck through all of it.
var h: Harness

func _run(seed_value: int = 7) -> RunState:
	return RunState.new(load("res://data/shift_config.tres"),
		load("res://data/interests/interest_pool.tres"),
		load("res://data/card_pool.tres"),
		load("res://data/archetype_pool.tres"), seed_value)

## Mirrors Shift._standing_delta() exactly, the way test_cards.gd's
## `p.margin * 5 / 4` mirrors the upgrade-ratio rule it is checking - an
## independent restatement of the formula, not a call into it, so a fabricated
## report dict here can carry a genuinely correct standing_delta rather than a
## placeholder that happens not to crash finish_shift().
func _delta(margin: int, quota: int, cfg: ShiftConfig) -> int:
	if margin >= quota:
		return roundi(float(margin - quota) / float(quota) * cfg.standing_heal_scale)
	return -roundi(float(quota - margin) / float(quota) * cfg.standing_damage_scale)

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

func test_the_quota_climbs_a_fixed_percentage() -> void:
	var r := _run()
	h.eq("shift 1 is the config quota", r.quota_for(1), 3600)
	h.eq("shift 2", r.quota_for(2), 4140)
	h.eq("shift 3", r.quota_for(3), 4761)
	h.eq("shift 4", r.quota_for(4), 5475)
	h.eq("shift 5", r.quota_for(5), 6296)

func test_only_what_you_bank_over_quota_becomes_a_bonus() -> void:
	## The quota is the house's cut and comes out first. What survives it is the
	## bonus, and bonuses STACK for the length of the run.
	var r := _run()
	r.finish_shift({"margin_banked": 4200, "quota": 3600, "made_quota": true,
		"standing_delta": _delta(4200, 3600, r.cfg)})
	h.eq("you advance a shift", r.shift_number, 2)
	h.eq("the bonus is the OVERAGE, not the take", r.money, 600)
	h.eq("and the shift says what it just added", r.last_bonus, 600)
	h.eq("while the lifetime total counts every dollar", r.banked_total, 4200)

	r.finish_shift({"margin_banked": 5000, "quota": 4140, "made_quota": true,
		"standing_delta": _delta(5000, 4140, r.cfg)})
	h.eq("the next bonus STACKS rather than replacing", r.money, 600 + 860)
	h.eq("though last_bonus is only the latest shift's", r.last_bonus, 860)
	h.eq("and the lifetime total keeps climbing", r.banked_total, 9200)
	h.eq("with every report kept", r.reports.size(), 2)

func test_a_shift_that_earns_no_bonus_leaves_the_pot_untouched() -> void:
	## The threshold has teeth on both sides, and neither side goes negative or
	## takes back what earlier shifts already earned.
	var r := _run()
	r.finish_shift({"margin_banked": 4600, "quota": 3600, "made_quota": true,
		"standing_delta": _delta(4600, 3600, r.cfg)})
	h.eq("a good shift builds the pot", r.money, 1000)

	r.finish_shift({"margin_banked": 500, "quota": 4140, "made_quota": false,
		"standing_delta": _delta(500, 4140, r.cfg)})
	h.eq("missing quota adds nothing", r.last_bonus, 0)
	h.eq("but never DRAINS what you already had", r.money, 1000)

	r.finish_shift({"margin_banked": 4761, "quota": 4761, "made_quota": true,
		"standing_delta": _delta(4761, 4761, r.cfg)})
	h.eq("and landing on it exactly adds nothing either", r.money, 1000)

	r.finish_shift({"margin_banked": 5476, "quota": 5475, "made_quota": true,
		"standing_delta": _delta(5476, 5475, r.cfg)})
	h.eq("one dollar over is one dollar added", r.money, 1001)

func test_the_bonus_is_readable_before_the_run_advances() -> void:
	## The report panel puts this number on screen while you are still looking at
	## the shift you just played - finish_shift() has not run yet.
	h.eq("an over-quota shift", RunState.bonus_from(
		{"margin_banked": 4200, "quota": 3600}), 600)
	h.eq("never reads negative", RunState.bonus_from(
		{"margin_banked": 100, "quota": 3600}), 0)

func test_missing_quota_costs_nothing_more_than_the_bonus() -> void:
	## Money's OWN floor, isolated from standing: standing_delta is pinned to 0
	## here on purpose, so this checks only that a miss never dips the bonus pot
	## below 0 - not whether repeated misses end the run, which is a different
	## invariant now (see test_repeated_total_failure_ends_the_run below) and was
	## in fact the exact behaviour this whole feature exists to change.
	var r := _run()
	for i in range(5):
		r.finish_shift({"margin_banked": 0, "quota": r.quota_for(i + 1),
			"made_quota": false, "standing_delta": 0})
	h.eq("five straight misses, still nothing to spend", r.money, 0)
	h.check("standing untouched by a neutral delta", r.standing == r.cfg.standing_start)
	h.check("so the run ran its full five shifts", r.is_over())

func test_repeated_total_failure_ends_the_run_before_it_would_naturally_end() -> void:
	## The literal bug report: before this feature, you could play every shift
	## badly and still walk into shift 5 on schedule - a scorecard with no
	## stakes. A standing meter has to make that false.
	var r := _run()
	var wiped_out := {"margin_banked": 0, "quota": r.quota_for(1), "made_quota": false,
		"standing_delta": _delta(0, r.quota_for(1), r.cfg)}
	r.finish_shift(wiped_out)
	h.check("one wipeout survives", not r.is_over())
	h.eq("but costs half of standing", r.standing, 50)
	r.finish_shift(wiped_out)
	h.check("a second wipeout ends the run", r.is_over())
	h.check("strictly before shift 5", r.shift_number <= r.cfg.shifts_in_run)

func test_standing_clamps_at_both_ends() -> void:
	var r := _run()
	r.finish_shift({"margin_banked": 0, "quota": 1000, "made_quota": false,
		"standing_delta": -30})
	h.eq("a partial wipeout", r.standing, 70)
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
	var s := r.start_shift()
	h.eq("the shift knows which one it is", s.shift_number, 3)
	h.eq("and runs to that shift's quota", s.quota, r.quota_for(3))
	var uids := {}
	for c in r.deck.cards:
		uids[c.uid] = true
	for c in s.hand:
		h.check("it deals from the run's deck", uids.has(c.uid))

func test_two_runs_from_one_seed_are_identical() -> void:
	## The whole reason the run owns a seeded rng instead of calling randi().
	var a := _run(4242)
	var b := _run(4242)
	var sa := a.start_shift()
	var sb := b.start_shift()
	var ids_a: Array[String] = []
	var ids_b: Array[String] = []
	for c in sa.seated():
		ids_a.append(String(c.archetype.id))
	for c in sb.seated():
		ids_b.append(String(c.archetype.id))
	h.eq("the same floor walks in", ids_a, ids_b)
