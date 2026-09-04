class_name CustomerCard3D extends Card3D
## The person you are selling to, as an object on the table.
##
## Built like a product card - a 2D face at 500x700 rendered into a SubViewport
## and used as the mesh albedo - because a customer should read as the same KIND
## of thing as the cards you play at them.
##
## Two states. On the floor it shows only identity: portrait, name, type and
## patience. Selecting them scales the card up and unhides the Detail block, so
## the card itself becomes the customer sheet rather than handing that job to a
## panel somewhere else on screen.

const FRONT_SIZE := Vector2i(500, 700)
const ORDINALS := ["", "1st", "2nd", "3rd", "4th", "5th", "6th", "7th", "8th", "9th"]
## How much bigger the card gets once you are standing with them.
const SELECTED_SCALE := 1.35
const SCALE_TWEEN := 0.35

var customer
var chair: int = -1

var _material := StandardMaterial3D.new()
var _bound := false
var _viewport: SubViewport
var _detail: Control
var _name: Label
var _archetype: Label
var _patience_bar: ProgressBar
var _patience: Label
var _line: Label
var _does: Label
var _table: Label
var _known: Label
var _scale_tween: Tween
var _expanded := false

func _ready() -> void:
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
	_detail = col.get_node(^"Detail")
	_line = _detail.get_node(^"LineLabel")
	_does = _detail.get_node(^"DoesLabel")
	_table = _detail.get_node(^"TableLabel")
	_known = _detail.get_node(^"KnownLabel")

	_viewport.size = FRONT_SIZE
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_material.albedo_texture = _viewport.get_texture()
	$CardMesh/CardFrontMesh.set_surface_override_material(0, _material)

## `c == null` is an empty chair. The card stays - a seat should not blink out of
## existence mid-shift - it just says nobody is there.
func setup(c, expanded: bool = false) -> void:
	_bind()
	customer = c
	_set_expanded(expanded and c != null)

	if c == null:
		_name.text = "- empty -"
		_archetype.text = ""
		_patience.text = ""
		_patience_bar.visible = false
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

	if _expanded:
		_line.text = "THE LINE  %d" % c.line if c.known_line else "THE LINE  ?"
		_does.text = behaviour_text(c)
		_table.text = unsigned_text(c)
		_known.text = known_text(c)
	_redraw()

## What their archetype does to you. Shared with the floor tooltip so the two
## can never disagree about what a customer is.
static func behaviour_text(c) -> String:
	var tells: Array[String] = []
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

static func known_text(c) -> String:
	var known: Array[String] = []
	for iid in c.known_ranks:
		known.append("%s %s" % [str(iid).capitalize(), ORDINALS[int(c.known_ranks[iid])]])
	if known.is_empty():
		return "you know nothing about their priorities yet"
	return " . ".join(known)

func _set_expanded(want: bool) -> void:
	if _expanded == want:
		return
	_expanded = want
	_detail.visible = want
	if _scale_tween != null and _scale_tween.is_running():
		_scale_tween.kill()
	var target := Vector3.ONE * (SELECTED_SCALE if want else 1.0)
	_scale_tween = create_tween()
	_scale_tween.set_ease(Tween.EASE_OUT)
	_scale_tween.set_trans(Tween.TRANS_CUBIC)
	_scale_tween.tween_property(self, "scale", target, SCALE_TWEEN)

func _redraw() -> void:
	if _viewport != null:
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
