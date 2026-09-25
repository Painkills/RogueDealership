class_name DetailCard3D extends Card3D
## The second card, hidden behind the first until you sit down with someone.
##
## Every seat has two: one behind the customer and one behind their product slot.
## On the floor they sit flush behind their partner at the same x and y, so they
## are simply occluded and cost nothing. Selecting the seat slides them out to
## the right, and that slide IS the zoom-in: the identity card stays the size it
## was and the detail arrives beside it, rather than the identity card growing
## and swallowing whatever was below it.
##
## Never dragged, never dropped on. Collision is disabled for its whole life, so
## it can never intercept a pointer aimed at the product slot it sits beside.

const FRONT_SIZE := Vector2i(500, 700)
## Exactly the size of the card it hides behind. A back that is not the same
## shape as its front is not a back, and the pair has to read as one card.
const CARD_SIZE := Vector2(2.5, 3.5)
## LEFT, and far enough that the two half-widths plus a gutter clear. Because
## both cards are the same width, the same offset gives the customer pair and
## the product pair an identical margin - it is equal by construction rather
## than by two numbers agreeing.
const SLIDE_OUT := Vector3(-2.75, 0.0, 0.03)
## The card's size in the world and its face's in pixels: CARD_SIZE and
## FRONT_SIZE for the product's sheet. A customer's back is set to its folder's
## own by build_shift_scene.gd - a back that is not the same shape as its front
## is not a back.
@export var card_size := CARD_SIZE
@export var face_size := FRONT_SIZE
const SLIDE_TWEEN := 0.42
## Late enough that a pair flipped by hover has finished turning back to face
## front before this starts moving it - see FlipPair.FLIP_TWEEN.
const SLIDE_DELAY := 0.32

var _material := StandardMaterial3D.new()
var _bound := false
var _viewport: SubViewport
var _title: Label
var _sub: Label
var _customer_body: Control
var _offer_body: Control
var _does: Label
var _table: Label
var _known: Label
var _margin: Label
var _combo_now: Label
var _bar: AppealBar
var _status: Label
var _hint: Label
var _sub_icon: CategoryIconControl

var _home: Vector3
var _home_rotation: Vector3
var _slide_tween: Tween
var _out := false

func _ready() -> void:
	# Authored FACING AWAY at home, so at rest it is the back of the card in
	# front of it. Coming out is a turn as well as a move.
	_home = position
	_home_rotation = rotation
	disable_collision()
	_bind()
	_redraw.call_deferred()

func _bind() -> void:
	if _bound:
		return
	_bound = true
	_viewport = $FrontViewport
	var col: Node = $FrontViewport/DetailFront/Margin/Column
	_title = col.get_node(^"TitleLabel")
	_sub = col.get_node(^"SubRow/SubLabel")
	_sub_icon = col.get_node(^"SubRow/SubIcon")
	_customer_body = col.get_node(^"CustomerBody")
	_offer_body = col.get_node(^"OfferBody")
	_does = _customer_body.get_node(^"DoesLabel")
	_table = _customer_body.get_node(^"TableLabel")
	_known = _customer_body.get_node(^"KnownLabel")
	_margin = _offer_body.get_node(^"MarginLabel")
	_combo_now = _offer_body.get_node(^"ComboNowLabel")
	_bar = _offer_body.get_node(^"AppealBar") as AppealBar
	_status = _offer_body.get_node(^"StatusLabel")
	_hint = _offer_body.get_node(^"HintLabel")

	_viewport.size = face_size
	# The face is laid out at 500x700; a wider back (a customer's - see
	# CustomerCard3D.CARD_SIZE) just gives its text more room across.
	($FrontViewport/DetailFront as Control).size = Vector2(face_size)
	CustomerCard3D.resize_quads(self, card_size)
	_viewport.disable_3d = true
	# UPDATE_ALWAYS, not UPDATE_ONCE: see card_face_3d.gd - the one-shot bake
	# raced dynamic card creation on the Web export.
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_material.albedo_texture = _viewport.get_texture()
	$CardMesh/CardFrontMesh.set_surface_override_material(0, _material)

# --- what it says ----------------------------------------------------------

## Their sheet: what their archetype does to you, what they have already agreed
## to, and what you have managed to work out about their priorities.
func show_customer(c) -> void:
	_bind()
	_customer_body.visible = c != null
	_offer_body.visible = false
	if c == null:
		_title.text = "- empty -"
		_sub.text = "nobody in this chair"
		_sub_icon.set_category(&"", Color.WHITE)
		_redraw()
		return
	_title.text = c.display_name
	_sub.text = c.archetype.display_name
	_sub_icon.set_category(&"", Color.WHITE)
	_does.text = CustomerCard3D.behaviour_text(c)
	_table.text = CustomerCard3D.unsigned_text(c)
	_known.text = CustomerCard3D.known_text(c)
	_redraw()

## The product's sheet, with the appeal meter. `band` comes from the model's own
## Shift.band_for(), so the colour thresholds are never re-derived here.
## `meter_scale` comes from the model's own ShiftConfig.appeal_meter_scale -
## a fixed ceiling, the same for every customer and every offer, so the bar
## never resizes itself out from under the fill.
func show_offer(c, band: String, meter_scale: int) -> void:
	_bind()
	_customer_body.visible = false
	var o = c.offer if c != null else null
	_offer_body.visible = o != null
	if o == null:
		_title.text = "nothing on the table"
		_sub.text = "drag a product onto them" if c != null else ""
		_sub_icon.set_category(&"", Color.WHITE)
		_combo_now.visible = false
		_redraw()
		return

	_title.text = o.product.display_name
	_sub.text = "%s . %s" % [o.product.interest.category.display_name,
		o.product.interest.display_name]
	_sub_icon.set_category(o.product.interest.category.id, Palette.color(&"accent"))
	_margin.text = Format.money(o.margin)
	_combo_now.visible = true
	# c.sales is how many products they have ALREADY taken this visit - the
	# same prior-sales count _settle() itself multiplies by, so the second
	# branch is a preview of the real number, not a separate guess. Before
	# any sale there is nothing to preview yet, so this shows the archetype's
	# own static knobs instead - never hidden, always something to read.
	if c.sales > 0:
		_combo_now.text = "×%.2f combo" % (1.0 + c.combo_step * c.sales)
	else:
		_combo_now.text = CustomerCard3D.combo_knobs_text(c)
	_bar.set_state(o.appeal, c.line, meter_scale, band, c.known_line)

	# The FILL is always honest about your own appeal; only the LINE is fogged,
	# and Read the Room is the ONLY thing that lifts it. Offering used to lift it
	# too, which quietly made the card optional: ask once, anywhere, and the exact
	# number was yours for the rest of the shift.
	#
	# So the exact gap is gated on known_line rather than on having offered.
	# Having offered still buys you something real - the band - but a band is a
	# read and a number is a readout, and only one of those you have paid for.
	if not o.revealed:
		_status.text = ""
		_hint.visible = true
		_hint.text = "their Line is marked - clear it before you offer" \
			if c.known_line else "read the room to learn their Line"
		_redraw()
		return

	_hint.visible = false
	if not c.known_line:
		# You asked and they said no. How far off you were is a feeling.
		_status.text = band
		_status.add_theme_color_override("font_color", _bar.fill_color())
		_redraw()
		return

	# READY is gated behind known_line for the same reason the number is: appeal
	# can climb past the Line on cards played AFTER a miss, and being told you
	# have cleared a line you cannot see is the number by another name.
	var gap: int = c.line - o.appeal
	if gap <= 0:
		_status.text = "READY - they will sign"
		_status.add_theme_color_override("font_color", Palette.color(&"patience_ok"))
	else:
		_status.text = "%d SHORT" % gap
		_status.add_theme_color_override("font_color", _bar.fill_color())
	_redraw()

# --- where it sits ---------------------------------------------------------

## Out to the left and face-front, or back behind its partner and facing away.
## Delayed on the way out so the camera has begun to settle first - the card
## arriving reads as a consequence of sitting down rather than something that
## happened at the same time.
func reveal(want: bool) -> void:
	if _out == want:
		return
	_out = want
	if _slide_tween != null and _slide_tween.is_valid() and _slide_tween.is_running():
		_slide_tween.kill()
	var to: Vector3 = _home + SLIDE_OUT if want else _home
	# Turning to face you is half the move. Without it the card would arrive
	# beside its partner still showing its own back.
	var to_rot: Vector3 = Vector3.ZERO if want else _home_rotation
	var delay: float = SLIDE_DELAY if want else 0.0
	_slide_tween = create_tween()
	_slide_tween.set_parallel(true)
	_slide_tween.set_ease(Tween.EASE_OUT)
	_slide_tween.set_trans(Tween.TRANS_CUBIC)
	_slide_tween.tween_property(self, "position", to, SLIDE_TWEEN).set_delay(delay)
	_slide_tween.tween_property(self, "rotation", to_rot, SLIDE_TWEEN).set_delay(delay)

func is_out() -> bool:
	return _out

func home() -> Vector3:
	return _home

func _redraw() -> void:
	if _viewport != null:
		# UPDATE_ALWAYS, not UPDATE_ONCE: see card_face_3d.gd - the one-shot bake
		# raced dynamic card creation on the Web export.
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
