extends SceneTree
## Builds res://scenes/deck_viewer.tscn - the shop's "see your whole deck"
## overlay. DeckGrid is EMPTY here and filled at runtime by deck_viewer.gd,
## the same shape ShelfRow/DeckRow already use for content that changes
## every visit - here it is the same content in an ordinary visit, but a
## deck bought into or dropped from mid-run still needs a fresh build.

const COLUMNS := 6

func _init() -> void:
	var root := PanelContainer.new()
	root.name = "DeckViewer"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.visible = false
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Palette.color(&"bg")
	root.add_theme_stylebox_override("panel", panel_style)
	root.set_script(load("res://scripts/view/deck_viewer.gd"))

	var margin := MarginContainer.new()
	margin.name = "Margin"
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 48)
	root.add_child(margin)
	margin.owner = root

	var col := VBoxContainer.new()
	col.name = "Column"
	col.add_theme_constant_override("separation", 16)
	margin.add_child(col)
	col.owner = root

	var title := Label.new()
	title.name = "DeckViewerTitle"
	title.text = "YOUR DECK"
	title.unique_name_in_owner = true
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Palette.color(&"text"))
	col.add_child(title)
	title.owner = root

	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	scroll.owner = root

	var grid := GridContainer.new()
	grid.name = "DeckGrid"
	grid.unique_name_in_owner = true
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 20)
	scroll.add_child(grid)
	grid.owner = root

	var close := Button.new()
	close.name = "DeckCloseButton"
	close.text = "CLOSE"
	close.unique_name_in_owner = true
	close.custom_minimum_size = Vector2(240, 64)
	close.add_theme_font_size_override("font_size", 24)
	col.add_child(close)
	close.owner = root

	var packed := PackedScene.new()
	packed.pack(root)
	var err := ResourceSaver.save(packed, "res://scenes/deck_viewer.tscn")
	if err != OK:
		push_error("failed to save deck_viewer.tscn: %d" % err)
		quit(1)
		return
	print("saved deck_viewer.tscn")
	root.free()
	quit(0)
