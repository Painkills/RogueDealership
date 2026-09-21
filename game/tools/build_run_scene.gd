extends SceneTree
## Builds res://scenes/run.tscn - the main scene, which hosts the shift and the
## shop and switches between them.

const DECK_VIEWER_SCENE := "res://scenes/deck_viewer.tscn"

func _init() -> void:
	var root := Node.new()
	root.name = "Run"
	root.set_script(load("res://scripts/view/run_controller.gd"))

	# Added first, so a picker chosen() before the very first shift's own
	# setup() runs still covers a floor that has never been built yet, the
	# same "on top of whatever's behind it" layering the summary view uses.
	var picker_view: Control = \
		(load("res://scenes/shift_picker.tscn") as PackedScene).instantiate()
	picker_view.name = "ShiftPickerView"
	picker_view.visible = false
	root.add_child(picker_view)
	picker_view.owner = root

	var shift_view: Node = (load("res://scenes/shift.tscn") as PackedScene).instantiate()
	shift_view.name = "ShiftView"
	root.add_child(shift_view)
	shift_view.owner = root

	var shop_view: Control = (load("res://scenes/shop.tscn") as PackedScene).instantiate()
	shop_view.name = "ShopView"
	shop_view.visible = false
	root.add_child(shop_view)
	shop_view.owner = root

	# Added after both, so it draws on top of whichever of them is visible
	# when the run ends - same layering trick as the shift's own ReportOverlay
	# covering the floor underneath it.
	var summary_view: Control = \
		(load("res://scenes/run_summary.tscn") as PackedScene).instantiate()
	summary_view.name = "RunSummaryView"
	summary_view.visible = false
	root.add_child(summary_view)
	summary_view.owner = root

	# Added last of the four+one, so it draws on top of literally anything
	# beneath it - reachable from both the shop and the floor, so it cannot
	# belong to either of them (see run_controller.gd's own comment).
	var deck_viewer: Control = (load(DECK_VIEWER_SCENE) as PackedScene).instantiate()
	deck_viewer.name = "DeckViewer"
	root.add_child(deck_viewer)
	deck_viewer.owner = root

	# A permanent corner badge, not something either screen owns - so it
	# survives switching between them for free and can never be the thing a
	# screen's own layout work accidentally covers up. Its own CanvasLayer,
	# stacked above the shift's HUD layer, so it is never buried under a
	# customer card at the table's own draw order.
	var badge_layer := CanvasLayer.new()
	badge_layer.name = "BuildBadge"
	badge_layer.layer = 100
	root.add_child(badge_layer)
	badge_layer.owner = root

	var badge := Label.new()
	badge.name = "BuildLabel"
	badge.text = BuildInfo.LABEL
	badge.add_theme_font_size_override("font_size", 18)
	badge.add_theme_color_override("font_color", Palette.color(&"text_dim"))
	badge.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	badge.add_theme_constant_override("shadow_offset_x", 2)
	badge.add_theme_constant_override("shadow_offset_y", 2)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.autowrap_mode = TextServer.AUTOWRAP_OFF
	# Label already defaults to IGNORE, so this changes nothing today - stated
	# explicitly anyway, since the exact bug it heads off (a full-rect
	# ColorRect eating clicks meant for the table, already caught once in
	# this project's own HUD) is one a LATER edit could reintroduce the
	# moment this badge stops being a plain Label.
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	badge.offset_left = -260
	badge.offset_top = -26
	badge.offset_right = -8
	badge.offset_bottom = -6
	badge_layer.add_child(badge)
	badge.owner = root

	# Top-right, same layer as the badge (always on screen, over any of the
	# four screens or the deck viewer itself) - a reliable click target for
	# "your deck" that does not depend on hitting the 3D draw pile's own
	# pick shape, which is a real click target too (see shift_controller.gd's
	# _draw_zone wiring) but a much smaller and less forgiving one.
	var view_deck_btn := Button.new()
	view_deck_btn.name = "ViewDeckCornerButton"
	view_deck_btn.text = "VIEW DECK"
	view_deck_btn.unique_name_in_owner = true
	view_deck_btn.custom_minimum_size = Vector2(200, 56)
	view_deck_btn.add_theme_font_size_override("font_size", 22)
	view_deck_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	view_deck_btn.offset_left = -216
	view_deck_btn.offset_top = 20
	view_deck_btn.offset_right = -16
	view_deck_btn.offset_bottom = 76
	badge_layer.add_child(view_deck_btn)
	view_deck_btn.owner = root

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
