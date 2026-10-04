extends RefCounted
## Guards the project settings that a later edit could quietly break.
var h: Harness

func test_the_web_export_still_targets_gl_compatibility() -> void:
	## G1.5 moved the desktop renderer to Forward+ for Card3D's sake. Godot has no
	## WebGPU backend, so a GLOBAL forward_plus would silently forfeit GODOT_SPEC.md
	## §10's itch.io web build. The per-platform override is what keeps both.
	h.eq("desktop renders Forward+",
		ProjectSettings.get_setting("rendering/renderer/rendering_method"),
		"forward_plus")
	h.eq("web still renders GL Compatibility, so G3 stays possible",
		ProjectSettings.get_setting("rendering/renderer/rendering_method.web"),
		"gl_compatibility")

func test_the_vendored_card3d_addon_is_present_and_loadable() -> void:
	for path in [
			"res://addons/card_3d/scenes/card_3d.tscn",
			"res://addons/card_3d/scenes/card_collection_3d.tscn",
			"res://addons/card_3d/shapes_3d/default_card_collection_3d_drop_zone_shape_3d.tres"]:
		h.check("%s exists" % path, ResourceLoader.exists(path))
	h.check("the MIT licence travelled with the vendored code",
		FileAccess.file_exists("res://addons/card_3d/LICENSE"))

func test_the_game_boots_into_the_run_not_a_bare_shift() -> void:
	## G2 made the run the entry point. A main scene that silently reverts to
	## shift.tscn would still play - one shift, forever, with no shop - which is
	## exactly the kind of regression that survives a playtest.
	h.eq("the main scene is the run",
		ProjectSettings.get_setting("application/run/main_scene"),
		"res://scenes/run.tscn")
