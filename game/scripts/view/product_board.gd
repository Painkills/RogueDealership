class_name ProductBoard extends PanelContainer
## The menu: a menu run's products, face up down the right rail in place of the
## shift log (Shift.board). One slot per interest - rows are categories, the
## columns in the order the customers' grids use too (Shift.board_order()), so
## the product in a column is the one for the cell above it on their folder.
##
## Small, because there are nine; the one under the pointer is shown full size
## beside the rail. Press one and drag it onto a customer's folder to put it on
## their table - the floor (ShiftController) finds who it was let go over.
##
## Each slot carries the customer you are looking at's rank for it - "?" until
## you have found it out - and greys out while it is on a table or gone for the
## shift.

## Let go somewhere: the floor works out whose folder that is.
signal dropped(product_id: StringName, at: Vector2)

const SLOT := Vector2(104, 146)
const GAP := 8
## The one under the pointer, full size, left of the rail.
const ZOOM := Vector2(300, 420)
const BADGE := Vector2(38, 30)

var _grid: GridContainer
var _zoom: ShopCardButton
var _ghost: ShopCardButton
var _held: StringName = &""
var _built := false
## product id -> CardInstance, from the last show().
var _shown: Dictionary = {}

func _ready() -> void:
	_build()

func _build() -> void:
	if _built:
		return
	_built = true
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	var title := Label.new()
	title.text = "THE MENU"
	title.theme_type_variation = &"Heading"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Palette.color(&"text_dim"))
	col.add_child(title)
	var hint := Label.new()
	hint.text = "Drag one onto a customer."
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Palette.color(&"text_dim"))
	col.add_child(hint)
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", GAP)
	_grid.add_theme_constant_override("v_separation", GAP)
	_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_grid)
	_zoom = _card()
	_zoom.top_level = true
	_zoom.visible = false
	add_child(_zoom)
	_fit(_zoom, ZOOM)
	_ghost = _card()
	_ghost.top_level = true
	_ghost.visible = false
	_ghost.modulate.a = 0.85
	add_child(_ghost)
	_fit(_ghost, SLOT * 1.3)

func _card() -> ShopCardButton:
	var card: ShopCardButton = (load("res://scenes/cards/shop_card_button.tscn") \
		as PackedScene).instantiate()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.focus_mode = Control.FOCUS_NONE
	return card

## Sizes `card`, once it is in the tree - nothing here is a container to do it,
## and out of the tree a size neither sticks nor reaches the picture inside.
func _fit(card: ShopCardButton, sz: Vector2) -> void:
	card.custom_minimum_size = sz
	card.size = sz
	var picture := card.get_node(^"TextureRect") as Control
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

## Lays the menu out for `shift`, with `focus`'s ranks on it (null: nobody's).
func show_board(shift: Shift, focus) -> void:
	_build()
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	_shown.clear()
	var by_interest := {}
	for inst in shift.board:
		by_interest[(inst.card as ProductCardDef).interest.id] = inst
	var order := shift.board_order()
	for cat in shift.interests.categories:
		for iid in order.get(cat.id, []):
			var inst: CardInstance = by_interest.get(iid)
			if inst == null:
				_grid.add_child(_empty_slot(shift.interests.by_id(iid)))
			else:
				_shown[inst.card.id] = inst
				var slot := _slot(shift, inst, focus)
				_grid.add_child(slot)
				_fit(slot.get_child(0) as ShopCardButton, SLOT)

func _empty_slot(interest: Interest) -> Control:
	var box := Panel.new()
	box.custom_minimum_size = SLOT
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.color(&"panel_hi")
	style.border_color = Palette.color(&"neutral_3")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	box.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = "%s\nopen" % (interest.display_name if interest != null else "")
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Palette.color(&"text_dim"))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_child(label)
	return box

func _slot(shift: Shift, inst: CardInstance, focus) -> Control:
	var box := Control.new()
	box.custom_minimum_size = SLOT
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	box.set_meta("product", inst.card.id)
	var card := _card()
	card.show_card(inst)
	box.add_child(card)
	var free := shift.board_available(inst)
	if not free:
		card.modulate.a = 0.35
		var why := Label.new()
		why.text = "GONE" if shift.exhausted.has(inst) else "ON A TABLE"
		why.add_theme_font_size_override("font_size", 14)
		why.add_theme_color_override("font_color", Palette.color(&"text"))
		why.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		why.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		why.autowrap_mode = TextServer.AUTOWRAP_WORD
		box.add_child(why)
		why.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.add_child(_badge(inst, focus))
	box.mouse_entered.connect(_show_zoom.bind(inst, box))
	box.mouse_exited.connect(_hide_zoom)
	if free:
		box.gui_input.connect(_on_slot_input.bind(inst.card.id))
	return box

## Their rank for the product's interest, once you know it; "?" before.
func _badge(inst: CardInstance, focus) -> Control:
	var iid: StringName = (inst.card as ProductCardDef).interest.id
	var text := ""
	var fill := Palette.color(&"grid_cell")
	if focus != null:
		text = "?"
		if focus.owns(inst.card.id):
			text = "SOLD"
			fill = Palette.color(&"patience_ok")
		elif focus.known_ranks.has(iid):
			var rank := int(focus.known_ranks[iid])
			text = str(rank)
			fill = Palette.color(&"accent") if rank == 1 else Palette.color(&"patience_warn")
	var badge := PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.position = Vector2(-4, -4)
	badge.visible = text != ""
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(8)
	style.content_margin_left = 6
	style.content_margin_right = 6
	badge.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(BADGE.x - 12, BADGE.y)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Palette.color(&"neutral_1"))
	badge.add_child(label)
	return badge

func _show_zoom(inst: CardInstance, over: Control) -> void:
	if _held != &"":
		return
	_zoom.show_card(inst)
	var r := over.get_global_rect()
	# Level with the slot, but never up under the top bar: no higher than the
	# rail's own top.
	var top := get_global_rect().position.y
	_zoom.global_position = Vector2(get_global_rect().position.x - ZOOM.x - 16,
		clampf(r.get_center().y - ZOOM.y * 0.5, top,
			maxf(top, get_viewport_rect().size.y - ZOOM.y - 8.0)))
	_zoom.visible = true

func _hide_zoom() -> void:
	_zoom.visible = false

func _on_slot_input(event: InputEvent, product_id: StringName) -> void:
	var pressed := false
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		pressed = mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventScreenTouch:
		pressed = (event as InputEventScreenTouch).pressed
	if not pressed or not _shown.has(product_id):
		return
	_held = product_id
	_hide_zoom()
	_ghost.show_card(_shown[product_id])
	_ghost.visible = true
	_follow(get_viewport().get_mouse_position())
	accept_event()

## Which product is being dragged off the menu, or &"".
func held() -> StringName:
	return _held

func _input(event: InputEvent) -> void:
	if _held == &"":
		return
	if event is InputEventMouseMotion:
		_follow((event as InputEventMouseMotion).position)
	elif event is InputEventScreenDrag:
		_follow((event as InputEventScreenDrag).position)
	var released_at = null
	if event is InputEventMouseButton and not (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		released_at = (event as InputEventMouseButton).position
	elif event is InputEventScreenTouch and not (event as InputEventScreenTouch).pressed:
		released_at = (event as InputEventScreenTouch).position
	if released_at == null:
		return
	var id := _held
	_held = &""
	_ghost.visible = false
	dropped.emit(id, released_at)

func _follow(at: Vector2) -> void:
	_ghost.global_position = at - _ghost.size * 0.5
