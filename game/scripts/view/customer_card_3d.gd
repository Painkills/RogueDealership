class_name CustomerCard3D extends Card3D
## The person you are selling to, as an object on the table.
##
## Built like a product card - a 2D face rendered into a SubViewport and used as
## the mesh albedo - because a customer should read as the same KIND of thing as
## the cards you play at them. But WIDER: a customer is a file folder, landscape
## like a real one, and the width is what gives their interest grid room to be
## read (see build_customer_front_scene.gd).
##
## ONE state, deliberately. It used to scale up by a third and unhide a detail
## block when you selected it, and that is precisely what drove it down into the
## product slot underneath. The extra detail is a second card now, and this one
## never changes size, so the seat layout is fixed geometry rather than something
## that rearranges itself the moment you look at it.

## World units. The same height as every other card, so rows still line up;
## build_shift_scene.gd gives this card and its back their own meshes this
## size, rather than touching the shared product-card mesh.
const CARD_SIZE := Vector2(4.0, 3.5)
## The face, at the same pixels-per-unit as a product card's 500x700.
const FRONT_SIZE := Vector2i(800, 700)

var customer
var chair: int = -1

var _material := StandardMaterial3D.new()
var _bound := false
var _viewport: SubViewport
var _name: Label
var _photo: Control
var _archetype: Label
var _patience_bar: ProgressBar
## The box the bar fills - see build_customer_front_scene.gd. Shown and hidden
## with the bar, so an empty chair has no empty meter.
var _patience_frame: Control
## Owned per card, so recolouring one customer's bar never repaints another's.
var _patience_fill := StyleBoxFlat.new()
var _patience: Label
var _demand: Label
var _grid: InterestGrid
var _status: Label
var _bubble: SpeechBubble
## Numerals in the interest grid stop being readable before the cells do, so a
## card that is going to be drawn small says so once rather than guessing from
## its own size - the face is authored at 500x700 no matter where it lands.
var compact: bool = false

func _ready() -> void:
	# The seat's HoverPad owns the mouse, not this card. This card turns over,
	# and a rotating flat collider vanishes edge-on - which made hovering it
	# oscillate between flipped and not. A hover target must never be the thing
	# the hover moves.
	disable_collision()
	_bind()
	_redraw.call_deferred()

func _bind() -> void:
	if _bound:
		return
	_bound = true
	_viewport = $FrontViewport
	var col: Node = $FrontViewport/CustomerFront/Margin/Column
	# Name and patience sit beside their photo; the archetype is written on
	# the folder's tab - see build_customer_front_scene.gd.
	_name = col.get_node(^"Header/Info/NameLabel")
	_photo = col.get_node(^"Header/Photo")
	_archetype = $FrontViewport/CustomerFront/Tab/ArchetypeLabel
	_patience_frame = col.get_node(^"Header/Info/PatienceFrame")
	_patience_bar = _patience_frame.get_node(^"PatienceBar")
	_patience = col.get_node(^"Header/Info/PatienceLabel")
	_demand = col.get_node(^"DemandLabel")
	_grid = col.get_node(^"InterestGrid")
	_status = col.get_node(^"StatusLabel")
	_bubble = $FrontViewport/CustomerFront/SpeechBubble
	# Rounded to sit inside the frame's own corners.
	_patience_fill.set_corner_radius_all(7)
	_patience_bar.add_theme_stylebox_override("fill", _patience_fill)
	resize_quads(self, CARD_SIZE)

	_viewport.size = FRONT_SIZE
	_viewport.disable_3d = true
	# UPDATE_ALWAYS, not UPDATE_ONCE: see card_face_3d.gd - the one-shot bake
	# raced dynamic card creation on the Web export.
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_material.albedo_texture = _viewport.get_texture()
	$CardMesh/CardFrontMesh.set_surface_override_material(0, _material)

## Gives a card its own front and back quads at `size`. The addon's card scene
## shares one 2.5 x 3.5 mesh between every card in the game, so a wider card
## takes copies rather than stretching the one every product card is using.
static func resize_quads(card: Node3D, size: Vector2) -> void:
	for path in [^"CardMesh/CardFrontMesh", ^"CardMesh/CardBackMesh"]:
		var quad := card.get_node(path) as MeshInstance3D
		var plane := quad.mesh as PlaneMesh
		if plane != null and plane.size != size:
			plane = plane.duplicate() as PlaneMesh
			plane.size = size
			quad.mesh = plane

## `c == null` is an empty chair. The card stays - a seat should not blink out of
## existence mid-shift - it just says nobody is there.
##
## `seated` is whether you are sitting with THIS customer. It hides the status
## line: that is there so the FLOOR can tell you that you left a product with
## someone, and once you are with them the product is standing right below this
## card. It also sets how long what they say stays up - see SpeechBubble.
func setup(c, seated: bool = false, tick: int = 0) -> void:
	_bind()
	# A bubble is keyed to whoever said it, not to the chair - the moment the
	# customer in it changes (walked, signed, or a fresh arrival), whatever is
	# still floating over their face belongs to somebody who is not there any
	# more.
	if c != customer and _bubble != null:
		_bubble.visible = false
	customer = c
	if _bubble != null:
		# Quick to clear at the desk you are sitting at, where the grid under it
		# is what you are working from; slower at the others, where the bubble
		# is how you hear that someone said anything at all.
		_bubble.update_visibility(tick, SpeechBubble.AT_YOUR_DESK_TICKS if seated \
			else SpeechBubble.SIDE_SEAT_TICKS)
	_status.visible = not seated

	if c == null:
		_name.text = "- empty -"
		_archetype.text = ""
		_patience.text = ""
		_demand.text = ""
		_status.text = ""
		_patience_frame.visible = false
		_grid.visible = false
		# An empty file has nobody's photo clipped to it.
		_photo.visible = false
		_redraw()
		return

	_photo.visible = true
	_name.text = c.display_name
	_archetype.text = "%s  [%s]" % [c.archetype.display_name, c.key]
	_patience_frame.visible = true
	_patience_bar.max_value = c.max_patience
	_patience_bar.value = c.patience
	# The FILL carries the colour, not the whole bar. Modulating the bar tinted
	# its empty trough too, which on paper turned the part of the patience you
	# have already lost the same muddy green as the part you still have.
	_patience_fill.bg_color = Format.patience_color(c.patience, c.max_patience)
	_patience.text = "patience %d/%d" % [c.patience, c.max_patience]
	_patience.add_theme_color_override("font_color",
		Palette.color(&"alert") if c.leaving_soon() else Palette.color(&"text"))
	_demand.text = demand_text(c, tick)
	_grid.visible = true
	_grid.set_state(c.interests(), c.known_ranks, c.known_top_category,
		sold_interests(c), not compact)
	_status.text = status_text(c)
	_redraw()

## "All customer actions need to show on the screen, not just in the log" -
## pops a speech bubble with their own words over the card, timed against the
## model's own clock (tick) rather than a wall-clock timer. A no-op before
## _bind() has run, which only a bare .instantiate() in a test can hit.
func say(text: String, tick: int) -> void:
	_bind()
	if _bubble != null:
		_bubble.say(text, tick)

## Clears what they just said - you looked at them, so it has been heard.
func hush() -> void:
	_bind()
	if _bubble != null:
		_bubble.hush()

func is_speaking() -> bool:
	return _bubble != null and _bubble.visible

## What this customer does to you, and what they will not do for you.
##
## `demands` comes FIRST and is not an action: it is a standing rule that
## close() enforces, so it never fires, never appears in the log, and was
## therefore invisible - a Karen would simply refuse to sign with no stated
## reason anywhere on screen.
static func behaviour_text(c) -> String:
	var tells: Array[String] = []
	if c.demands_category != null:
		tells.append("WILL NOT SIGN until they have bought something in %s."
			% str(c.demands_category).capitalize())
	for act in c.archetype.actions:
		tells.append("%s - %s" % [act.display_name, act.tell])
	if tells.is_empty():
		return "Nothing. They just sit and listen."
	return "\n".join(tells)

static func unsigned_text(c) -> String:
	var parts: Array[String] = []
	for u in c.unsigned:
		parts.append("%s %s" % [u["product"].display_name, Format.money(u["margin"])])
	if parts.is_empty():
		return "nothing agreed yet"
	return "%s\n(%s at risk)" % ["\n".join(parts), Format.money(c.unsigned_margin())]

## The one thing about their priority list that is not already sitting on the
## interest grid itself: which CATEGORY narrowed to. Individual ranks used to
## be repeated here too, as a growing ". "-joined line - the grid now carries
## that (each known cell names its own interest, see InterestGrid._draw_cell),
## so saying it twice is a caption for a picture that already has one.
##
## `known_top_category` is the whole point of Read the Room - it narrows nine
## interests to three - and it used to be set by the model and then dropped
## here, so playing the card looked like it did nothing at all.
static func known_text(c) -> String:
	if c.known_top_category != null:
		return "Their number one is a %s need." % str(c.known_top_category).capitalize()
	return "you know nothing about their priorities yet"

## What they are asking for and how long you have, or nothing. The telegraph is
## authored SHORT for exactly this - it has to fit one line on a card that may
## be 179 px wide - and the countdown is what turns an event into a decision.
static func demand_text(c, tick: int) -> String:
	if c.demand == null:
		return ""
	var left: int = maxi(0, c.demand_due_tick - tick)
	return "%s  %dt" % [c.demand.telegraph, left]

## Which of their interests they have already bought into. The grid lights these
## rather than the status line listing them, because a list grows and a grid
## does not.
static func sold_interests(c) -> Dictionary:
	var out := {}
	for u in c.unsigned:
		out[u["product"].interest.id] = true
	return out

## The floor card's one non-identity line. Short on purpose: it exists so that
## walking away from a live offer is visible from the floor, not to reproduce the
## tablet in miniature.
static func status_text(c) -> String:
	var parts: Array[String] = []
	if c.offer != null:
		parts.append("on the table: %s" % c.offer.product.display_name)
	if not c.unsigned.is_empty():
		parts.append("%s unsigned" % Format.money(c.unsigned_margin()))
	return "\n".join(parts)

func _redraw() -> void:
	if _viewport != null:
		# UPDATE_ALWAYS, not UPDATE_ONCE: see card_face_3d.gd - the one-shot bake
		# raced dynamic card creation on the Web export.
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
