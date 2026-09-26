class_name AppWindow extends RefCounted
## Every report and menu in the game is something on a screen: the boss's
## email, the employee portal, the dealership system's end-of-day report, a
## dialog box. They are all built in this one window, so they read as apps on
## the same computer rather than as menus laid over the game.
##
## Builder-side: these make plain nodes, owned by whatever scene is being
## built, and nothing here runs at play time.

const RADIUS := 14
const TITLE_BAR_H := 46
const LIGHT := 14.0

## The desktop behind a window - opaque for a screen of its own, see-through
## for one that pops up over the floor.
static func desktop(root: Control, alpha: float = 1.0) -> void:
	var ground := StyleBoxFlat.new()
	ground.bg_color = Color(Palette.color(&"desktop"), alpha)
	root.add_theme_stylebox_override("panel", ground)

## A window, centred in `parent`: a title bar with its three lights and a
## title, then - when `url` is given - a browser's address bar, then its body.
## Returns {"window", "body"}; the caller fills "body", a VBoxContainer inside
## `margin` pixels of padding.
static func build(parent: Node, owner: Node, node_name: String, title: String,
		size: Vector2, url: String = "", margin: int = 32) -> Dictionary:
	var centre := CenterContainer.new()
	centre.name = node_name + "Centre"
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(centre)
	centre.owner = owner

	var window := PanelContainer.new()
	window.name = node_name
	window.custom_minimum_size = size
	window.unique_name_in_owner = true
	var frame := StyleBoxFlat.new()
	frame.bg_color = Palette.color(&"panel")
	frame.border_color = Palette.color(&"neutral_3")
	frame.set_border_width_all(1)
	frame.set_corner_radius_all(RADIUS)
	frame.shadow_color = Color(0, 0, 0, 0.45)
	frame.shadow_size = 36
	frame.shadow_offset = Vector2(0, 12)
	window.add_theme_stylebox_override("panel", frame)
	centre.add_child(window)
	window.owner = owner

	var col := VBoxContainer.new()
	col.name = "WindowColumn"
	col.add_theme_constant_override("separation", 0)
	window.add_child(col)
	col.owner = owner

	_title_bar(col, owner, title)
	if url != "":
		_address_bar(col, owner, url)

	var pad := MarginContainer.new()
	pad.name = "Body"
	pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["left", "top", "right", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, margin)
	col.add_child(pad)
	pad.owner = owner

	var body := VBoxContainer.new()
	body.name = "Content"
	body.add_theme_constant_override("separation", 16)
	pad.add_child(body)
	body.owner = owner
	return {"window": window, "body": body}

## Grey, rounded across the top, with the three window lights on the left and
## the app's name in the middle.
static func _title_bar(col: Node, owner: Node, title: String) -> void:
	var bar := PanelContainer.new()
	bar.name = "TitleBar"
	bar.custom_minimum_size = Vector2(0, TITLE_BAR_H)
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.color(&"paper_shade")
	style.corner_radius_top_left = RADIUS - 1
	style.corner_radius_top_right = RADIUS - 1
	style.border_color = Palette.color(&"neutral_2")
	style.border_width_bottom = 1
	style.content_margin_left = 18
	style.content_margin_right = 18
	bar.add_theme_stylebox_override("panel", style)
	col.add_child(bar)
	bar.owner = owner

	var row := HBoxContainer.new()
	row.name = "Row"
	row.add_theme_constant_override("separation", 8)
	bar.add_child(row)
	row.owner = owner

	var lights := HBoxContainer.new()
	lights.name = "Lights"
	lights.add_theme_constant_override("separation", 8)
	lights.alignment = BoxContainer.ALIGNMENT_BEGIN
	lights.custom_minimum_size = Vector2(90, 0)
	row.add_child(lights)
	lights.owner = owner
	for role in [&"stamp", &"brass", &"patience_ok"]:
		var dot := Panel.new()
		dot.name = "Light"
		dot.custom_minimum_size = Vector2(LIGHT, LIGHT)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var circle := StyleBoxFlat.new()
		circle.bg_color = Palette.color(role)
		circle.set_corner_radius_all(int(LIGHT * 0.5))
		dot.add_theme_stylebox_override("panel", circle)
		lights.add_child(dot)
		dot.owner = owner

	var label := Label.new()
	label.name = "WindowTitle"
	label.text = title
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 19)
	label.add_theme_color_override("font_color", Palette.color(&"text_dim"))
	row.add_child(label)
	label.owner = owner

	# As wide as the lights, so the title sits in the true middle of the bar.
	var balance := Control.new()
	balance.name = "Balance"
	balance.custom_minimum_size = Vector2(90, 0)
	row.add_child(balance)
	balance.owner = owner

## A browser's back and forward, and the address of the page you are on.
static func _address_bar(col: Node, owner: Node, url: String) -> void:
	var bar := PanelContainer.new()
	bar.name = "AddressBar"
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.color(&"panel_hi")
	style.border_color = Palette.color(&"neutral_2")
	style.border_width_bottom = 1
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	bar.add_theme_stylebox_override("panel", style)
	col.add_child(bar)
	bar.owner = owner

	var row := HBoxContainer.new()
	row.name = "Row"
	row.add_theme_constant_override("separation", 14)
	bar.add_child(row)
	row.owner = owner

	for glyph in ["‹", "›"]:
		var nav := Label.new()
		nav.name = "Nav"
		nav.text = glyph
		nav.add_theme_font_size_override("font_size", 30)
		nav.add_theme_color_override("font_color", Palette.color(&"neutral_3"))
		nav.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(nav)
		nav.owner = owner

	var omnibox := PanelContainer.new()
	omnibox.name = "Omnibox"
	omnibox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pill := StyleBoxFlat.new()
	pill.bg_color = Palette.color(&"panel")
	pill.border_color = Palette.color(&"neutral_3")
	pill.set_border_width_all(1)
	pill.set_corner_radius_all(18)
	pill.content_margin_left = 20
	pill.content_margin_right = 20
	pill.content_margin_top = 4
	pill.content_margin_bottom = 5
	omnibox.add_theme_stylebox_override("panel", pill)
	row.add_child(omnibox)
	omnibox.owner = owner

	var address := Label.new()
	address.name = "Address"
	address.text = url
	address.add_theme_font_size_override("font_size", 19)
	address.add_theme_color_override("font_color", Palette.color(&"text_dim"))
	omnibox.add_child(address)
	address.owner = owner

## The employee portal's own header - its logo, its name, and its two pages
## with the one you are on underlined - shared by the store and the toolkit so
## they read as one website. Returns the row, so a page can add to its right.
static func portal_header(parent: Node, owner: Node, active: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "SiteHeader"
	row.add_theme_constant_override("separation", 18)
	parent.add_child(row)
	row.owner = owner

	var logo := box(row, owner, "Logo", &"primary", &"", 0, 10)
	logo.custom_minimum_size = Vector2(52, 52)
	logo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var mark := label(logo, owner, "Mark", "RD", 24, &"paper", true)
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var site := label(row, owner, "SiteName", "Employee Portal", 30, &"text", true)
	site.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var gap := Control.new()
	gap.name = "Gap"
	gap.custom_minimum_size = Vector2(24, 0)
	row.add_child(gap)
	gap.owner = owner
	for page in ["Store", "My Toolkit"]:
		var on: bool = page == active
		var tab := PanelContainer.new()
		tab.name = page.replace(" ", "") + "Tab"
		tab.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var underline := StyleBoxFlat.new()
		underline.bg_color = Color(0, 0, 0, 0)
		underline.border_color = Palette.color(&"primary")
		underline.border_width_bottom = 3 if on else 0
		underline.content_margin_left = 6
		underline.content_margin_right = 6
		underline.content_margin_bottom = 6
		tab.add_theme_stylebox_override("panel", underline)
		row.add_child(tab)
		tab.owner = owner
		label(tab, owner, "Label", page, 22, &"primary" if on else &"text_dim", on)

	var spacer := Control.new()
	spacer.name = "Spacer"
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	spacer.owner = owner
	return row

## A label in one of the palette's roles - the one every screen here needs a
## dozen of.
static func label(parent: Node, owner: Node, node_name: String, text: String,
		size: int, role: StringName, heading: bool = false,
		unique: bool = false) -> Label:
	var l := Label.new()
	l.name = node_name
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Palette.color(role))
	if heading:
		l.theme_type_variation = &"Heading"
	l.unique_name_in_owner = unique
	parent.add_child(l)
	l.owner = owner
	return l

## A hairline. A styled PanelContainer rather than a ColorRect: the end-of-day
## report lives under the shift's HUD, and a test there bans ColorRects under
## the HUD outright (a full-rect one once ate every click meant for the table).
static func rule(parent: Node, owner: Node, node_name: String) -> void:
	var line := PanelContainer.new()
	line.name = node_name
	line.custom_minimum_size = Vector2(0, 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.color(&"neutral_2")
	line.add_theme_stylebox_override("panel", style)
	parent.add_child(line)
	line.owner = owner

## A rounded box - a tile, a sidebar, a highlighted block.
static func box(parent: Node, owner: Node, node_name: String, fill: StringName,
		edge: StringName = &"", pad: int = 20, radius: int = 12) -> PanelContainer:
	var p := PanelContainer.new()
	p.name = node_name
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.color(fill)
	if edge != &"":
		style.border_color = Palette.color(edge)
		style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(pad)
	p.add_theme_stylebox_override("panel", style)
	parent.add_child(p)
	p.owner = owner
	return p
