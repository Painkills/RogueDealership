extends RefCounted
## A screen embedded in another scene (the end-of-day report in the table's
## HUD, the store and the boss's email in the run) must look like its own
## scene, not like it did the last time the scene around it was rebuilt.
##
## The builders instance each screen and pack the scene around it, and the
## packer bakes the screen's root background into that outer scene as an
## override. Rebuild the screen alone and the outer scene keeps the stale copy
## - which is how the new end-of-day report once came up on the old light-grey
## ground: correct in its own scene, wrong everywhere it was actually shown.
var h: Harness

const OUTER := ["res://scenes/shift.tscn", "res://scenes/run.tscn",
	"res://scenes/shop.tscn"]

func test_an_embedded_screen_wears_its_own_scenes_background() -> void:
	for outer_path in OUTER:
		var outer := (load(outer_path) as PackedScene).instantiate()
		for node in _all(outer):
			if not (node is PanelContainer) or node.scene_file_path == "":
				continue
			var fresh := (load(node.scene_file_path) as PackedScene).instantiate() as Control
			var mine := (node as Control).get_theme_stylebox("panel") as StyleBoxFlat
			var theirs := fresh.get_theme_stylebox("panel") as StyleBoxFlat
			if mine != null and theirs != null:
				h.eq("%s in %s wears %s's own background (rebuild %s after it)"
					% [node.name, outer_path.get_file(), node.scene_file_path.get_file(),
						outer_path.get_file()], mine.bg_color, theirs.bg_color)
			fresh.free()
		outer.free()

func _all(node: Node) -> Array[Node]:
	var out: Array[Node] = [node]
	for child in node.get_children():
		out.append_array(_all(child))
	return out
