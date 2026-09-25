extends SceneTree
## Builds res://scenes/report.tscn - the end-of-shift screen.
##
## Every element here used to render at the engine's literal default: no
## panel style, no font-size override anywhere, four of the nine labels never
## even given a Palette color. It worked, in the sense that the numbers were
## on screen - but "worked" and "visible" are not the same claim, and this is
## the one screen a player stops to actually read every single shift.
##
## Structure now: a themed FULL-RECT ground (same dark Palette.bg the floor's
## felt uses, not Godot's default gray) with a fixed-width CARD centered on
## it, rather than nine labels stretched edge to edge across a 1920px screen.
## The one number that matters most - banked vs quota - is the largest text on
## the card after the title; everything else is a supporting detail below it,
## in descending emphasis.

func _init() -> void:
	var root := PanelContainer.new()
	root.name = "ReportPanel"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.set_script(load("res://scripts/view/report_panel.gd"))
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
	# A fixed width, not the full 1920 the old flat layout used - nine lines of
	# text stretched edge to edge across the whole screen read as sparse and
	# are slower to scan than the same lines held to a column you can take in
	# without moving your eyes sideways. Height is left at 0 (no minimum) so
	# the card is exactly as tall as its content, never padded or clipped.
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
	vbox.add_theme_constant_override("separation", 20)
	card_margin.add_child(vbox)
	vbox.owner = root

	# --- the headline: what happened, and by how much --------------------
	var title := _label(vbox, root, "TitleLabel", "CLOSING TIME", 60)
	title.theme_type_variation = &"Heading"
	title.unique_name_in_owner = true   # overridden to "YOU'RE FIRED" on a fatal shift
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_divider(vbox, root, "TitleRule")

	# The single most important number on the card - banked vs quota - gets
	# the second-largest type on the whole screen and its own centered line,
	# so it reads as the headline rather than one fact among nine.
	var banked := _label(vbox, root, "BankedLabel", "", 40)
	banked.unique_name_in_owner = true
	banked.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var bonus := _label(vbox, root, "BonusLabel", "", 26)
	bonus.unique_name_in_owner = true
	bonus.autowrap_mode = TextServer.AUTOWRAP_WORD
	bonus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_divider(vbox, root, "StatsRule")

	# --- the supporting detail, smaller and left-aligned ------------------
	var standing := _label(vbox, root, "StandingLabel", "", 28)
	standing.unique_name_in_owner = true

	var walkouts := _label(vbox, root, "WalkoutsLabel", "", 24)
	walkouts.unique_name_in_owner = true
	walkouts.autowrap_mode = TextServer.AUTOWRAP_WORD

	var customers := _label(vbox, root, "CustomersLabel", "", 22)
	customers.unique_name_in_owner = true

	var offers := _label(vbox, root, "OffersLabel", "", 22)
	offers.unique_name_in_owner = true

	var margin := _label(vbox, root, "MarginMovedLabel", "", 22)
	margin.unique_name_in_owner = true
	margin.autowrap_mode = TextServer.AUTOWRAP_WORD

	var lost := _label(vbox, root, "LostLabel", "", 22)
	lost.unique_name_in_owner = true
	lost.autowrap_mode = TextServer.AUTOWRAP_WORD

	_divider(vbox, root, "ButtonRule")

	# Centered, not stretched: a full-width button at the bottom of a 788px
	# content column reads as a bar, not a button you press.
	var button_wrap := CenterContainer.new()
	button_wrap.name = "ButtonWrap"
	vbox.add_child(button_wrap)
	button_wrap.owner = root

	var restart := Button.new()
	restart.name = "RestartButton"
	restart.text = "Continue"
	restart.custom_minimum_size = Vector2(360, 84)
	restart.add_theme_font_size_override("font_size", 32)
	restart.unique_name_in_owner = true
	button_wrap.add_child(restart)
	restart.owner = root

	var packed := PackedScene.new()
	packed.pack(root)
	ResourceSaver.save(packed, "res://scenes/report.tscn")
	print("saved report.tscn")
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

## A hairline between logical groups - title, headline number, supporting
## detail, the button - so the card reads as sections rather than nine lines
## in a row of identical weight. Not unique-named: nothing outside the
## builder ever needs to find one again.
##
## A styled PanelContainer, not a ColorRect: this report is a permanent child
## of the shift scene's HUD (hidden, not absent), and
## test_the_background_is_the_environment_not_a_control() bans ANY ColorRect
## anywhere under HUD, recursively, regardless of visibility - the G1 bug it
## guards against was a full-rect ColorRect eating clicks meant for the table.
## A PanelContainer achieves the identical solid-strip look through the same
## StyleBoxFlat mechanism Card's own background already uses, without being
## the class that guard is actually watching for.
func _divider(parent: Node, root: Node, node_name: String) -> void:
	var rule := PanelContainer.new()
	rule.name = node_name
	rule.custom_minimum_size = Vector2(0, 2)
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.color(&"neutral_2")
	rule.add_theme_stylebox_override("panel", style)
	parent.add_child(rule)
	rule.owner = root
