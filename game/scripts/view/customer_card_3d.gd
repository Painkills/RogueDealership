class_name CustomerCard3D extends Card3D
## The person you are selling to, as an object on the table.
##
## Built like a product card - a 2D face at 500x700 rendered into a SubViewport
## and used as the mesh albedo - because a customer should read as the same KIND
## of thing as the cards you play at them.
##
## ONE state, deliberately. It used to scale up by a third and unhide a detail
## block when you selected it, and that is precisely what drove it down into the
## product slot underneath. The extra detail is a second card now, and this one
## never changes size, so the seat layout is fixed geometry rather than something
## that rearranges itself the moment you look at it.

const FRONT_SIZE := Vector2i(500, 700)

var customer
var chair: int = -1

var _material := StandardMaterial3D.new()
## Its own material, separate from _material above: the card face is opaque
## and never needs transparency or billboarding, and giving the bubble its
## own StandardMaterial3D is what lets it be both - see _bind() below.
var _bubble_material := StandardMaterial3D.new()
var _bound := false
var _viewport: SubViewport
var _bubble_viewport: SubViewport
var _name: Label
var _archetype: Label
var _patience_bar: ProgressBar
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
	_name = col.get_node(^"NameLabel")
	_archetype = col.get_node(^"ArchetypeLabel")
	_patience_bar = col.get_node(^"PatienceBar")
	_patience = col.get_node(^"PatienceLabel")
	_demand = col.get_node(^"DemandLabel")
	_grid = col.get_node(^"InterestGrid")
	_status = col.get_node(^"StatusLabel")
	_bubble_viewport = $BubbleViewport
	_bubble = $BubbleViewport/SpeechBubble

	_viewport.size = FRONT_SIZE
	_viewport.disable_3d = true
	# UPDATE_ALWAYS, not UPDATE_ONCE: see card_face_3d.gd - the one-shot bake
	# raced dynamic card creation on the Web export.
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_material.albedo_texture = _viewport.get_texture()
	$CardMesh/CardFrontMesh.set_surface_override_material(0, _material)

	# Explicit, not left to whatever the .tscn's own serialized size resolves
	# to: FrontViewport hits exactly this gap on the Web export (see the
	# UPDATE_ALWAYS comment above) and only setting size in code, not just in
	# the scene file, reliably avoids it - confirmed live as a zero-size
	# framebuffer (GL_INVALID_FRAMEBUFFER_OPERATION) the one time this was
	# skipped here.
	_bubble_viewport.size = SpeechBubble.CANVAS_SIZE
	_bubble_viewport.disable_3d = true
	_bubble_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# Everywhere the bubble's own 2D scene draws nothing (outside the rounded
	# panel and its tail) has to stay see-through, or the bubble would show
	# up as a solid rectangle - the one thing that would defeat "coming out
	# of the card" the hardest.
	_bubble_viewport.transparent_bg = true
	_bubble_material.albedo_texture = _bubble_viewport.get_texture()
	_bubble_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Faces the camera regardless of the seat's own rotation (the carousel, or
	# a hover-flip on the floor) - a speech bubble that turned edge-on with
	# its card would vanish exactly when the flip animation made it hardest
	# to notice. FIXED_Y, not full spherical: the seat cameras look down at
	# the table, and a spherical billboard would tip the bubble back toward
	# the camera instead of just turning it to face forward.
	_bubble_material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	# CONFIRMED live: CULL_DISABLED alone made the bubble render for the first
	# time - proving billboard mode really does recompute orientation from its
	# own convention rather than composing with BubbleMesh's pre-rotation, and
	# that the face left facing the camera was the one CULL_BACK had been
	# discarding the whole time. But two-sided rendering shows the texture as
	# authored on THAT face - mirror-image, confirmed live (readable text,
	# backwards). uv1_scale.x = -1 flips the U axis in material space, which a
	# billboard-recomputed basis cannot re-break, instead of trying to predict
	# which geometric orientation lands the correct face toward the camera.
	_bubble_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_bubble_material.uv1_scale = Vector3(-1.0, 1.0, 1.0)
	# Confirmed live: text on, mirroring fixed, positioned in frame - but the
	# whole panel rendered muddy and dark, barely legible, because a default
	# StandardMaterial3D is LIT - scene lighting was multiplying down colours
	# that were only ever meant to be read exactly as this texture authored
	# them, the same as every other UI-on-a-mesh surface in this project.
	# CardFrontMesh gets away without this because its fixed orientation
	# happens to catch the key light; a billboard's normal always points
	# straight at the camera, wherever that puts it relative to the light.
	_bubble_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var bubble_mesh: MeshInstance3D = $BubbleMesh
	bubble_mesh.set_surface_override_material(0, _bubble_material)
	# Frustum culling runs against the mesh's PRE-billboard bounding box - the
	# vertex shader only reorients to face the camera after that test already
	# ran. A thin, pre-rotated plane's own box is an easy false negative there
	# (confirmed live: fully wired, zero render errors, still never visible),
	# so this trades a precise box for one generous enough to never be the
	# reason the bubble fails to draw.
	bubble_mesh.custom_aabb = AABB(Vector3(-2.5, -2.5, -2.5), Vector3(5.0, 5.0, 5.0))

## `c == null` is an empty chair. The card stays - a seat should not blink out of
## existence mid-shift - it just says nobody is there.
##
## `seated` only decides whether the status line shows. It is there so the FLOOR
## can tell you that you left a product with someone; once you are with them the
## product card is sitting directly below this one, and a line of text repeating
## what a card already says is just something else to keep in sync.
func setup(c, seated: bool = false, tick: int = 0) -> void:
	_bind()
	# A bubble is keyed to whoever said it, not to the chair - the moment the
	# customer in it changes (walked, signed, or a fresh arrival), whatever is
	# still floating over their face belongs to somebody who is not there any
	# more.
	if c != customer and _bubble != null:
		_bubble.visible = false
	customer = c
	_status.visible = not seated

	if c == null:
		_name.text = "- empty -"
		_archetype.text = ""
		_patience.text = ""
		_demand.text = ""
		_status.text = ""
		_patience_bar.visible = false
		_grid.visible = false
		_redraw()
		return

	_name.text = c.display_name
	_archetype.text = "%s  [%s]" % [c.archetype.display_name, c.key]
	_patience_bar.visible = true
	_patience_bar.max_value = c.max_patience
	_patience_bar.value = c.patience
	_patience_bar.modulate = Format.patience_color(c.patience, c.max_patience)
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
## pops a speech bubble with their own words over the card. A no-op before
## _bind() has run, which only a bare .instantiate() in a test can hit.
func say(text: String) -> void:
	_bind()
	if _bubble != null:
		_bubble.say(text)

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
## detail card in miniature.
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
