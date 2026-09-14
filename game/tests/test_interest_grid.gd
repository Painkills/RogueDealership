extends RefCounted
## The compact customer face: the interest grid, the demand telegraph, and what
## counts as "taken".
##
## All of it is reachable without a canvas, which is the whole reason the
## ordering was hoisted out of _draw() - the same move appeal_bar.gd made for
## marker_x(), and for the same reason: a rule that only exists inside _draw()
## is a rule no headless suite can ever check.
var h: Harness

func _pool() -> InterestPool:
	return load("res://data/interests/interest_pool.tres")

func _ids(row: Array) -> Array:
	var out := []
	for i in row:
		out.append(i.id)
	return out

func _shift(floor_ids: Array) -> Shift:
	var cfg: ShiftConfig = (load("res://data/shift_config.tres") as ShiftConfig).duplicate()
	cfg.patience_jitter = 0
	cfg.prior_slip = 0.0
	cfg.arrival_patience_min_fraction = 1.0
	return Shift.new(cfg, _pool(), load("res://data/card_pool.tres"),
		load("res://data/archetype_pool.tres"), 1, floor_ids)

# ------------------------------------------------------------- the ordering
func test_a_row_you_know_nothing_about_keeps_pool_order() -> void:
	var pool := _pool()
	var row := pool.in_category(pool.categories[0])
	h.check("the category has cells in it", row.size() >= 2)
	h.eq("and nothing moved", _ids(InterestGrid.row_order(row, {})), _ids(row))

func test_what_you_know_sorts_to_the_front_by_rank() -> void:
	## The "arrange themselves in priority order if you know" half. Cells you
	## have learned come first, best first; everything else holds its place
	## behind them so the row never reshuffles under you for no reason.
	var pool := _pool()
	var row := pool.in_category(pool.categories[0])
	var last: Interest = row[row.size() - 1]
	var first: Interest = row[0]
	var known := {last.id: 2, first.id: 7}
	var got := _ids(InterestGrid.row_order(row, known))
	h.eq("the better-ranked known cell leads", got[0], last.id)
	h.eq("then the worse-ranked one", got[1], first.id)
	h.eq("and the row is still the same cells", got.size(), row.size())
	for i in row:
		h.check("%s is still in it" % i.id, got.has(i.id))

func test_every_category_is_a_full_row() -> void:
	## One row per category, and the grid draws a fixed box - so a category
	## with a different number of interests would silently leave a gap or
	## overflow the card.
	var pool := _pool()
	h.eq("three categories", pool.categories.size(), 3)
	for c in pool.categories:
		h.eq("%s holds three interests" % c.id, pool.in_category(c).size(), 3)

# ------------------------------------------------------------ the telegraph
func test_a_customer_asking_for_nothing_telegraphs_nothing() -> void:
	var s := _shift([&"easygoing"])
	h.eq("no demand, no line", CustomerCard3D.demand_text(s.chairs[0], s.tick), "")

func test_the_telegraph_shouts_the_ask_and_counts_down() -> void:
	var s := _shift([&"easygoing"])
	var c: Customer = s.chairs[0]
	c.ticks_on_floor = s.cfg.demand_grace_ticks
	var d := Demand.new()
	d.telegraph = "MANAGER?"
	d.ticks = 3
	d.resolve = PlayConcession.new()
	s.raise_demand(c, d)
	var said := CustomerCard3D.demand_text(c, s.tick)
	h.check("it shouts the ask (%s)" % said, said.contains("MANAGER?"))
	h.check("and says how long you have (%s)" % said, said.contains("3t"))
	s._burn(2, "cards")
	var later := CustomerCard3D.demand_text(c, s.tick)
	h.check("the fuse visibly burns down (%s)" % later, later.contains("1t"))

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

# ----------------------------------------------------------------- what is taken
func test_the_grid_lights_what_they_have_actually_bought() -> void:
	var s := _shift([&"easygoing"])
	var c: Customer = s.chairs[0]
	h.check("nothing lit to begin with",
		CustomerCard3D.sold_interests(c).is_empty())
	c.unsigned.append({"product": s.card_pool.by_id(&"vsc"),
		"margin": 1600, "bonus": 0})
	var lit := CustomerCard3D.sold_interests(c)
	h.check("the interest the product answers is lit, not the product",
		lit.has(&"reliability"))
	h.eq("and only that one", lit.size(), 1)

func test_a_customer_carries_the_board_they_were_dealt_against() -> void:
	## The grid needs the nine interests to lay out. Which nine exist was never
	## hidden - the RANKS are the hidden information, and they stay behind
	## known_ranks where they have always been.
	var s := _shift([&"easygoing"])
	var c: Customer = s.chairs[0]
	h.check("they can name the board", c.interests() != null)
	h.eq("all nine of it", c.interests().count(), 9)
	h.check("without giving away a single rank", c.known_ranks.is_empty())
