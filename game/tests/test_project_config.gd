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

func test_the_web_export_installs_as_a_full_screen_app() -> void:
	## The phone's "install" needs the manifest and service worker the PWA option
	## makes, and its home-screen icon needs the pictures the manifest names.
	var presets := ConfigFile.new()
	h.eq("the export presets load", presets.load("res://export_presets.cfg"), OK)
	var web := ""
	for section in presets.get_sections():
		if presets.get_value(section, "platform", "") == "Web":
			web = section
	h.check("there is a Web preset", web != "")
	var options := web + ".options"
	h.check("it is a progressive web app", bool(presets.get_value(options,
		"progressive_web_app/enabled", false)))
	h.eq("that opens full screen (0 is Fullscreen)", int(presets.get_value(options,
		"progressive_web_app/display", -1)), 0)
	for key in ["icon_144x144", "icon_180x180", "icon_512x512"]:
		var path := str(presets.get_value(options, "progressive_web_app/" + key, ""))
		h.check("%s is a picture that exists (%s)" % [key, path],
			path != "" and FileAccess.file_exists(path))

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
