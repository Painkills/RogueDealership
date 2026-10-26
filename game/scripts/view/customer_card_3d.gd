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
var _photo: PhotoFrame
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
## The body of a note - see setup_note().
var _note: Label
var _bubble: SpeechBubble
## The clocks for your cards still working on them - see LingerBadges.
var _badges: LingerBadges
## The countdown on their incoming action, and the red banner it sits on (at its right end).
var _countdown: DemandBadge
var _banner := StyleBoxFlat.new()
## The action the banner last popped for - a new one pops it again.
var _shown_demand = null
var _pop: Tween = null
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
	_note = col.get_node(^"NoteLabel")
	_bubble = $FrontViewport/CustomerFront/SpeechBubble
	_badges = $FrontViewport/CustomerFront/LingerBadges
	_countdown = _demand.get_node(^"DemandBadge")
	_banner.bg_color = Palette.color(&"alert")
	_banner.set_corner_radius_all(14)
	_banner.content_margin_left = 14
	_banner.content_margin_top = 2
	_banner.content_margin_bottom = 2
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
## A menu run's grid columns and the interests you have a product for (see
## InterestGrid._order) - set by the floor before setup(). Empty in a classic run.
var menu_order: Dictionary = {}
var menu_stocked: Dictionary = {}

func setup(c, seated: bool = false, tick: int = 0) -> void:
	_bind()
	# A bubble is keyed to whoever said it, not to the chair - the moment the
	# customer in it changes (walked, signed, or a fresh arrival), whatever is
	# still floating over their face belongs to somebody who is not there any
	# more.
	if c != customer and _bubble != null:
		_bubble.visible = false
	customer = c
	_note.visible = false
	if _bubble != null:
		# Quick to clear at the desk you are sitting at, where the grid under it
		# is what you are working from; slower at the others, where the bubble
		# is how you hear that someone said anything at all.
		_bubble.update_visibility(tick, SpeechBubble.AT_YOUR_DESK_TICKS if seated \
			else SpeechBubble.SIDE_SEAT_TICKS)
	_status.visible = not seated
	var turns: Array[int] = []
	if c != null:
		for s in c.lingering:
			turns.append(int(s["ticks_left"]))
	_badges.show_turns(turns)

	if c == null:
		_name.text = "- empty -"
		_archetype.text = ""
		_patience.text = ""
		_set_banner("", -1)
		_shown_demand = null
		_status.text = ""
		_patience_frame.visible = false
		_grid.visible = false
		# An empty file has nobody's photo clipped to it.
		_photo.visible = false
		_redraw()
		return

	_photo.visible = true
	_photo.icon = c.archetype.icon
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
	# "Incoming" - a red banner across the folder, the countdown big at its left
	# end, and a pop and a flash the moment something new comes up.
	_set_banner(banner_text(c), maxi(0, c.demand_due_tick - tick) if c.demand != null else -1)
	if c.demand != null and c.demand != _shown_demand:
		_pop_banner()
	_shown_demand = c.demand
	_grid.visible = true
	_grid.set_state(c.interests(), c.known_ranks, c.known_top_category,
		sold_interests(c), not compact, c.known_top, menu_order, menu_stocked)
	_status.text = status_text(c)
	_redraw()

## A folder with nobody in it, carrying a note instead: a boss fight's budget or
## next move, on the seats either side of the boss (see BossPanels). `note` is
## BossPanels' Dictionary. The same face as a customer's - a title where their
## name goes, a bar and its words where their patience goes, a red line where
## their countdown goes - with the explanation where their interests would be,
## and nobody's photo.
## Where the patience bar sits on the folder's face, as a share of its width and
## height - for a popup about their patience to go beside it.
func patience_frac() -> Vector2:
	return _patience_at()

## The clocks' numbers as drawn ("" when no card of yours is working on them).
func badge_text() -> String:
	_bind()
	return _badges.shown_text() if _badges.visible else ""

func _patience_at() -> Vector2:
	_bind()
	var r := _patience_bar.get_global_rect()
	if r.size.x <= 0.0 or _viewport == null or _viewport.size.x <= 0:
		return Vector2(0.55, 0.2)
	return r.get_center() / Vector2(_viewport.size)

func setup_note(note: Dictionary) -> void:
	_bind()
	customer = null
	_badges.show_turns([] as Array[int])
	if _bubble != null:
		_bubble.visible = false
	_status.visible = false
	_photo.visible = false
	_archetype.text = str(note.get("tab", ""))
	_name.text = str(note.get("title", ""))
	_patience_frame.visible = true
	_patience_bar.max_value = maxf(1.0, float(note.get("bar_max", 1)))
	_patience_bar.value = float(note.get("bar_value", 0))
	_patience_fill.bg_color = note.get("bar_color", Palette.color(&"money"))
	_patience.text = str(note.get("bar_text", ""))
	_patience.add_theme_color_override("font_color", Palette.color(&"text"))
	_set_banner(str(note.get("headline", "")), -1)
	_grid.visible = false
	_note.text = str(note.get("body", ""))
	_note.visible = true
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
	# A boss is a fight, not a sale: three short lines, and the rest is said
	# move by move on the folders either side (BossPanels).
	if c.archetype.is_boss():
		return BossPanels.fight_text(c)
	if c.demands_category != null:
		tells.append("WILL NOT SIGN until they have bought something in %s."
			% str(c.demands_category).capitalize())
	# The Budget Hawk's whole behaviour is a rule rather than an action, so it
	# has to be said here or their card reads as nobody in particular.
	var past: int = c.archetype.needs_concession_past_rank
	if past > 0:
		tells.append("HOLDS OUT - won't take anything outside their top %d without a concession first." % past)
	var most: int = c.archetype.min_products_to_sign
	if most > 0:
		tells.append("WILL NOT SIGN for fewer than %d products." % most)
	# The rest of the rules nothing fires for, said here for the same reason.
	var nth: int = c.archetype.rejects_every_nth_card
	if nth > 0:
		tells.append("SKEPTICAL - waves off every %s card you play on them: it is spent, and does nothing."
			% ordinal(nth))
	if c.archetype.only_category != null:
		tells.append("%s ONLY - will not even look at anything else."
			% c.archetype.only_category.display_name.to_upper())
	if c.archetype.pays_per_patience_left > 0:
		tells.append("IN A HURRY - pays %s for every point of patience they have left when they sign."
			% Format.money(c.archetype.pays_per_patience_left))
	var prized: Array[String] = []
	for i in c.archetype.premium_interests:
		if i != null:
			prized.append(i.display_name)
	if not prized.is_empty() and c.archetype.premium_margin_scale > 1.0:
		var times: String = "DOUBLE" if is_equal_approx(c.archetype.premium_margin_scale, 2.0) \
			else "x%s" % str(c.archetype.premium_margin_scale)
		tells.append("PAYS %s for %s." % [times, " and ".join(prized)])
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

## What they are asking for and how long you have, or nothing. The telegraph is
## authored SHORT for exactly this - it has to fit one line on a card that may
## be 179 px wide - and the countdown is what turns an event into a decision.
static func demand_text(c, tick: int) -> String:
	var parts: Array[String] = []
	if c.demand != null:
		var left: int = maxi(0, c.demand_due_tick - tick)
		parts.append("%s  %dt" % [c.demand.telegraph, left])
	# Not an ask but a warning, in the same place: whatever you play on them
	# next is wasted (CustomerArchetype.rejects_every_nth_card).
	if c.next_card_rejected():
		parts.append(NEXT_CARD_REJECTED)
	return "\n".join(parts)

const NEXT_CARD_REJECTED := "NEXT CARD REJECTED"

## The banner's words: what they are asking for, and the warning that the next
## card is wasted - the countdown goes on the badge, not in the words.
static func banner_text(c) -> String:
	var parts: Array[String] = []
	if c.demand != null:
		parts.append(c.demand.telegraph)
	if c.next_card_rejected():
		parts.append(NEXT_CARD_REJECTED)
	return "\n".join(parts)

## The banner: red with white words when there is something to say, nothing at
## all when not; the countdown badge when there is a clock on it.
func _set_banner(text: String, ticks: int) -> void:
	_demand.text = text
	if text == "":
		_demand.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		_countdown.show_ticks(-1)
		return
	_banner.content_margin_right = (DEMAND_BADGE_ROOM if ticks >= 0 else 14)
	_demand.add_theme_stylebox_override("normal", _banner)
	_demand.add_theme_color_override("font_color", Palette.color(&"panel"))
	_countdown.show_ticks(ticks)

const DEMAND_BADGE_ROOM := 70

## The ticks on the countdown, or -1 when there is none.
func countdown() -> int:
	return _countdown.ticks()

## Whether the banner is popping right now - a new action just came up.
func banner_popping() -> bool:
	return _pop != null and _pop.is_valid() and _pop.is_running()

func _pop_banner() -> void:
	if _pop != null and _pop.is_valid():
		_pop.kill()
	_demand.pivot_offset = _demand.size * 0.5
	_pop = create_tween()
	for _k in range(3):
		_pop.tween_property(_demand, "scale", Vector2(1.18, 1.18), 0.12) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_pop.parallel().tween_property(_demand, "modulate", Color(1.7, 1.7, 1.7, 1.0), 0.12)
		_pop.tween_property(_demand, "scale", Vector2.ONE, 0.22)
		_pop.parallel().tween_property(_demand, "modulate", Color.WHITE, 0.22)

## 3 -> "3rd".
static func ordinal(n: int) -> String:
	var suffix := "th"
	if n % 100 < 11 or n % 100 > 13:
		match n % 10:
			1: suffix = "st"
			2: suffix = "nd"
			3: suffix = "rd"
	return "%d%s" % [n, suffix]

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
	# Your cards still working on them: what each is doing every tick, and for how
	# many more.
	for s in c.lingering:
		var card: CardDef = s["card"]
		parts.append("%s: %s a tick, %d more" % [card.display_name if card != null else "-",
			(s["inner"] as Effect).describe(), int(s["ticks_left"])])
	return "\n".join(parts)

func _redraw() -> void:
	if _viewport != null:
		# UPDATE_ALWAYS, not UPDATE_ONCE: see card_face_3d.gd - the one-shot bake
		# raced dynamic card creation on the Web export.
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
