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

func test_the_viewport_is_big_enough_for_readable_cards() -> void:
	## 960x540 came from GODOT_SPEC.md 7's pixel-art plan, which the move to 3D
	## retired. At that size a card was ~106px wide and its text was illegible no
	## matter how it was drawn - the resolution was the ceiling, not the method.
	h.check("viewport is at least 1920 wide",
		int(ProjectSettings.get_setting("display/window/size/viewport_width")) >= 1920)
	h.check("and at least 1080 tall",
		int(ProjectSettings.get_setting("display/window/size/viewport_height")) >= 1080)

func test_the_3d_renders_at_window_resolution_not_upscaled() -> void:
	## "viewport" stretch renders the 3D at the base size and scales the result
	## up, which is why the table looked soft. canvas_items scales only the UI
	## layer and lets 3D render natively.
	h.eq("stretch mode", ProjectSettings.get_setting("display/window/stretch/mode"),
		"canvas_items")

func test_msaa_is_on_now_that_this_is_not_pixel_art() -> void:
	## It was off to protect pixel-font edges. There is no pixel font, and card
	## edges at an angle are exactly what MSAA is for.
	h.check("3D MSAA enabled",
		int(ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_3d")) > 0)

func test_the_vendored_card3d_addon_is_present_and_loadable() -> void:
	for path in [
			"res://addons/card_3d/scenes/card_3d.tscn",
			"res://addons/card_3d/scenes/card_collection_3d.tscn",
			"res://addons/card_3d/shapes_3d/default_card_collection_3d_drop_zone_shape_3d.tres"]:
		h.check("%s exists" % path, ResourceLoader.exists(path))
	h.check("the MIT licence travelled with the vendored code",
		FileAccess.file_exists("res://addons/card_3d/LICENSE"))
