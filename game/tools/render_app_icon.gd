extends SceneTree
## Draws the app's icon - the dealership's pylon sign over a car, on the card
## backs' navy - and writes it at the three sizes the installed web app wants
## (res://icons/app_512.png is also the project's own icon, so the browser tab's
## favicon and the home-screen icon are the same picture). Needs a window (not
## --headless), which is what draws anything.
##
##     godot --path game --script res://tools/render_app_icon.gd

const SIZES := [512, 180, 144]
const OUT := "res://icons/app_%d.png"

var _viewport: SubViewport
var _frames := 0

## One square of art, drawn to whatever size it is given.
class IconArt extends Control:
	func _draw() -> void:
		var w := size.x
		draw_rect(Rect2(Vector2.ZERO, size), Palette.color(&"desktop"))
		# The sign: red, white-edged, RD in white - the one on the lot.
		var sign_rect := Rect2(w * 0.27, w * 0.1, w * 0.46, w * 0.3)
		draw_rect(sign_rect, Palette.color(&"stamp"))
		draw_rect(sign_rect, Palette.color(&"paper"), false, maxf(2.0, w * 0.018))
		var font := ThemeDB.fallback_font
		var text_size := int(w * 0.21)
		var text_width := font.get_string_size("RD", HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x
		draw_string(font, Vector2(sign_rect.get_center().x - text_width * 0.5,
			sign_rect.get_center().y + text_size * 0.34), "RD", HORIZONTAL_ALIGNMENT_LEFT,
			-1, text_size, Palette.color(&"paper"))
		# The car, over the pale-blue ground line the lot sits on.
		var car := Rect2(w * 0.18, w * 0.38, w * 0.64, w * 0.5)
		CardTypeIcon.draw(self, car, true, Palette.color(&"card_back_mark"))
		draw_rect(Rect2(w * 0.1, w * 0.9, w * 0.8, w * 0.02), Palette.color(&"sticky"))

func _init() -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(SIZES[0], SIZES[0])
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	var art := IconArt.new()
	art.size = Vector2(_viewport.size)
	_viewport.add_child(art)

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 6:
		var big := _viewport.get_texture().get_image()
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://icons"))
		for side in SIZES:
			var image := big.duplicate() as Image
			if side != SIZES[0]:
				image.resize(side, side, Image.INTERPOLATE_LANCZOS)
			var path: String = OUT % side
			image.save_png(path)
			print("wrote %s" % path)
		quit()
	return false
