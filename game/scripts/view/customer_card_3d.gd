class_name CustomerCard3D extends Card3D
## The person you are selling to, as an object on the table.
##
## Same construction as a product card - 2D face at 500x700 rendered into a
## SubViewport and used as the mesh albedo - because a customer should read as
## the same KIND of thing as the cards you play at them.
##
## It carries the state you triage on: name, archetype, patience, and their Line
## once you know it. Everything slower-moving (what they do, what is on the
## table, what you have learned) lives in the world-anchored panel beside them,
## not on the card itself.

const FRONT_SIZE := Vector2i(500, 700)

var customer

var _material := StandardMaterial3D.new()
var _bound := false
var _viewport: SubViewport
var _name: Label
var _archetype: Label
var _patience_bar: ProgressBar
var _patience: Label
var _line: Label

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
	_line = col.get_node(^"LineLabel")

	_viewport.size = FRONT_SIZE
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_material.albedo_texture = _viewport.get_texture()
	$CardMesh/CardFrontMesh.set_surface_override_material(0, _material)

## `null` means an empty chair - the card still exists, so the seat never
## visually disappears mid-shift, it just shows nobody is there.
func setup(c) -> void:
	_bind()
	customer = c
	if c == null:
		_name.text = "- empty -"
		_archetype.text = ""
		_patience.text = ""
		_line.text = ""
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
	_line.text = "THE LINE  %d" % c.line if c.known_line else "THE LINE  ?"
	_redraw()

func _redraw() -> void:
	if _viewport != null:
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
