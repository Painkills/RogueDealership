extends SceneTree
## Builds res://scenes/shop.tscn - the between-shifts screen.
##
## A plain 2D Control. G2's bar is mechanical - add, remove or upgrade a card -
## and says nothing about presentation, so this follows the panel style G1 used
## before the 3D pivot rather than staging a second 3D scene.
##
## The three lists are EMPTY here and filled at runtime: what is on the shelf,
## what is in the deck, and which of the deck's cards may be upgraded all
## change every visit.
##
## PreviewColumn/CardPreview shows whatever row you are currently hovering, on
## the exact same card face the floor renders - a plain 2D face this time
## (card_preview_2d.tscn), since there is no 3D table here to render it onto.

const PREVIEW_SCENE := "res://scenes/cards/card_preview_2d.tscn"

func _init() -> void:
	var root := PanelContainer.new()
	root.name = "ShopScreen"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	# STOP, not IGNORE: this sits over a 3D table whose colliders do not stop
	# existing just because the table is hidden.
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.set_script(load("res://scripts/view/shop_screen.gd"))
	# Themed rather than left at the engine's default gray PanelContainer style
	# - the one thing this screen shared with the report screen before either
	# got a design pass, and the most direct fix for "make the menus look like
	# they belong to this game" that touches only one property.
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Palette.color(&"bg")
	root.add_theme_stylebox_override("panel", panel_style)

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

	# --- the row-lists on the left, the preview on the right ----------------
	# A side-by-side split rather than a taller stack: DeckScroll's 260px cap
	# exists because HEIGHT is the tight budget in this layout (see its own
	# comment below), and a preview pane costs WIDTH instead, which this
	# screen has never been short of. LogLabel and DoneButton stay direct
	# children of Column, unmoved - drive_run.gd pins Margin/Column/DoneButton
	# and Margin/Column/LogLabel by exact path.
	var body := HBoxContainer.new()
	body.name = "ShopBody"
	body.add_theme_constant_override("separation", 32)
	col.add_child(body)
	body.owner = root

	var left := VBoxContainer.new()
	left.name = "LeftColumn"
	# A hard cap, not EXPAND_FILL: unconstrained, this column claimed every
	# pixel the preview did not strictly need, stretching a single line of
	# button text across 1500+ px of a 1920-wide screen and squeezing the
	# hover preview down to a bare 260px sliver jammed against the right
	# margin with nothing to spare - "too wide" broke the preview's own
	# visibility, not just this column's own good looks. Measured worst
	# case (longest product name, both price buttons) is ~580px; 700 leaves
	# real headroom without giving up the room the preview needs to read as
	# a normal part of the screen rather than an afterthought at the edge.
	left.custom_minimum_size = Vector2(700, 0)
	left.add_theme_constant_override("separation", 18)
	body.add_child(left)
	left.owner = root

	_label(left, root, "OnShelfTitle", "ON THE SHELF", 24, &"text_dim")

	var offers := VBoxContainer.new()
	offers.name = "OfferRows"
	offers.unique_name_in_owner = true
	offers.add_theme_constant_override("separation", 8)
	left.add_child(offers)
	offers.owner = root

	_label(left, root, "DeckTitle", "YOUR DECK", 24, &"text_dim")

	var deck_scroll := ScrollContainer.new()
	deck_scroll.name = "DeckScroll"
	# A Control is never sized below its own minimum, anchors or not - so at 420
	# this plus the labels around it summed to 1095 against the 984 the 48px
	# margins leave inside a 1080-tall viewport, and DoneButton rendered 63px
	# below the bottom edge with a real 14-card starter deck. 260 leaves 49px of
	# headroom at the current shop_offers (3) rather than the ~9px a smaller cut
	# to 300 would, measured with tools/probe_shop_layout.gd against the actual
	# built scene, and it still shows about four deck rows before the list
	# itself needs to scroll - which is what the ScrollContainer is there for.
	# A ScrollContainer's minimum size is exactly this constant, never its
	# content's, so this number is independent of how large the deck grows.
	deck_scroll.custom_minimum_size = Vector2(0, 260)
	left.add_child(deck_scroll)
	deck_scroll.owner = root

	var deck_rows := VBoxContainer.new()
	deck_rows.name = "DeckRows"
	deck_rows.unique_name_in_owner = true
	deck_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deck_rows.add_theme_constant_override("separation", 6)
	deck_scroll.add_child(deck_rows)
	deck_rows.owner = root

	var preview_col := VBoxContainer.new()
	preview_col.name = "PreviewColumn"
	preview_col.add_theme_constant_override("separation", 12)
	# Takes whatever LeftColumn's hard cap leaves behind, rather than the bare
	# 260px its own content needs - the whole point of capping LeftColumn was
	# to give this room to actually read as part of the screen.
	preview_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_col.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(preview_col)
	preview_col.owner = root

	var preview_title := _label(preview_col, root, "PreviewTitle", "PREVIEW", 24, &"text_dim")
	preview_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var preview: Control = (load(PREVIEW_SCENE) as PackedScene).instantiate()
	preview.name = "CardPreview"
	preview.unique_name_in_owner = true
	# A fixed-size face, not a stretchy one: without this a VBoxContainer
	# widened to fill the freed-up space would stretch the card's own 260x364
	# proportions right along with it.
	preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	preview_col.add_child(preview)
	preview.owner = root

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
		size: int, role: StringName) -> Label:
	var l := Label.new()
	l.name = node_name
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Palette.color(role))
	l.unique_name_in_owner = true
	parent.add_child(l)
	l.owner = root
	return l
