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

# ---------------------------------------------------------- the cell's name
func test_the_cell_names_shrink_only_as_far_as_they_have_to() -> void:
	## "Add the interest name to the bottom of the little blocks" - and the
	## widest of those names ("Value Retention") does not fit the cell at
	## NAME_FONT_MAX, so _fit_font_size() has to actually shrink it rather
	## than overflow into the neighbouring cell.
	var font := ThemeDB.fallback_font
	var wide := font.get_string_size("Value Retention",
		HORIZONTAL_ALIGNMENT_LEFT, -1, InterestGrid.NAME_FONT_MAX).x
	var got: int = InterestGrid._fit_font_size(font, "Value Retention", wide - 1.0,
		InterestGrid.NAME_FONT_MAX, InterestGrid.NAME_FONT_MIN)
	h.check("shrinks when the max size does not fit (%d)" % got,
		got < InterestGrid.NAME_FONT_MAX)
	h.check("but never below the floor", got >= InterestGrid.NAME_FONT_MIN)

	var roomy: int = InterestGrid._fit_font_size(font, "Power", 9999.0,
		InterestGrid.NAME_FONT_MAX, InterestGrid.NAME_FONT_MIN)
	h.eq("and does not shrink a name that already fits",
		roomy, InterestGrid.NAME_FONT_MAX)

func test_every_real_interest_has_a_name_short_enough_to_ever_fit() -> void:
	## The floor itself has to be reachable - a name that is STILL too wide at
	## NAME_FONT_MIN would silently overflow forever, and nothing else in the
	## pipeline would ever catch that.
	var font := ThemeDB.fallback_font
	for i in _pool().interests:
		var w := font.get_string_size(i.display_name, HORIZONTAL_ALIGNMENT_LEFT,
			-1, InterestGrid.NAME_FONT_MIN).x
		h.check("%s fits some cell width at the floor size (%.1f px)"
			% [i.display_name, w], w > 0.0 and w < 500.0)

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


# ------------------------------------------------------------- category icons
## CategoryIcon.draw() itself only works inside a live _draw() - see this
## file's own header - but the SHAPES it draws are pure functions precisely so
## a headless test can still check that "car", "tag" and "person" are actually
## three different things, and that none of them draws outside the box it was
## given (a card_front row is only 44px tall; a point that drifts out of rect
## would clip against its neighbour rather than just look ugly).

const CATEGORIES: Array[StringName] = [&"vehicle", &"deal", &"person"]

func _inside(points: PackedVector2Array, rect: Rect2) -> bool:
	for p in points:
		if not rect.has_point(p):
			return false
	return true

func test_every_glyph_stays_inside_the_rect_it_was_given() -> void:
	var rect := Rect2(Vector2(4, 4), Vector2(40, 40))    # an off-origin box,
	# deliberately not (0,0), so a glyph that forgot to add rect.position would
	# still pass a check anchored at the origin and fail everywhere real.
	h.check("the car body", _inside(CategoryIcon.car_body(rect), rect))
	h.check("the car's wheel centres", _inside(CategoryIcon.car_wheels(rect), rect))
	h.check("the tag", _inside(CategoryIcon.tag(rect), rect))
	h.check("the person's shoulders", _inside(CategoryIcon.person_body(rect), rect))
	var head := CategoryIcon.person_head_center(rect)
	h.check("and the person's head centre", rect.has_point(head))

func test_the_wheels_sit_below_the_cars_own_body() -> void:
	## The overlap IS the design - see car_wheels()'s own comment - but "below"
	## is what makes it read as a car sitting on wheels rather than floating
	## above them.
	var rect := Rect2(Vector2.ZERO, Vector2(40, 40))
	var body := CategoryIcon.car_body(rect)
	var lowest_body := 0.0
	for p in body:
		lowest_body = maxf(lowest_body, p.y)
	for wheel in CategoryIcon.car_wheels(rect):
		h.check("wheel at y=%.1f sits at or below the body's own lowest point (%.1f)"
			% [wheel.y, lowest_body], wheel.y >= lowest_body - 0.01)

func test_the_head_sits_above_the_shoulders() -> void:
	var rect := Rect2(Vector2.ZERO, Vector2(40, 40))
	var head_y := CategoryIcon.person_head_center(rect).y
	var shoulders := CategoryIcon.person_body(rect)
	var highest_shoulder := 999999.0
	for p in shoulders:
		highest_shoulder = minf(highest_shoulder, p.y)
	h.check("head (%.1f) is above the shoulders' own topmost point (%.1f)"
		% [head_y, highest_shoulder], head_y < highest_shoulder)

func test_the_three_glyphs_are_not_secretly_the_same_shape() -> void:
	## The whole point of adding icons was to tell three categories apart at a
	## glance - three functions that all happened to return the same points
	## would defeat that just as completely as never drawing anything.
	var rect := Rect2(Vector2.ZERO, Vector2(40, 40))
	var shapes := [CategoryIcon.car_body(rect), CategoryIcon.tag(rect),
		CategoryIcon.person_body(rect)]
	for a in range(shapes.size()):
		for b in range(a + 1, shapes.size()):
			h.check("shape %d and shape %d are not the same polygon" % [a, b],
				shapes[a] != shapes[b])

func test_every_real_category_has_a_matching_glyph() -> void:
	## If a fourth category ever ships with no matching case in
	## CategoryIcon.draw(), its row and every card badge for it go quietly
	## blank rather than obviously broken - draw() fails silently by design (see
	## its own doc comment) precisely because a badge is not worth a crash, which
	## is exactly why this has to be checked some OTHER way. Checked against the
	## real pool data, not a second hardcoded guess at what the categories are.
	var have: Array = []
	for cat in _pool().categories:
		have.append(cat.id)
	have.sort()
	var want: Array = CATEGORIES.duplicate()
	want.sort()
	h.eq("every real category has a matching glyph", have, want)
