extends RefCounted
## Score.tally() - the six categories the end-of-run screen adds into one
## high score. Fabricated report dicts throughout, the same restatement-not-
## a-call-into-it style test_run_state.gd already uses: each dict carries only
## the keys the assertion it feeds actually needs.
var h: Harness

func _run(seed_value: int = 7) -> RunState:
	return RunState.new(load("res://data/shift_config.tres"),
		load("res://data/interests/interest_pool.tres"),
		load("res://data/card_pool.tres"),
		load("res://data/archetype_pool.tres"), seed_value)

func test_margin_and_standing_score_from_the_runs_own_totals() -> void:
	var r := _run()
	r.finish_shift({"margin_banked": 4200, "quota": 3600, "standing_delta": 0,
		"customers_walked": 0, "sale_streak_events": []})
	var score := Score.tally(r)
	h.eq("margin scores a fixed point per dollar banked, lifetime",
		score["margin_points"], r.banked_total * Score.POINTS_PER_MARGIN_DOLLAR)
	h.eq("standing scores per point held at the final bell",
		score["standing_points"], r.standing * Score.POINTS_PER_STANDING)

func test_standing_lost_only_counts_shifts_that_net_negative() -> void:
	## A shift that healed does not cancel out a shift that later lost ground -
	## each shift's own net is judged on its own, the same granularity the
	## CLOSING TIME report already shows the player.
	var r := _run()
	r.finish_shift({"margin_banked": 9999, "quota": 100, "standing_delta": 20,
		"customers_walked": 0, "sale_streak_events": []})
	r.finish_shift({"margin_banked": 0, "quota": 100, "standing_delta": -15,
		"customers_walked": 0, "sale_streak_events": []})
	var score := Score.tally(r)
	h.eq("only the losing shift's magnitude counts as lost",
		score["standing_lost"], 15)
	h.eq("docked at the configured rate", score["standing_lost_points"],
		-15 * Score.POINTS_LOST_PER_STANDING)

func test_walkouts_dock_a_flat_amount_each_summed_across_the_whole_run() -> void:
	var r := _run()
	r.finish_shift({"margin_banked": 0, "quota": 100, "standing_delta": 0,
		"customers_walked": 2, "sale_streak_events": []})
	r.finish_shift({"margin_banked": 0, "quota": 100, "standing_delta": 0,
		"customers_walked": 1, "sale_streak_events": []})
	var score := Score.tally(r)
	h.eq("walkouts summed across every shift in the run", score["walkouts"], 3)
	h.eq("docked at the flat per-walkout rate", score["walkout_points"],
		-3 * Score.POINTS_PER_WALKOUT)

func test_streak_points_reward_the_length_of_a_streak_not_just_the_sale_count() -> void:
	## Three sales in one unbroken streak (1, 2, 3) must outscore the same
	## three sales each isolated by a walkout (1, 1, 1) - equal sales, very
	## different totals. This is the floor-wide sale_streak mechanic, not the
	## per-customer combo multiplier (see test_combo.gd) - the two are scored
	## as separate categories below.
	var clean := _run(1)
	clean.finish_shift({"margin_banked": 0, "quota": 100, "standing_delta": 0,
		"customers_walked": 0, "sale_streak_events": [1, 2, 3], "sale_streak_end": 3})
	var clean_score := Score.tally(clean)
	h.eq("a clean streak of 3 scores 1+2+3 streak steps",
		clean_score["streak_points"], (1 + 2 + 3) * Score.POINTS_PER_SALE_STREAK_STEP)
	h.eq("its peak is remembered for display", clean_score["best_streak"], 3)

	var broken := _run(2)
	broken.finish_shift({"margin_banked": 0, "quota": 100, "standing_delta": 0,
		"customers_walked": 2, "sale_streak_events": [1, 1, 1], "sale_streak_end": 0})
	var broken_score := Score.tally(broken)
	h.eq("the same three sales, each starting the streak over, score far less",
		broken_score["streak_points"], 3 * Score.POINTS_PER_SALE_STREAK_STEP)
	h.check("strictly less than the unbroken streak despite equal sales",
		broken_score["streak_points"] < clean_score["streak_points"])

func test_a_streak_keeps_climbing_across_shifts_that_carried_it() -> void:
	## sale_streak_events only ever holds the values THIS shift's closes landed
	## on - a streak that started in shift 1 and continued into shift 2 shows
	## up as [3] in shift 2's own events, not [1, 2, 3] repeated. Score still
	## has to credit the full climb once both shifts are summed.
	var r := _run()
	r.finish_shift({"margin_banked": 0, "quota": 100, "standing_delta": 0,
		"customers_walked": 0, "sale_streak_events": [1, 2], "sale_streak_end": 2})
	r.finish_shift({"margin_banked": 0, "quota": 100, "standing_delta": 0,
		"customers_walked": 0, "sale_streak_events": [3], "sale_streak_end": 3})
	var score := Score.tally(r)
	h.eq("every step of the carried-forward climb scores",
		score["streak_points"], (1 + 2 + 3) * Score.POINTS_PER_SALE_STREAK_STEP)
	h.eq("and the peak reflects the shift that reached it", score["best_streak"], 3)

func test_combo_multiplier_points_reward_the_peak_reached_anywhere_in_the_run() -> void:
	## peak_combo_multiplier is a per-shift float (Shift._settle()'s combo
	## multiplier, at its highest point that shift) - Score takes the max
	## across every shift in the run, the same maxi()-over-reports shape
	## best_streak already uses, just with maxf() and a float baseline of 1.0.
	var r := _run()
	r.finish_shift({"margin_banked": 0, "quota": 100, "standing_delta": 0,
		"customers_walked": 0, "sale_streak_events": [], "peak_combo_multiplier": 1.2})
	r.finish_shift({"margin_banked": 0, "quota": 100, "standing_delta": 0,
		"customers_walked": 0, "sale_streak_events": [], "peak_combo_multiplier": 1.6})
	var score := Score.tally(r)
	h.eq("the peak is the highest multiplier reached in ANY shift, not the last",
		score["best_combo_multiplier"], 1.6)
	h.eq("scored off how far above the no-effort baseline of 1.0 it got",
		score["combo_multiplier_points"],
		roundi(0.6 * Score.POINTS_PER_COMBO_MULTIPLIER_POINT))

func test_a_run_that_never_chained_a_sale_scores_nothing_for_combo() -> void:
	var r := _run()
	r.finish_shift({"margin_banked": 0, "quota": 100, "standing_delta": 0,
		"customers_walked": 0, "sale_streak_events": []})
	var score := Score.tally(r)
	h.eq("no report ever mentioned a multiplier, so the peak stays at baseline",
		score["best_combo_multiplier"], 1.0)
	h.eq("and the baseline earns exactly zero, same as a walkout-free shift",
		score["combo_multiplier_points"], 0)

func test_the_total_is_exactly_the_sum_of_the_six_lines_shown() -> void:
	var r := _run()
	r.finish_shift({"margin_banked": 1000, "quota": 100, "standing_delta": -10,
		"customers_walked": 1, "sale_streak_events": [1], "sale_streak_end": 0,
		"peak_combo_multiplier": 1.4})
	var score := Score.tally(r)
	h.eq("the headline total is exactly what the six category lines add up to",
		score["total"], score["margin_points"] + score["standing_points"]
			+ score["standing_lost_points"] + score["walkout_points"]
			+ score["streak_points"] + score["combo_multiplier_points"])
