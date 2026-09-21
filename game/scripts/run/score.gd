class_name Score extends RefCounted
## The high score shown at the end of a run: six categories, tallied into one
## number. Every POINTS_* constant here is a tuning knob, like
## ShiftConfig.quota_growth - a guess to playtest against, not a derived value.
##
## Reads only RunState.banked_total, RunState.standing and RunState.reports -
## the full per-shift history the run already keeps for its own purposes - and
## mutates nothing, so tally() can be called as many times as the view wants
## without double-counting anything.

const POINTS_PER_MARGIN_DOLLAR := 1     ## $1 of margin banked = 1 point
const POINTS_PER_STANDING := 50         ## per point of standing held at the bell
const POINTS_LOST_PER_STANDING := 30    ## docked per point of standing lost, any cause
const POINTS_PER_WALKOUT := 200         ## flat dock per customer who walked, on top of the above
const POINTS_PER_SALE_STREAK_STEP := 100 ## Nth consecutive close (no walkout between) scores N * this
const POINTS_PER_COMBO_MULTIPLIER_POINT := 1000 ## scaled off (best_combo_multiplier - 1.0)

static func tally(run: RunState) -> Dictionary:
	var walkouts := 0
	var standing_lost := 0
	var best_streak := 0
	var streak_points := 0
	var best_combo_multiplier := 1.0
	for r in run.reports:
		walkouts += int(r.get("customers_walked", 0))
		# A shift's own net standing_delta, not a sum of every mutation inside
		# it: the per-shift report is already the granularity the player sees
		# it at (the CLOSING TIME screen shows exactly this number), so a
		# shift that healed and then lost standing nets out the same way here.
		var delta: int = int(r.get("standing_delta", 0))
		if delta < 0:
			standing_lost += -delta
		for streak in (r.get("sale_streak_events", []) as Array):
			var n := int(streak)
			best_streak = maxi(best_streak, n)
			streak_points += n * POINTS_PER_SALE_STREAK_STEP
		best_combo_multiplier = maxf(best_combo_multiplier,
			float(r.get("peak_combo_multiplier", 1.0)))

	var margin_points := run.banked_total * POINTS_PER_MARGIN_DOLLAR
	var standing_points := run.standing * POINTS_PER_STANDING
	var standing_lost_points := -standing_lost * POINTS_LOST_PER_STANDING
	var walkout_points := -walkouts * POINTS_PER_WALKOUT
	var combo_multiplier_points := roundi(
		(best_combo_multiplier - 1.0) * POINTS_PER_COMBO_MULTIPLIER_POINT)
	var total := margin_points + standing_points + standing_lost_points \
		+ walkout_points + streak_points + combo_multiplier_points

	return {
		"margin_banked": run.banked_total,
		"margin_points": margin_points,
		"standing": run.standing,
		"standing_start": run.cfg.standing_start,
		"standing_points": standing_points,
		"standing_lost": standing_lost,
		"standing_lost_points": standing_lost_points,
		"walkouts": walkouts,
		"walkout_points": walkout_points,
		"best_streak": best_streak,
		"streak_points": streak_points,
		"best_combo_multiplier": best_combo_multiplier,
		"combo_multiplier_points": combo_multiplier_points,
		"total": total,
	}
