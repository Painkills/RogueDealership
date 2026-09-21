extends SceneTree
## Builds res://scenes/cards/shop_card_button.tscn - a real card face you can
## click, used for both the shelf ("click to buy") and the deck browser
## ("click to manage"). Same SubViewport-to-TextureRect trick
## card_preview_2d.tscn already established, wrapped in a FLAT Button
## instead of a plain Control - flat drops the engine's default button
## panel styling, so the card face itself is the only thing you see, and
## the whole card is the click target with no chrome of its own.

const CARD_SIZE := Vector2(180, 252)   ## exactly the 2.5 x 3.5 aspect every card uses

func _init() -> void:
	var root := Button.new()
	root.name = "ShopCardButton"
	root.custom_minimum_size = CARD_SIZE
	root.size = CARD_SIZE
	root.flat = true
	# The exact bug CardPreview2D already shipped once: a SubViewport-fed
	# TextureRect can paint past its own logical rect on the Web
	# (gl_compatibility) renderer specifically, no matter how correctly every
	# Control's size and position measure headless. clip_contents forecloses
	# it regardless of cause - see card_preview_2d.tscn's own fix.
	root.clip_contents = true
	root.set_script(load("res://scripts/view/shop_card_button.gd"))

	var texture := TextureRect.new()
	texture.name = "TextureRect"
	texture.set_anchors_preset(Control.PRESET_FULL_RECT)
	# IGNORE: a child that ate the click would make the button underneath it
	# unclickable - the same rule the build badge follows for the same reason.
	texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(texture)
	texture.owner = root

	var viewport := SubViewport.new()
	viewport.name = "SubViewport"
	viewport.disable_3d = true
	viewport.size = Vector2i(500, 700)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.owner = root

	var front: Control = (load("res://scenes/cards/card_front_2d.tscn") as PackedScene) \
		.instantiate()
	front.name = "CardFront"
	viewport.add_child(front)
	front.owner = root

	var packed := PackedScene.new()
	packed.pack(root)
	var err := ResourceSaver.save(packed, "res://scenes/cards/shop_card_button.tscn")
	if err != OK:
		push_error("failed to save shop_card_button.tscn: %d" % err)
		quit(1)
		return
	print("saved shop_card_button.tscn")
	root.free()
	quit(0)
