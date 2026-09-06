extends SceneTree
## Builds res://scenes/shop.tscn - the between-shifts screen.
##
## A plain 2D Control. G2's bar is mechanical - add, remove or upgrade a card -
## and says nothing about presentation, so this follows the panel style G1 used
## before the 3D pivot rather than staging a second 3D scene.
##
## The two lists are EMPTY here and filled at runtime: what is on the shelf and
## what is in the deck both change every visit.

func _init() -> void:
	var root := PanelContainer.new()
	root.name = "ShopScreen"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	# STOP, not IGNORE: this sits over a 3D table whose colliders do not stop
	# existing just because the table is hidden.
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.set_script(load("res://scripts/view/shop_screen.gd"))

	var margin := MarginContainer.new()
	margin.name = "Margin"
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 48)
	root.add_child(margin)
	margin.owner = root

	var col := VBoxContainer.new()
	col.name = "Column"
	col.add_theme_constant_override("separation", 18)
	margin.add_child(col)
	col.owner = root

	_label(col, root, "TitleLabel", "BETWEEN SHIFTS", 44, &"text")
	_label(col, root, "ShiftLabel", "shift 1 of 5", 28, &"text_dim")
	_label(col, root, "MoneyLabel", "$0 to spend", 34, &"margin")
	_label(col, root, "OnShelfTitle", "ON THE SHELF", 24, &"text_dim")

	var offers := VBoxContainer.new()
	offers.name = "OfferRows"
	offers.unique_name_in_owner = true
	offers.add_theme_constant_override("separation", 8)
	col.add_child(offers)
	offers.owner = root

	_label(col, root, "DeckTitle", "YOUR DECK", 24, &"text_dim")

	var deck_scroll := ScrollContainer.new()
	deck_scroll.name = "DeckScroll"
	deck_scroll.custom_minimum_size = Vector2(0, 420)
	col.add_child(deck_scroll)
	deck_scroll.owner = root

	var deck_rows := VBoxContainer.new()
	deck_rows.name = "DeckRows"
	deck_rows.unique_name_in_owner = true
	deck_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deck_rows.add_theme_constant_override("separation", 6)
	deck_scroll.add_child(deck_rows)
	deck_rows.owner = root

	_label(col, root, "LogLabel", "", 26, &"alert")

	var done := Button.new()
	done.name = "DoneButton"
	done.text = "OPEN THE FLOOR"
	done.custom_minimum_size = Vector2(420, 96)
	done.add_theme_font_size_override("font_size", 32)
	done.unique_name_in_owner = true
	col.add_child(done)
	done.owner = root

	var packed := PackedScene.new()
	packed.pack(root)
	var err := ResourceSaver.save(packed, "res://scenes/shop.tscn")
	if err != OK:
		push_error("failed to save shop.tscn: %d" % err)
		quit(1)
		return
	print("saved shop.tscn")
	root.free()
	quit(0)

func _label(parent: Node, root: Node, node_name: String, text: String,
		size: int, role: StringName) -> void:
	var l := Label.new()
	l.name = node_name
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Palette.color(role))
	l.unique_name_in_owner = true
	parent.add_child(l)
	l.owner = root
