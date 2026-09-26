class_name OfficeWindows extends Node3D
## The office's windows, along the back wall behind the customers. What they
## look out on says which shift you are working - morning light, a bright
## afternoon, or a town lit up at night - the same three the week's calendar
## offers you (see ShiftHours).
##
## One sky, drawn once into a texture (SkyView) and cut across every pane, so
## the view carries on behind the frames between them the way it would through
## real windows. Scenery like the desks: meshes and nothing else, so nothing
## here can take a click meant for the table in front of it.

var _bound := false
var _sky: SkyView

func _ready() -> void:
	_bind()

func _bind() -> void:
	if _bound:
		return
	_bound = true
	var viewport := $SkyViewport as SubViewport
	_sky = $SkyViewport/Sky as SkyView
	# UPDATE_ALWAYS, the same as every card face: see card_face_3d.gd on the
	# one-shot bake the Web export raced.
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var panes := $Panes.get_children()
	for i in range(panes.size()):
		var m := StandardMaterial3D.new()
		m.albedo_texture = viewport.get_texture()
		# Lit by the day outside, not by the office's lamps.
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		# Pane i shows the i-th slice of the one picture, left to right.
		m.uv1_scale = Vector3(1.0 / panes.size(), 1.0, 1.0)
		m.uv1_offset = Vector3(float(i) / panes.size(), 0.0, 0.0)
		(panes[i] as MeshInstance3D).material_override = m

## `id` is the shift's ShiftProfile id - &"morning", &"midday" or &"night". Any
## other looks out on the middle of the day.
func show_time(id: StringName) -> void:
	_bind()
	_sky.time_of_day = id

func time_of_day() -> StringName:
	_bind()
	return _sky.time_of_day
