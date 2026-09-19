extends SceneTree
## Builds res://scenes/cards/card_back_2d.tscn - the face-down side of a card:
## a solid muted color plus one big wrench, drawn the same 500x700-then-
## minified way card_front_2d.tscn is (see that builder's own comment on why).
##
## One shared scene and one shared look for both types - CardBack2D.setup()
## takes no argument, since a face-down card has nothing to tell apart.

const W := 500
const H := 700

func _init() -> void:
	var root := Control.new()
	root.name = "CardBack"
	root.custom_minimum_size = Vector2(W, H)
	root.size = Vector2(W, H)
	root.set_script(load("res://scripts/view/card_back_2d.gd"))

	var bg := ColorRect.new()
	bg.name = "Background"
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Palette.color(&"neutral_2")
	root.add_child(bg)
	bg.owner = root

	# Centered, not stretched - CardTypeIcon.draw() scales to whatever rect it
	# is handed with no aspect correction, the same reason BodyIcon on the
	# front is held to a square custom_minimum_size instead of filling a row.
	var wrap := CenterContainer.new()
	wrap.name = "IconWrap"
	wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(wrap)
	wrap.owner = root

	var icon := Control.new()
	icon.name = "TypeIcon"
	icon.set_script(load("res://scripts/view/card_type_icon_control.gd"))
	icon.custom_minimum_size = Vector2(320, 320)
	wrap.add_child(icon)
	icon.owner = root

	var packed := PackedScene.new()
	packed.pack(root)
	var err := ResourceSaver.save(packed, "res://scenes/cards/card_back_2d.tscn")
	if err != OK:
		push_error("failed to save card_back_2d.tscn: %d" % err)
		quit(1)
		return
	print("saved card_back_2d.tscn")
	root.free()
	quit(0)
