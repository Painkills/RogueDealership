extends RefCounted
## The compact customer face: the interest grid, the demand telegraph, and what
## counts as "taken".
##
## All of it is reachable without a canvas, which is the whole reason the
## ordering was hoisted out of _draw() - the same move appeal_bar.gd made for
## marker_y(), and for the same reason: a rule that only exists inside _draw()
## is a rule no headless suite can ever check.
var h: Harness

func _pool() -> InterestPool:
	return load("res://data/interests/interest_pool.tres")

func _shift(floor_ids: Array) -> Shift:
	var cfg: ShiftConfig = (load("res://data/shift_config.tres") as ShiftConfig).duplicate()
	cfg.patience_jitter = 0
	cfg.action_cadence_jitter_ticks = 0
	cfg.prior_slip = 0.0
	cfg.arrival_patience_min_fraction = 1.0
	return Shift.new(cfg, _pool(), load("res://data/card_pool.tres"),
		load("res://data/archetype_pool.tres"), 1, floor_ids)

# ------------------------------------------------------------ the telegraph
func test_a_customer_asking_for_nothing_telegraphs_nothing() -> void:
	var s := _shift([&"easygoing"])
	h.eq("no demand, no line", CustomerCard3D.demand_text(s.chairs[0], s.tick), "")

func test_the_countdown_never_reads_negative() -> void:
	## It is read every render, including the render that happens on the tick
	## the demand comes due, so an unclamped subtraction would flash "-1t".
	var s := _shift([&"easygoing"])
	var c: Customer = s.chairs[0]
	var d := Demand.new()
	d.telegraph = "WELL?"
	d.ticks = 1
	d.resolve = PlayConcession.new()
	c.demand = d
	c.demand_due_tick = 0
	h.eq("clamped at zero", CustomerCard3D.demand_text(c, 5), "WELL?  0t")

# ------------------------------------------------------------- category icons
## CategoryIcon.draw() itself only works inside a live _draw() - see this
## file's own header - but the SHAPES it draws are pure functions precisely so
## a headless test can still check that "car", "tag" and "person" are actually
## three different things, and that none of them draws outside the box it was
## given (a card_front row is only 44px tall; a point that drifts out of rect
## would clip against its neighbour rather than just look ugly).

const CATEGORIES: Array[StringName] = [&"vehicle", &"deal", &"person"]
