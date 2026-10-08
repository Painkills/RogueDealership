extends SceneTree
## Draws every archetype glyph (ArchetypeIcon) to a PNG contact sheet, each one
## large and again at about the size it has on a folder at the side of the floor,
## beside the archetype that uses it - to look at after drawing or changing one.
## Needs a window (not --headless), which is what draws anything.
##
##     godot --path game --script res://tools/render_archetype_icons.gd -- out=C:/path/sheet.png

const CELL := Vector2(260, 330)
const BIG := 200.0
const SMALL := 50.0
const COLUMNS := 6

var _out := "user://archetype_icons.png"
var _viewport: SubViewport
var _frames := 0

func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			_out = arg.substr(4)
	var names: Array[StringName] = ArchetypeIcon.NAMES
	var rows := ceili(float(names.size()) / COLUMNS)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(roundi(CELL.x * COLUMNS), roundi(CELL.y * rows))
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	var bg := ColorRect.new()
	bg.color = Color("93a9c9")
	bg.size = Vector2(_viewport.size)
	_viewport.add_child(bg)
	# Every archetype file, not only the pool's: a boss comes in by a shift.
	var everyone: Array[CustomerArchetype] = []
	for file in DirAccess.get_files_at("res://data/archetypes"):
		if file.ends_with(".tres"):
			everyone.append(load("res://data/archetypes/" + file))
	for i in range(names.size()):
		var cell := Vector2(i % COLUMNS, i / COLUMNS) * CELL
		_tile(names[i], cell + Vector2(30, 20), BIG)
		_tile(names[i], cell + Vector2(30, 240), SMALL)
		var who: Array[String] = []
		for a in everyone:
			if a.icon == names[i]:
				who.append(a.display_name)
		var label := Label.new()
		label.text = "%s\n%s" % [names[i], ", ".join(who) if not who.is_empty() else "(unused)"]
		label.position = cell + Vector2(92, 240)
		label.add_theme_font_size_override("font_size", 18)
		label.add_theme_color_override("font_color", Color("101828"))
		_viewport.add_child(label)

func _tile(icon: StringName, at: Vector2, side: float) -> void:
	var tile := PhotoFrame.new()
	tile.size = Vector2(side, side)
	tile.position = at
	tile.icon = icon
	_viewport.add_child(tile)

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 6:
		_viewport.get_texture().get_image().save_png(_out)
		print("wrote %s" % _out)
		quit()
	return false
