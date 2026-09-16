extends SceneTree
## Builds res://scenes/run_summary.tscn - the end-of-run high score screen.
##
## Structurally identical to build_report_scene.gd's own card-on-a-dark-
## ground layout, since a player who just finished a run already knows how to
## read this shape from every shift they closed to get here.

func _init() -> void:
	var root := PanelContainer.new()
	root.name = "RunSummaryPanel"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.set_script(load("res://scripts/view/run_summary_panel.gd"))
	var ground := StyleBoxFlat.new()
	ground.bg_color = Palette.color(&"bg")
	root.add_theme_stylebox_override("panel", ground)

	var wrap := CenterContainer.new()
	wrap.name = "CenterWrap"
	wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(wrap)
	wrap.owner = root

	var card := PanelContainer.new()
	card.name = "Card"
	card.custom_minimum_size = Vector2(900, 0)
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Palette.color(&"panel_hi")
	card_style.border_width_left = 2
	card_style.border_width_top = 2
	card_style.border_width_right = 2
	card_style.border_width_bottom = 2
	card_style.border_color = Palette.color(&"neutral_3")
	card.add_theme_stylebox_override("panel", card_style)
	wrap.add_child(card)
	card.owner = root

	var card_margin := MarginContainer.new()
	card_margin.name = "CardMargin"
	for side in ["left", "top", "right", "bottom"]:
		card_margin.add_theme_constant_override("margin_" + side, 56)
	card.add_child(card_margin)
	card_margin.owner = root

	var vbox := VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.add_theme_constant_override("separation", 18)
	card_margin.add_child(vbox)
	vbox.owner = root

	var title := _label(vbox, root, "TitleLabel", "RUN COMPLETE", 60)
	title.unique_name_in_owner = true   # overridden to "YOU'RE FIRED" when standing hit 0
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_divider(vbox, root, "TitleRule")

	# --- the five scoring categories, one line each, in the order the player
	# earned them across the run: what you made, what you kept, what it cost.
	var margin := _label(vbox, root, "MarginLabel", "", 24)
	margin.unique_name_in_owner = true

	var standing := _label(vbox, root, "StandingLabel", "", 24)
	standing.unique_name_in_owner = true

	var standing_lost := _label(vbox, root, "StandingLostLabel", "", 24)
	standing_lost.unique_name_in_owner = true

	var walkouts := _label(vbox, root, "WalkoutsLabel", "", 24)
	walkouts.unique_name_in_owner = true

	var combo := _label(vbox, root, "ComboLabel", "", 24)
	combo.unique_name_in_owner = true

	_divider(vbox, root, "TotalRule")

	# The headline number, same emphasis the per-shift report gives its own
	# banked-vs-quota line - the single biggest thing on the card besides the
	# title itself.
	var total := _label(vbox, root, "TotalLabel", "", 44)
	total.unique_name_in_owner = true
	total.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	total.add_theme_color_override("font_color", Palette.color(&"margin"))

	_divider(vbox, root, "ButtonRule")

	var button_wrap := CenterContainer.new()
	button_wrap.name = "ButtonWrap"
	vbox.add_child(button_wrap)
	button_wrap.owner = root

	var restart := Button.new()
	restart.name = "RestartButton"
	restart.text = "Start New Run"
	restart.custom_minimum_size = Vector2(360, 84)
	restart.add_theme_font_size_override("font_size", 32)
	restart.unique_name_in_owner = true
	button_wrap.add_child(restart)
	restart.owner = root

	var packed := PackedScene.new()
	packed.pack(root)
	var err := ResourceSaver.save(packed, "res://scenes/run_summary.tscn")
	if err != OK:
		push_error("failed to save run_summary.tscn: %d" % err)
		quit(1)
		return
	print("saved run_summary.tscn")
	root.free()
	quit(0)

func _label(parent: Node, root: Node, node_name: String, text: String,
		size: int) -> Label:
	var l := Label.new()
	l.name = node_name
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	parent.add_child(l)
	l.owner = root
	return l

## Same PanelContainer-as-hairline trick build_report_scene.gd uses: a styled
## PanelContainer clears the "no ColorRect anywhere under HUD" guard while
## still achieving a flat-color strip via its own StyleBoxFlat panel.
func _divider(parent: Node, root: Node, node_name: String) -> void:
	var rule := PanelContainer.new()
	rule.name = node_name
	rule.custom_minimum_size = Vector2(0, 2)
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.color(&"neutral_2")
	rule.add_theme_stylebox_override("panel", style)
	parent.add_child(rule)
	rule.owner = root
