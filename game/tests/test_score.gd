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
