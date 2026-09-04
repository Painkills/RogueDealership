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

const FRONT_SIZE := Vector2i(800, 700)
## Wider than a playing card. Height is what the seat framing is short of, and
## width is what it has spare, so the prose card spends the width.
const CARD_SIZE := Vector2(4.0, 3.5)
## Card half-widths plus a gutter: 1.25 (partner) + 2.0 (self) + gutter.
const SLIDE_OUT := Vector3(3.47, 0.0, 0.12)
const SLIDE_TWEEN := 0.42
const SLIDE_DELAY := 0.16

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
var _bar: AppealBar
var _status: Label
var _hint: Label

var _home: Vector3
var _slide_tween: Tween
var _out := false

func _ready() -> void:
	_home = position
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
	_sub = col.get_node(^"SubLabel")
	_customer_body = col.get_node(^"CustomerBody")
	_offer_body = col.get_node(^"OfferBody")
	_does = _customer_body.get_node(^"DoesLabel")
	_table = _customer_body.get_node(^"TableLabel")
	_known = _customer_body.get_node(^"KnownLabel")
	_margin = _offer_body.get_node(^"MarginLabel")
	_bar = _offer_body.get_node(^"AppealBar") as AppealBar
	_status = _offer_body.get_node(^"StatusLabel")
	_hint = _offer_body.get_node(^"HintLabel")

	_viewport.size = FRONT_SIZE
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
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
		_redraw()
		return
	_title.text = c.display_name
	_sub.text = c.archetype.display_name
	_does.text = CustomerCard3D.behaviour_text(c)
	_table.text = CustomerCard3D.unsigned_text(c)
	_known.text = CustomerCard3D.known_text(c)
	_redraw()

## The product's sheet, with the appeal meter. `band` comes from the model's own
## Shift.band_for(), so the colour thresholds are never re-derived here.
func show_offer(c, band: String) -> void:
	_bind()
	_customer_body.visible = false
	var o = c.offer if c != null else null
	_offer_body.visible = o != null
	if o == null:
		_title.text = "nothing on the table"
		_sub.text = "drag a product onto them" if c != null else ""
		_redraw()
		return

	_title.text = o.product.display_name
	_sub.text = "%s . %s" % [o.product.interest.category.display_name,
		o.product.interest.display_name]
	_margin.text = Format.money(o.margin)
	_bar.set_state(o.appeal, c.line, meter_scale(o.appeal, c.line), band, c.known_line)

	# The FILL is always honest about your own appeal; only the LINE is fogged.
	# Which is why the gap is spelled out as a number only once you have offered
	# and the model has actually told you the number.
	if o.revealed:
		var gap: int = c.line - o.appeal
		if gap <= 0:
			_status.text = "READY - they will sign"
			_status.add_theme_color_override("font_color", Palette.color(&"patience_ok"))
		else:
			_status.text = "%d SHORT" % gap
			_status.add_theme_color_override("font_color", _bar.fill_color())
		_hint.visible = false
	else:
		_status.text = ""
		_hint.visible = true
		_hint.text = "their Line is marked - clear it before you offer" \
			if c.known_line else "offer, or read the room, to learn their Line"
	_redraw()

## Never lets the fill or the marker run off the end, and only steps in tens so
## the bar does not silently rescale under you every time appeal moves.
static func meter_scale(appeal: int, line: int) -> int:
	return maxi(40, (maxi(appeal, line) / 10 + 1) * 10)

# --- where it sits ---------------------------------------------------------

## Out to the right, or back behind its partner. Delayed on the way out so the
## camera has begun to settle first - the card arriving reads as a consequence
## of sitting down rather than a thing that happened at the same time.
func reveal(want: bool) -> void:
	if _out == want:
		return
	_out = want
	if _slide_tween != null and _slide_tween.is_valid() and _slide_tween.is_running():
		_slide_tween.kill()
	var to: Vector3 = _home + SLIDE_OUT if want else _home
	_slide_tween = create_tween()
	_slide_tween.set_ease(Tween.EASE_OUT)
	_slide_tween.set_trans(Tween.TRANS_CUBIC)
	_slide_tween.tween_property(self, "position", to, SLIDE_TWEEN) \
		.set_delay(SLIDE_DELAY if want else 0.0)

func is_out() -> bool:
	return _out

func home() -> Vector3:
	return _home

func _redraw() -> void:
	if _viewport != null:
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
