class_name OfferTablet extends Node3D
## The tablet on the desk you are sitting at. The product you are pitching
## stands in the middle of its screen, and the screen shows how that pitch is
## landing on either side of it: appeal on the left, the money on the right.
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
const SIZE_PX := Vector2i(1320, 688)
## ...and in the world: 7.33 x 3.82, standing on the desk.
const SIZE := Vector2(1320.0 / PX_PER_UNIT, 688.0 / PX_PER_UNIT)
## The black glass edge, in pixels.
const BEZEL_PX := 18
## The well in the middle of the screen that the product card stands in front
## of: exactly one 2.5 x 3.5 card, centred, so the card is the middle of the
## screen rather than something laid across it.
const WELL_RECT := Rect2i(435, 29, 450, 630)
## Either side of the well. The appeal meter is the thing you are steering by,
## so it gets the side your eye reaches first.
const APPEAL_RECT := Rect2i(32, 29, 381, 630)
const DEAL_RECT := Rect2i(907, 29, 381, 630)

var _material := StandardMaterial3D.new()
var _bound := false
var _viewport: SubViewport
var _bar: AppealBar
var _status: Label
var _hint: Label
var _margin: Label
var _combo: Label
var _worth: Label
var _knobs: Label

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
	_hint = screen.get_node(^"AppealPanel/Column/HintLabel")
	_margin = screen.get_node(^"DealPanel/Column/MarginLabel")
	_combo = screen.get_node(^"DealPanel/Column/ComboLabel")
	_worth = screen.get_node(^"DealPanel/Column/WorthLabel")
	_knobs = screen.get_node(^"DealPanel/Column/KnobsLabel")

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

## The product in front of `c` and how it is landing. `band` comes from the
## model's own Shift.band_for(), so the colour thresholds are never re-derived
## here, and `meter_scale` from ShiftConfig.appeal_meter_scale - a fixed
## ceiling, the same for every customer and every offer, so the bar never
## resizes itself out from under the fill.
func show_offer(c, band: String, meter_scale: int) -> void:
	_bind()
	# The combo belongs to the CUSTOMER, not the product - it stands whether or
	# not anything is on the table yet, so it is shown either way. c.sales is
	# how many they have ALREADY taken this visit, the same prior-sales count
	# Shift._settle() multiplies by, so this is a preview of the real number.
	var mult: float = 1.0 + c.combo_step * c.sales if c != null else 1.0
	_combo.text = "×%.2f" % mult
	_combo.add_theme_color_override("font_color",
		Palette.color(&"accent") if mult > 1.0 else Palette.color(&"text_dim"))
	_knobs.text = knobs_text(c) if c != null else ""

	var o = c.offer if c != null else null
	_bar.visible = o != null
	_worth.visible = o != null and mult > 1.0
	if o == null:
		_margin.text = "-"
		_status.text = ""
		_hint.text = "Place a product to see its appeal" if c != null \
			else "Nobody in this chair"
	else:
		_bar.set_state(o.appeal, c.line, meter_scale, band, c.known_line)
		_margin.text = Format.money(o.margin)
		# What this offer books if they say yes, combo and all - rounded exactly
		# the way _settle() rounds it, so the tablet never promises a dollar the
		# sale will not pay.
		_worth.text = "%s if they buy" % Format.money(roundi(o.margin * mult))
		_read_the_offer(c, o, band)
	# A verdict or a nudge, never an empty line holding the space open.
	_status.visible = not _status.text.is_empty()
	_hint.visible = not _hint.text.is_empty()

## The verdict under the meter: nothing yet, a band, or the exact gap.
##
## The FILL is always honest about your own appeal; only the LINE is fogged, and
## Read the Room is the ONLY thing that lifts it. Offering used to lift it too,
## which quietly made the card optional: ask once, anywhere, and the exact
## number was yours for the rest of the shift.
##
## So the exact gap is gated on known_line rather than on having offered.
## Having offered still buys you something real - the band - but a band is a
## read and a number is a readout, and only one of those you have paid for.
func _read_the_offer(c, o, band: String) -> void:
	if not o.revealed:
		_status.text = ""
		_hint.text = "their Line is marked - clear it before you offer" \
			if c.known_line else "read the room to learn their Line"
		return

	_hint.text = ""
	if not c.known_line:
		# You asked and they said no. How far off you were is a feeling.
		_status.text = band
		_status.add_theme_color_override("font_color", _bar.fill_color())
		return

	# READY is gated behind known_line for the same reason the number is: appeal
	# can climb past the Line on cards played AFTER a miss, and being told you
	# have cleared a line you cannot see is the number by another name.
	var gap: int = c.line - o.appeal
	if gap <= 0:
		_status.text = "READY TO SIGN"
		_status.add_theme_color_override("font_color", Palette.color(&"patience_ok"))
	else:
		_status.text = "%d SHORT" % gap
		_status.add_theme_color_override("font_color", _bar.fill_color())

## The two per-archetype combo knobs, read straight off their own data so this
## text can never drift from what Shift._settle() actually does with them.
static func knobs_text(c) -> String:
	return "Each sale: combo +%d%%, Line +%d" \
		% [roundi(c.archetype.combo_step * 100), c.archetype.line_per_sale]

## Where a rect of the screen sits in the tablet's own space: its centre...
static func centre_of(px: Rect2i) -> Vector3:
	var c := Vector2(px.position) + Vector2(px.size) * 0.5
	return Vector3((c.x - SIZE_PX.x * 0.5) / PX_PER_UNIT,
		(SIZE_PX.y * 0.5 - c.y) / PX_PER_UNIT, 0.0)

## ...and its size in world units.
static func size_of(px: Rect2i) -> Vector2:
	return Vector2(px.size) / PX_PER_UNIT
