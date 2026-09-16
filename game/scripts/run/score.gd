class_name Score extends RefCounted
## The high score shown at the end of a run: five categories, tallied into one
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
const POINTS_PER_COMBO_STEP := 100      ## Nth consecutive close (no walkout between) scores N * this

static func tally(run: RunState) -> Dictionary:
	var walkouts := 0
	var standing_lost := 0
	var best_combo := 0
	var combo_points := 0
	for r in run.reports:
		walkouts += int(r.get("customers_walked", 0))
		# A shift's own net standing_delta, not a sum of every mutation inside
		# it: the per-shift report is already the granularity the player sees
		# it at (the CLOSING TIME screen shows exactly this number), so a
		# shift that healed and then lost standing nets out the same way here.
		var delta: int = int(r.get("standing_delta", 0))
		if delta < 0:
			standing_lost += -delta
		for streak in (r.get("combo_events", []) as Array):
			var n := int(streak)
			best_combo = maxi(best_combo, n)
			combo_points += n * POINTS_PER_COMBO_STEP

	var margin_points := run.banked_total * POINTS_PER_MARGIN_DOLLAR
	var standing_points := run.standing * POINTS_PER_STANDING
	var standing_lost_points := -standing_lost * POINTS_LOST_PER_STANDING
	var walkout_points := -walkouts * POINTS_PER_WALKOUT
	var total := margin_points + standing_points + standing_lost_points \
		+ walkout_points + combo_points

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
		"best_combo": best_combo,
		"combo_points": combo_points,
		"total": total,
	}
