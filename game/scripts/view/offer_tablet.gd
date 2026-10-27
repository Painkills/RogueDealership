class_name OfferTablet extends Node3D
## The tablet on the desk you are sitting at. The product you are pitching
## stands on its screen, and the screen shows how that pitch is landing on
## either side of it: appeal on the left, the money on the right.
##
## The appeal side is only as wide as its meter, so the product is not quite in
## the middle of the tablet - the tablet is placed so the product still stands
## where the desk's slot is (see well_offset()).
##
## It replaced a second card that slid out beside the product - a sheet that
## repeated the product's name and category in smaller type beside a card that
## already said both, and was cramped for everything else. The tablet carries
## only what the product card itself cannot: how it is landing with THIS
## customer, and what it is worth to you if they buy.
##
## Scenery, like the desk it stands on. Nothing here collides, so the product
## card standing on the screen keeps every click, and so does the slot's own
## double-click-to-close pad.

## The screen's pixels per world unit. The seat camera draws about 102 design
## pixels to a unit, so the screen is drawn at nearly twice the size it lands
## at and minified - the same trick every card face uses.
const PX_PER_UNIT := 180.0
## The whole tablet, black edge and all. The edge and its rounded corners are
## drawn into the same texture and the corners cut out of the quad, so it has
## the corners a tablet has without a second mesh.
const SIZE_PX := Vector2i(1109, 688)
## ...and in the world: 6.16 x 3.82, standing on the desk.
const SIZE := Vector2(1109.0 / PX_PER_UNIT, 688.0 / PX_PER_UNIT)
## The black glass edge, in pixels.
const BEZEL_PX := 18
## The well the product card stands in front of: exactly one 2.5 x 3.5 card,
## as tall as the screen, so the card stands ON the screen rather than being
## laid across it.
const WELL_RECT := Rect2i(224, 29, 450, 630)
## The status bar along the top of the screen, as on any tablet: the time on
## the left, signal and battery on the right. The product stands over its
## middle, the way an app's content sits under one.
const STATUS_RECT := Rect2i(40, 24, 1029, 30)
## Either side of the well, under the status bar. The appeal meter is the thing
## you are steering by, so it gets the side your eye reaches first - a thin
## panel, "appeal" at its top and the meter from just under that to its foot.
const APPEAL_RECT := Rect2i(32, 64, 170, 595)
const DEAL_RECT := Rect2i(696, 64, 381, 595)
## The appeal meter's width: the whole of its panel, less the panel's padding.
const METER_WIDTH := 124

var _material := StandardMaterial3D.new()
var _bound := false
var _viewport: SubViewport
var _bar: AppealBar
var _status: Label
var _title: Label
var _margin: Label
var _combo: Label
var _worth: Label
var _knobs: Label
var _budget: Label
var _clock: Label
var _note: Control
var _note_close: Control

func _ready() -> void:
	_bind()

## Text can be written from instantiate() on; the texture is attached once, the
## first time anything asks.
func _bind() -> void:
	if _bound:
		return
	_bound = true
	_viewport = $ScreenViewport
	var screen: Node = $ScreenViewport/TabletScreen
	_bar = screen.get_node(^"AppealPanel/Column/AppealBar") as AppealBar
	_status = screen.get_node(^"AppealPanel/Column/StatusLabel")
	_title = screen.get_node(^"AppealPanel/Column/AppealTitle")
	_margin = screen.get_node(^"DealPanel/Column/MarginLabel")
	_combo = screen.get_node(^"DealPanel/Column/ComboLabel")
	_worth = screen.get_node(^"DealPanel/Column/WorthLabel")
	_knobs = screen.get_node(^"DealPanel/Column/KnobsIndent/KnobsLabel")
	_budget = screen.get_node(^"DealPanel/Column/BudgetLabel")
	_clock = screen.get_node(^"StatusBar/ClockLabel")
	_note = screen.get_node(^"WellNote")
	_note_close = screen.get_node(^"WellNote/CloseRow")

	_viewport.size = SIZE_PX
	_viewport.disable_3d = true
	# The corners outside the rounded edge are see-through, and the quad cuts
	# them out rather than blending them - a cut edge never sorts wrongly
	# against the card standing in front of it.
	_viewport.transparent_bg = true
	_material.albedo_texture = _viewport.get_texture()
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	_material.alpha_scissor_threshold = 0.5
	# A screen gives off its own light rather than reflecting the room's.
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	($Face as MeshInstance3D).material_override = _material
	switch_on(visible)

## On at the desk you are sitting at and gone everywhere else - the tablet is
## where you play a product, and you only play at the desk you are at. Off, it
## stops redrawing too: three screens nobody can see are three screens'
## worth of work every frame for nothing.
func switch_on(on: bool) -> void:
	_bind()
	visible = on
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on \
		else SubViewport.UPDATE_DISABLED

func is_on() -> bool:
	return visible

## The time in the status bar - the shift's own clock, which ShiftHours turns
## from ticks into the time of day the shift is being worked at.
func show_clock(text: String) -> void:
	_bind()
	_clock.text = text

func clock_text() -> String:
	_bind()
	return _clock.text

## The empty well's note - "nothing on the table, place a product here" - and,
## with `can_close`, its "or double-click to close the deal" half.
func show_note(empty: bool, can_close: bool) -> void:
	_bind()
	_note.visible = empty
	_note_close.visible = empty and can_close

func note_showing() -> bool:
	_bind()
	return _note.visible

func note_offers_close() -> bool:
	_bind()
	return _note_close.visible

## The note's own text, for checks: every line of it that is showing.
func note_text() -> String:
	_bind()
	var lines: Array[String] = []
	for l in _note.find_children("*", "Label", true, false):
		if (l as Label).is_visible_in_tree():
			lines.append((l as Label).text.replace("\n", " "))
	return " / ".join(lines)

## Where the note sits on the screen, in the screen's own pixels.
func note_px() -> Rect2:
	_bind()
	return _note.get_global_rect()

## The product in front of `c` and how it is landing. `band` comes from the
## model's own Shift.band_for(), so the colour thresholds are never re-derived
## here, and `meter_scale` from ShiftConfig.appeal_meter_scale - a fixed
## ceiling, the same for every customer and every offer, so the bar never
## resizes itself out from under the fill.
func show_offer(c, band: String, meter_scale: int, blocked_ticks: int = 0) -> void:
	_bind()
	# A debuff that stops your cards adding appeal says so over the meter.
	_title.text = "NO APPEAL" if blocked_ticks > 0 else "APPEAL"
	_title.add_theme_color_override("font_color",
		Palette.color(&"alert") if blocked_ticks > 0 else Palette.color(&"text_dim"))
	# The combo belongs to the CUSTOMER, not the product - it stands whether or
	# not anything is on the table yet, so it is shown either way. c.sales is
	# how many they have ALREADY taken this visit, the same prior-sales count
	# Shift._settle() multiplies by, so this is a preview of the real number.
	var mult: float = c.combo_multiplier() if c != null else 1.0
	_combo.text = Format.multiplier(mult)
	_combo.add_theme_color_override("font_color",
		Palette.color(&"accent") if mult > 1.0 else Palette.color(&"text_dim"))
	_knobs.text = knobs_text(c) if c != null else ""
	_budget.text = budget_text(c) if c != null else ""
	_budget.visible = _budget.text != ""

	var o = c.offer if c != null else null
	# And on top of the combo, whatever they pay over the odds for a product
	# they prize (CustomerArchetype.premium_interests).
	var prized: float = c.margin_scale_for(o.product) if o != null else 1.0
	_worth.visible = o != null and (mult > 1.0 or prized != 1.0)
	_status.text = ""
	if o == null:
		# An empty meter, not no meter: the panel says what it measures before
		# there is anything on the table to measure - and a Line you have found
		# out stays on it, product or not: knowing where they stand is worth
		# most when you are choosing what to put down.
		var known: bool = c != null and c.known_line
		_bar.set_state(0, c.line if known else 0, meter_scale, "", known)
		_margin.text = "-"
	else:
		_bar.set_state(o.appeal, c.line, meter_scale, band, c.known_line)
		_margin.text = Format.money(o.margin)
		# What this offer books if they say yes, combo and all - rounded exactly
		# the way _settle() rounds it, so the tablet never promises a dollar the
		# sale will not pay.
		var combo := roundi(o.margin * mult)
		_worth.text = "%s if they buy" % Format.money(combo + roundi(combo * (prized - 1.0)))
		_read_the_offer(c, o, band)

## The combo's flash, while it plays - see flash_combo().
var _flash: Tween = null

## Whether the combo is flashing right now.
func combo_flashing() -> bool:
	return _flash != null and _flash.is_valid() and _flash.is_running()

## Where the MARGIN number sits, in the screen's own pixels - a sale's number
## lifts off from here.
func margin_px() -> Rect2:
	_bind()
	return _margin.get_global_rect()

## Where one of the tablet's numbers sits, in its screen's own pixels: &"margin",
## &"combo", &"appeal" (the meter's panel) or &"well" (where the product stands, and the
## cards you play land) - for a popup to go where the number it is about is.
func spot_px(which: StringName) -> Rect2:
	_bind()
	match which:
		&"margin": return _margin.get_global_rect()
		&"combo": return _combo.get_global_rect()
		&"appeal": return Rect2(APPEAL_RECT)   # the meter's panel, APPEAL over it
		&"bar":
			# The meter itself - its panel when it has not been laid out yet.
			var r := _bar.get_global_rect()
			return r if r.size.x > 0.0 and r.size.y > 0.0 else Rect2(APPEAL_RECT)
		&"well": return Rect2(WELL_RECT)
	return Rect2()

## What heads the meter: APPEAL, or NO APPEAL under a debuff.
func title_text() -> String:
	_bind()
	return _title.text

## Hides (or shows) the MARGIN figure itself, while a popup rolls over it and
## stands in for it.
func cover_margin(on: bool) -> void:
	_bind()
	_margin.modulate.a = 0.0 if on else 1.0

func margin_covered() -> bool:
	_bind()
	return _margin.modulate.a < 0.5

## The type size the MARGIN number is drawn at, in the screen's own pixels.
func margin_font_px() -> int:
	_bind()
	return _margin.get_theme_font_size("font_size")

## The combo on the screen pops and flashes - a sale just went through, and the
## multiplier the next one gets is what it now shows.
func flash_combo() -> void:
	_bind()
	_combo.pivot_offset = _combo.size * 0.5
	var tw := create_tween()
	_flash = tw
	tw.tween_property(_combo, "scale", Vector2(1.6, 1.6), 0.12) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for _k in range(2):
		tw.tween_property(_combo, "modulate", Color(1.8, 1.8, 1.8, 1.0), 0.08)
		tw.tween_property(_combo, "modulate", Color.WHITE, 0.1)
	tw.tween_property(_combo, "scale", Vector2.ONE, 0.35)

## The verdict under the meter: nothing yet, a band, or the exact gap.
##
## The FILL is always honest about your own appeal; only the LINE is fogged, and
## Read the Room is the ONLY thing that lifts it.
##
## From the moment you place, it names the band in the meter's own colour -
## INTERESTED once you are over their Line, then ALMOST, WARM, COOL, COLD - so
## a player who has not read the room still knows roughly how far there is to
## go. INTERESTED is the one that matters: it is when you can make the offer, and
## you cannot before it. The exact number stays Read the Room's.
func _read_the_offer(c, o, band: String) -> void:
	if not c.known_line:
		_status.text = band
		_status.add_theme_color_override("font_color", _bar.fill_color())
		return

	var gap: int = c.line - o.appeal
	if gap <= 0:
		_status.text = "READY TO SIGN"
		_status.add_theme_color_override("font_color", Palette.color(&"patience_ok"))
	else:
		_status.text = "%d SHORT" % gap
		_status.add_theme_color_override("font_color", _bar.fill_color())

## The two per-archetype combo knobs, read straight off their own data so this
## text can never drift from what Shift._settle() actually does with them.
## Under the tablet's ON EACH SALE heading, one to a line.
static func knobs_text(c) -> String:
	return "Combo +%d%%\nLine +%d" % [roundi(c.combo_step * 100), c.archetype.line_per_sale]

## Someone on a budget: what they have left to spend - the fight's health bar.
## Empty for everyone else.
static func budget_text(c) -> String:
	return "Budget left: %s" % Format.money(c.budget_left()) if c.has_budget() else ""

## Where the product stands on this tablet, from the tablet's own middle - the
## desk places the tablet this far off its slot, the other way, so the product
## stands in the well.
static func well_offset() -> Vector3:
	return centre_of(WELL_RECT)

## Where a rect of the screen sits in the tablet's own space: its centre...
static func centre_of(px: Rect2i) -> Vector3:
	var c := Vector2(px.position) + Vector2(px.size) * 0.5
	return Vector3((c.x - SIZE_PX.x * 0.5) / PX_PER_UNIT,
		(SIZE_PX.y * 0.5 - c.y) / PX_PER_UNIT, 0.0)

## ...and its size in world units.
static func size_of(px: Rect2i) -> Vector2:
	return Vector2(px.size) / PX_PER_UNIT
