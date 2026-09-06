extends SceneTree
## Builds res://scenes/run.tscn - the main scene, which hosts the shift and the
## shop and switches between them.

func _init() -> void:
	var root := Node.new()
	root.name = "Run"
	root.set_script(load("res://scripts/view/run_controller.gd"))

	var shift_view: Node = (load("res://scenes/shift.tscn") as PackedScene).instantiate()
	shift_view.name = "ShiftView"
	root.add_child(shift_view)
	shift_view.owner = root

	var shop_view: Control = (load("res://scenes/shop.tscn") as PackedScene).instantiate()
	shop_view.name = "ShopView"
	shop_view.visible = false
	root.add_child(shop_view)
	shop_view.owner = root

	var packed := PackedScene.new()
	packed.pack(root)
	var err := ResourceSaver.save(packed, "res://scenes/run.tscn")
	if err != OK:
		push_error("failed to save run.tscn: %d" % err)
		quit(1)
		return
	print("saved run.tscn")
	root.free()
	quit(0)
