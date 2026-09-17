extends SceneTree
## Builds res://scenes/cards/speech_bubble_2d.tscn - a customer's own words,
## rendered as 2D UI and used as the texture for a small billboard plane that
## floats above their card in 3D space (see customer_card_3d.tscn's own
## BubbleMesh/BubbleViewport, added by hand since that scene is not
## builder-generated).
##
## A separate small face rather than a row baked into customer_front_2d.tscn:
## that face is a fixed 500x700 texture mapped onto the fixed-size CardMesh
## quad, so nothing drawn on it can ever appear OUTSIDE the card's own edges -
## "appear ABOVE the customer cards" needs geometry the card's own texture
## cannot provide.

func _init() -> void:
	var canvas: Vector2 = Vector2(SpeechBubble.CANVAS_SIZE)
	var root := Control.new()
	root.name = "SpeechBubble"
	root.set_script(load("res://scripts/view/speech_bubble.gd"))
	root.custom_minimum_size = canvas
	root.size = canvas
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.position = Vector2.ZERO
	panel.size = Vector2(canvas.x, canvas.y - SpeechBubble.TAIL_HEIGHT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.color(&"panel_hi")
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Palette.color(&"action")
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	root.add_child(panel)
	panel.owner = root

	var label := Label.new()
	label.name = "Label"
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", Palette.color(&"text"))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The longest dialogue line in data/demands/*.tres, so this scene shows its
	# own worst case in the editor - the same discipline every other card face
	# in this project follows.
	label.text = "\"The place on Dundas does this for less.\""
	panel.add_child(label)
	label.owner = root

	var timer := Timer.new()
	timer.name = "HideTimer"
	timer.one_shot = true
	root.add_child(timer)
	timer.owner = root

	var packed := PackedScene.new()
	packed.pack(root)
	var err := ResourceSaver.save(packed, "res://scenes/cards/speech_bubble_2d.tscn")
	if err != OK:
		push_error("failed to save speech_bubble_2d.tscn: %d" % err)
		quit(1)
		return
	print("saved speech_bubble_2d.tscn")
	root.free()
	quit(0)
