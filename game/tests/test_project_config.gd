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

func test_the_viewport_is_still_the_960x540_the_art_spec_assumes() -> void:
	## GODOT_SPEC.md §7 picked 960x540 over 640x360 because the game is text-dense.
	## 3D cards do not change that; the Label3D faces are sized against it.
	h.eq("viewport width", ProjectSettings.get_setting("display/window/size/viewport_width"), 960)
	h.eq("viewport height", ProjectSettings.get_setting("display/window/size/viewport_height"), 540)

func test_msaa_is_off_so_pixel_text_stays_crisp() -> void:
	## Forward+ makes 3D MSAA meaningful, and it softens exactly the pixel-font
	## edges this port exists to keep legible.
	h.eq("3D MSAA disabled",
		int(ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_3d")), 0)

func test_the_vendored_card3d_addon_is_present_and_loadable() -> void:
	for path in [
			"res://addons/card_3d/scenes/card_3d.tscn",
			"res://addons/card_3d/scenes/card_collection_3d.tscn",
			"res://addons/card_3d/shapes_3d/default_card_collection_3d_drop_zone_shape_3d.tres"]:
		h.check("%s exists" % path, ResourceLoader.exists(path))
	h.check("the MIT licence travelled with the vendored code",
		FileAccess.file_exists("res://addons/card_3d/LICENSE"))
