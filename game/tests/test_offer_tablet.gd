extends RefCounted
## OfferTablet: the tablet a product stands on while you pitch it. Its shape
## and layout are constants the table's geometry leans on, and what its screen
## says is plain data on its labels and meter - so both are checkable without
## ever rendering it. Whether it LOOKS like a tablet is for eyes.
var h: Harness

const SCENE := "res://scenes/offer_tablet.tscn"
const CFG := {"appeal_step": 5, "line_per_sale": 3, "leaving_soon_at": 4}
const CARD := Vector2(2.5, 3.5)          ## the Card3D plane, from card_3d.tscn

func _instance() -> OfferTablet:
	return (load(SCENE) as PackedScene).instantiate() as OfferTablet

func _meter_scale() -> int:
	return (load("res://data/shift_config.tres") as ShiftConfig).appeal_meter_scale

func _interests() -> InterestPool:
	return load("res://data/interests/interest_pool.tres")

func _pool() -> CardPool:
	return load("res://data/card_pool.tres")

func _cust(id: StringName, seed_value: int) -> Customer:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var a := (load("res://data/archetype_pool.tres") as ArchetypePool).by_id(id)
	var ranks := Customer.make_ranks(a, _interests(), rng, 0.0)
	return Customer.new("A", "Test Person", a, ranks, a.patience, a.patience,
		CFG, _interests())

func _offer(product_id: StringName, appeal: int, margin: int, uid: int = 1) -> Offer:
	return Offer.new(CardInstance.new(_pool().by_id(product_id), uid), appeal, margin)

# ------------------------------------------------------------------ the shape
func test_the_screen_is_drawn_at_the_tablets_own_shape() -> void:
	var t := _instance()
	var vp := t.get_node(^"ScreenViewport") as SubViewport
	h.eq("the screen is drawn at the tablet's pixels", vp.size, OfferTablet.SIZE_PX)
	h.check("with see-through corners, so the edge can be rounded", vp.transparent_bg)
	var quad := (t.get_node(^"Face") as MeshInstance3D).mesh as QuadMesh
	h.eq("on a quad the tablet's size", quad.size, OfferTablet.SIZE)
	h.check("which is the same shape as the screen, so nothing stretches",
		is_equal_approx(quad.size.x / quad.size.y,
			float(OfferTablet.SIZE_PX.x) / OfferTablet.SIZE_PX.y))
	t.free()

func test_the_product_stands_in_the_middle_of_the_screen() -> void:
	## "The product card shows up in the center." The well is exactly one card
	## at the screen's own resolution, so the real card standing in front of it
	## covers it edge to edge.
	var well := OfferTablet.WELL_RECT
	h.check("the well is exactly one card (%s)" % OfferTablet.size_of(well),
		OfferTablet.size_of(well).is_equal_approx(CARD))
	h.check("centred on the tablet (%s)" % OfferTablet.centre_of(well),
		OfferTablet.centre_of(well).is_equal_approx(Vector3.ZERO))
	h.check("and taller than nothing but the black edge around it",
		OfferTablet.SIZE.y > CARD.y)

func test_what_it_says_sits_either_side_of_the_product_on_the_screen() -> void:
	var well := OfferTablet.WELL_RECT
	var b := OfferTablet.BEZEL_PX
	var screen := Rect2i(b, b, OfferTablet.SIZE_PX.x - b * 2, OfferTablet.SIZE_PX.y - b * 2)
	h.check("appeal on the left of the product", OfferTablet.APPEAL_RECT.end.x < well.position.x)
	h.check("the money on the right of it", OfferTablet.DEAL_RECT.position.x > well.end.x)
	for pair in [["appeal", OfferTablet.APPEAL_RECT], ["deal", OfferTablet.DEAL_RECT],
			["well", well]]:
		h.check("the %s panel is on the screen, inside the black edge" % pair[0],
			screen.encloses(pair[1]))
	h.eq("and the two sides are the same width",
		OfferTablet.APPEAL_RECT.size.x, OfferTablet.DEAL_RECT.size.x)

func test_nothing_on_it_can_take_a_click() -> void:
	## The product card standing on the screen, and the slot's own
	## double-click-to-close pad, must keep every pointer aimed at them.
	var t := _instance()
	h.check("no collider anywhere on the tablet", _find_collider(t) == null)
	t.free()

func test_it_only_draws_while_it_is_on() -> void:
	var t := _instance()
	var vp := t.get_node(^"ScreenViewport") as SubViewport
	t.switch_on(false)
	h.check("off, it is out of sight", not t.visible and not t.is_on())
	h.eq("and its screen stops redrawing", vp.render_target_update_mode,
		SubViewport.UPDATE_DISABLED)
	t.switch_on(true)
	h.check("on, it is showing", t.visible and t.is_on())
	h.eq("and its screen redraws every frame, as every card face does",
		vp.render_target_update_mode, SubViewport.UPDATE_ALWAYS)
	t.free()

# ------------------------------------------------------------------ the meter
func test_the_meter_stands_upright_beside_the_product() -> void:
	## "Let's try making the appeal meter vertical so it can be a little
	## larger." It stands at the inside edge of the appeal panel - the edge
	## nearest the product - and takes the panel's whole height, where lying
	## across the panel it was capped at the panel's width.
	var t := _instance()
	var bar := t.get_node(^"ScreenViewport/TabletScreen/AppealPanel/Row/AppealBar") as AppealBar
	h.check("the meter is where the tablet reads it from", bar != null)
	if bar == null:
		t.free()
		return
	var row := bar.get_parent()
	h.check("the meter shares a row with the panel's words, not a column",
		row is HBoxContainer)
	h.eq("and is the last thing in it, up against the product",
		bar.get_index(), row.get_child_count() - 1)
	h.eq("as wide as the tablet says (%s)" % bar.custom_minimum_size,
		bar.custom_minimum_size, Vector2(OfferTablet.METER_WIDTH, 0))
	h.check("and left to fill the row's height, not given one of its own",
		bar.size_flags_vertical & Control.SIZE_FILL != 0)
	# The panel's content is its rect less the style's padding - the height the
	# row hands the meter. It used to be a 64-px bar across a 329-px panel.
	var style := (row.get_parent() as PanelContainer).get_theme_stylebox("panel")
	var tall: float = OfferTablet.APPEAL_RECT.size.y \
		- style.get_margin(SIDE_TOP) - style.get_margin(SIDE_BOTTOM)
	var across: float = OfferTablet.APPEAL_RECT.size.x \
		- style.get_margin(SIDE_LEFT) - style.get_margin(SIDE_RIGHT)
	h.check("so it is longer standing (%d px) than it could ever be lying down (%d px)"
		% [int(tall), int(across)], tall > across)
	t.free()

func test_the_meter_fills_up_from_the_bottom_and_marks_the_line_across_it() -> void:
	var bar := AppealBar.new()
	var track := Rect2(4, 4, 88, 400)
	bar.set_state(20, 40, 80, "COOL", false)
	var fill := bar.fill_rect(track)
	h.eq("the fill stands on the bottom of the track", fill.end.y, track.end.y)
	h.eq("the full width of it", fill.size.x, track.size.x)
	h.eq("and as tall as the appeal's share of the scale", fill.size.y, 100.0)
	h.eq("no marker while the Line is a guess", bar.marker_y(track), -1.0)
	bar.set_state(20, 40, 80, "COOL", true)
	h.eq("once known, the Line sits halfway up a bar scaled to twice it",
		bar.marker_y(track), track.end.y - 200.0)
	bar.set_state(200, 400, 80, "COLD", true)
	h.eq("past the ceiling the fill is simply full", bar.fill_rect(track).size.y,
		track.size.y)
	h.eq("and the marker pinned at the top, not off the end", bar.marker_y(track),
		track.position.y)
	bar.free()

func test_the_meter_fills_with_your_appeal_on_the_models_fixed_scale() -> void:
	var t := _instance()
	var scale := _meter_scale()
	var c := _cust(&"easygoing", 1)
	c.line = 20
	c.offer = _offer(&"vsc", 5, 1600)
	t.show_offer(c, "COLD", scale)
	h.check("the meter is showing", t._bar.visible)
	h.eq("filled with this offer's appeal", t._bar._appeal, 5)
	h.eq("low appeal, low Line: the configured scale", t._bar._scale, scale)

	## It used to grow to fit whatever the negotiation needed, so the bar's own
	## endpoint was a different number on every customer. It is one number now.
	c.offer.appeal = scale * 3          # deliberately far past the ceiling
	c.line = scale * 2
	t.show_offer(c, "WARM", scale)
	h.eq("appeal and Line both past the ceiling: still the same scale",
		t._bar._scale, scale)

	c.offer = _offer(&"gap", 15, 1400, 2)   # a different Offer, same customer
	t.show_offer(c, "COLD", scale)
	h.eq("a different offer, same fixed scale", t._bar._scale, scale)
	t.free()

func test_the_line_marker_waits_until_you_have_earned_the_line() -> void:
	var t := _instance()
	var c := _cust(&"easygoing", 1)
	c.line = 40
	c.offer = _offer(&"vsc", 30, 1600)
	t.show_offer(c, "COOL", _meter_scale())
	h.check("no marker while their Line is a guess", not t._bar._line_known)
	c.reveal_room()
	t.show_offer(c, "COOL", _meter_scale())
	h.check("one once you have read the room", t._bar._line_known)
	h.eq("at the Line the model holds", t._bar._line, c.line)
	t.free()

func test_the_status_is_a_band_until_you_know_the_line_and_a_number_after() -> void:
	var t := _instance()
	var c := _cust(&"easygoing", 1)
	c.line = 40
	c.offer = _offer(&"vsc", 30, 1600)
	t.show_offer(c, "COOL", _meter_scale())
	h.eq("before you offer, no verdict at all", t._status.text, "")
	## "Remove the Read the Room hint on the product detail box since it's
	## specific to a single card" - with their Line unknown the panel says
	## nothing at all, rather than advertising one card on every pitch.
	h.check("and no nudge toward any one card (%s)" % t._hint.text,
		not t._hint.visible and t._hint.text == "")
	c.known_line = true
	t.show_offer(c, "COOL", _meter_scale())
	h.check("a Line you can already see still gets its nudge (%s)" % t._hint.text,
		t._hint.visible and t._hint.text.contains("Line is marked"))
	c.known_line = false

	c.offer.revealed = true
	t.show_offer(c, "WARM", _meter_scale())
	h.eq("offered, but the Line unknown: a feeling, not a number", t._status.text, "WARM")

	c.reveal_room()
	t.show_offer(c, "WARM", _meter_scale())
	h.eq("knowing the Line turns it into the gap", t._status.text, "10 SHORT")
	c.offer.appeal = 40
	t.show_offer(c, "WARM", _meter_scale())
	h.eq("and at the Line, a yes", t._status.text, "READY TO SIGN")
	h.eq("in green", t._status.get_theme_color("font_color"), Palette.color(&"patience_ok"))
	t.free()

# ------------------------------------------------------------------ the money
func test_the_margin_is_the_offers_own() -> void:
	## The offer's, not the card's: a discount played on the table lowers the
	## offer's margin while the card keeps its printed one.
	var t := _instance()
	var c := _cust(&"easygoing", 1)
	c.offer = _offer(&"vsc", 30, 1250)
	t.show_offer(c, "COOL", _meter_scale())
	h.eq("the offer's margin", t._margin.text, Format.money(1250))
	t.free()

func test_before_any_sale_there_is_no_combo_yet_and_it_says_how_one_builds() -> void:
	var t := _instance()
	var c := _cust(&"karen", 1)
	c.offer = _offer(&"vsc", 30, 1600)
	t.show_offer(c, "COOL", _meter_scale())
	h.eq("nothing sold yet: no combo", t._combo.text, "×1.00")
	h.eq("in the quiet ink", t._combo.get_theme_color("font_color"),
		Palette.color(&"text_dim"))
	h.eq("and what each sale does, from their archetype's own knobs",
		t._knobs.text, OfferTablet.knobs_text(c))
	h.check("which names both knobs (%s)" % t._knobs.text,
		t._knobs.text.contains("+%d%%" % roundi(c.archetype.combo_step * 100))
			and t._knobs.text.contains("Line +%d" % c.archetype.line_per_sale))
	h.check("and no bigger number to promise", not t._worth.visible)
	t.free()

func test_after_a_sale_it_shows_the_combo_and_what_this_offer_books() -> void:
	var t := _instance()
	var c := _cust(&"karen", 1)
	c.combo_step = 0.5
	c.sales = 2   # two products already taken this visit
	c.offer = _offer(&"vsc", 30, 1601)
	t.show_offer(c, "COOL", _meter_scale())
	var mult := 1.0 + c.combo_step * c.sales
	h.eq("the multiplier THIS offer would sell at", t._combo.text, "×%.2f" % mult)
	h.eq("lit up, now that there is one", t._combo.get_theme_color("font_color"),
		Palette.color(&"accent"))
	h.check("with what that books", t._worth.visible)
	h.eq("rounded exactly the way a sale rounds it", t._worth.text,
		"%s if they buy" % Format.money(roundi(1601 * mult)))
	t.free()

func test_an_empty_table_still_shows_their_combo() -> void:
	## The combo is the CUSTOMER's, so it stands with nothing on the table.
	var t := _instance()
	var c := _cust(&"karen", 1)
	c.sales = 1
	t.show_offer(c, "", _meter_scale())           # c.offer is null
	h.check("no meter with nothing to meter", not t._bar.visible)
	h.eq("no margin with nothing to sell", t._margin.text, "-")
	h.check("just what to do about it", t._hint.visible
		and t._hint.text.contains("Place a product"))
	h.eq("but their combo is still theirs",
		t._combo.text, "×%.2f" % (1.0 + c.combo_step * c.sales))
	h.check("and nothing booked", not t._worth.visible)
	t.free()

func test_an_empty_chair_says_nobody_is_there() -> void:
	var t := _instance()
	t.show_offer(null, "", _meter_scale())
	h.check("says so", t._hint.text.contains("Nobody"))
	h.eq("no combo from nobody", t._combo.text, "×1.00")
	h.eq("and no knobs to read", t._knobs.text, "")
	t.free()

func _find_collider(node: Node) -> Node:
	for child in node.get_children():
		if child is CollisionObject3D:
			return child
		var found := _find_collider(child)
		if found != null:
			return found
	return null
