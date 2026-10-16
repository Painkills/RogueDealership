extends SceneTree
## Saves a placeholder picture (tools/card_art_painter.gd) for every card in the
## pool that has no art yet, to res://art/cards/<id>.png - and a contact sheet of
## them all to user://card_art_sheet.png to look at. Hooking each one up to its
## card is a separate step (CardDef.art), so a real picture is never overwritten.
##
##   godot --path game --script res://tools/render_card_art.gd

const DIR := "res://art/cards"

func _init() -> void:
	_go.call_deferred()

func _go() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var pool: CardPool = load("res://data/card_pool.tres")
	var vp := SubViewport.new()
	vp.size = Vector2i(900, 338)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var painter := Control.new()
	painter.set_script(load("res://tools/card_art_painter.gd"))
	painter.size = Vector2(900, 338)
	vp.add_child(painter)
	var shots: Array[Image] = []
	for def in pool.cards:
		if def.art != null and not def.art.resource_path.ends_with(".png"):
			continue
		painter.set("id", String(def.id))
		painter.queue_redraw()
		for _i in range(3):
			await process_frame
		var img := vp.get_texture().get_image()
		img.save_png("%s/%s.png" % [DIR, def.id])
		shots.append(img)
		print("saved ", def.id)
	# A contact sheet, four across.
	var cols := 4
	var rows := ceili(shots.size() / float(cols))
	var sheet := Image.create(cols * 450 + 10, rows * 170 + 10, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("2b3440"))
	for i in range(shots.size()):
		var small := shots[i].duplicate() as Image
		small.convert(Image.FORMAT_RGBA8)
		small.resize(440, 165)
		sheet.blit_rect(small, Rect2i(Vector2i.ZERO, small.get_size()),
			Vector2i(10 + (i % cols) * 450, 10 + (i / cols) * 170))
	sheet.save_png("user://card_art_sheet.png")
	print("%d pictures" % shots.size())
	quit()
