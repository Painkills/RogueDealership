class_name ProductBoard extends PanelContainer
## The menu: a menu run's products, face up down the right rail in place of the
## shift log (Shift.board). One slot per interest - rows are categories, the
## columns in the order the customers' grids use too (Shift.board_order()), so
## the product in a column is the one for the cell above it on their folder.
##
## Small, because there are nine; the one under the pointer - or a finger's
## tap or hold, where there is no pointer to hover - is shown full size beside
## the rail. Drag it and the big card gives way to a small one beside your
## finger; let go over the tablet on the table to put it there - the floor
## (ShiftController) works out whose table that is.
##
## Each slot carries the customer you are looking at's rank for it - "?" until
## you have found it out - and greys out while it is on a table or gone for the
## shift.

## Let go somewhere: the floor works out whose table that is.
signal dropped(product_id: StringName, at: Vector2)

## How far a press has to move before it is a drag rather than a tap - a finger
## held still wobbles a little.
const DRAG_FROM := 14.0
## Where the dragged card rides: left of the pointer, level with it - its right
## edge's middle just short of where the finger is, so the finger covers none
## of it.
const BESIDE_FINGER := 24.0
const BESIDE_FINGER_TOUCH := 36.0

const SLOT := Vector2(104, 146)
const GAP := 8
## The one under the pointer, full size, left of the rail.
const ZOOM := Vector2(300, 420)
## How far left of the rail the full-size card sits: a little with a pointer,
## more on a touch screen, where the finger on a slot would otherwise sit right
## up against it.
const ZOOM_GAP := 16.0
const ZOOM_GAP_TOUCH := 48.0
const BADGE := Vector2(38, 30)

var _grid: GridContainer
var _zoom: ShopCardButton
var _ghost: ShopCardButton
var _held: StringName = &""
## Where the held press went down, and whether it has moved far enough since to
## be a drag (DRAG_FROM).
var _pressed_at := Vector2.ZERO
var _dragging := false
## On a touch screen the card dragged is full size: there is no hover there to
## have read it first, and a finger is no pointer to aim a small one past. On a
## mouse it is small - the big one was up while you hovered. Settable for checks.
var big_drag := DisplayServer.is_touchscreen_available()
## product id -> its slot, from the last show_board().
var _boxes: Dictionary = {}
## What the slots were last built for - see show_board().
var _layout := ""
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
	hint.text = "Drag one onto the tablet."
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
## The slots are built when what is on the menu changes - a new shift, a product
## upgraded - and only brought up to date otherwise: every move of a shift
## renders the floor, and nine cards made afresh each time was a stall a phone
## could feel.
func show_board(shift: Shift, focus) -> void:
	_build()
	var by_interest := {}
	for inst in shift.board:
		by_interest[(inst.card as ProductCardDef).interest.id] = inst
	var order := shift.board_order()
	var layout: Array[String] = []
	for cat in shift.interests.categories:
		for iid in order.get(cat.id, []):
			var inst: CardInstance = by_interest.get(iid)
			layout.append("%s:%s" % [iid, "%s/%d/%s" % [inst.card.id, inst.uid, inst.upgraded]
				if inst != null else ""])
	var key := ",".join(layout)
	if key != _layout:
		_layout = key
		_lay_out(shift, order, by_interest)
	for id in _shown:
		_update_slot(shift, _shown[id], _boxes[id], focus)

func _lay_out(shift: Shift, order: Dictionary, by_interest: Dictionary) -> void:
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	_shown.clear()
	_boxes.clear()
	for cat in shift.interests.categories:
		for iid in order.get(cat.id, []):
			var inst: CardInstance = by_interest.get(iid)
			if inst == null:
				_grid.add_child(_empty_slot(shift.interests.by_id(iid)))
			else:
				_shown[inst.card.id] = inst
				var slot := _slot(inst)
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

## A product's slot: its card, what keeps it off the table when something does,
## and the rank badge - filled in by _update_slot().
func _slot(inst: CardInstance) -> Control:
	var box := Control.new()
	box.custom_minimum_size = SLOT
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	box.set_meta("product", inst.card.id)
	var card := _card()
	card.show_card(inst)
	box.add_child(card)
	var why := Label.new()
	why.name = "Why"
	why.add_theme_font_size_override("font_size", 14)
	why.add_theme_color_override("font_color", Palette.color(&"text"))
	why.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	why.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	why.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(why)
	why.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.add_child(_badge())
	box.mouse_entered.connect(_show_zoom.bind(inst, box))
	box.mouse_exited.connect(_hide_zoom)
	# Every slot answers a press - a tap is how a finger reads one - but only a
	# product you can put down picks up (the "free" meta, _update_slot()).
	box.gui_input.connect(_on_slot_input.bind(inst.card.id))
	_boxes[inst.card.id] = box
	return box

## Whether `inst` can go on a table now, and `focus`'s rank for it.
func _update_slot(shift: Shift, inst: CardInstance, box: Control, focus) -> void:
	var free := shift.board_available(inst)
	box.set_meta("free", free)
	(box.get_child(0) as Control).modulate.a = 1.0 if free else 0.35
	var why := box.get_node(^"Why") as Label
	why.visible = not free
	why.text = "GONE" if shift.exhausted.has(inst) else "ON A TABLE"

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
	var badge := box.get_node(^"Badge") as PanelContainer
	badge.visible = text != ""
	(badge.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = fill
	(badge.get_child(0) as Label).text = text

## The rank badge in a slot's corner - its words and colour are _update_slot()'s.
func _badge() -> Control:
	var badge := PanelContainer.new()
	badge.name = "Badge"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.position = Vector2(-4, -4)
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(8)
	style.content_margin_left = 6
	style.content_margin_right = 6
	badge.add_theme_stylebox_override("panel", style)
	var label := Label.new()
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
	_zoom.global_position = Vector2(get_global_rect().position.x - ZOOM.x
		- (ZOOM_GAP_TOUCH if big_drag else ZOOM_GAP),
		clampf(r.get_center().y - ZOOM.y * 0.5, top,
			maxf(top, get_viewport_rect().size.y - ZOOM.y - 8.0)))
	_zoom.visible = true

func _hide_zoom() -> void:
	_zoom.visible = false

## A touch screen sends every touch twice: as the touch, and as a mouse the
## engine makes of it (emulate_mouse_from_touch, on by default). Following both
## made a dragged card flick between the two - and a touch's position in a
## slot's own input is the slot's, not the screen's. With the mouse made of it,
## the mouse is the one followed.
static func _second_copy(event: InputEvent) -> bool:
	return (event is InputEventScreenTouch or event is InputEventScreenDrag) \
		and bool(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", true))

func _on_slot_input(event: InputEvent, product_id: StringName) -> void:
	if _second_copy(event):
		return
	var pressed_at = null
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			pressed_at = mb.global_position
	elif event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		# The slot's own position, made the screen's.
		pressed_at = (_boxes[product_id] as Control).get_global_transform() \
			* (event as InputEventScreenTouch).position
	if pressed_at == null or not _shown.has(product_id):
		return
	accept_event()
	# Full size first - a tap, or a finger held on it, is a look.
	var box: Control = _boxes[product_id]
	_show_zoom(_shown[product_id], box)
	if not bool(box.get_meta("free", false)):
		return
	_held = product_id
	_pressed_at = pressed_at
	_dragging = false

## Which product is being held on the menu - pressed, dragged or not yet - or &"".
func held() -> StringName:
	return _held

## Whether the held product is being dragged (rather than only looked at).
func dragging() -> bool:
	return _dragging

## Whether the full-size card is up.
func zoomed() -> bool:
	return _zoom.visible

func _input(event: InputEvent) -> void:
	if _second_copy(event):
		return
	# A press anywhere else puts a tapped card away - a finger never "leaves" a
	# slot the way a pointer does. A press on a slot shows its own again after.
	var down := (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) \
		or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
	if down and _held == &"":
		_hide_zoom()
	if _held == &"":
		return
	var moved_to = null
	if event is InputEventMouseMotion:
		moved_to = (event as InputEventMouseMotion).position
	elif event is InputEventScreenDrag:
		moved_to = (event as InputEventScreenDrag).position
	if moved_to != null:
		if not _dragging and (moved_to as Vector2).distance_to(_pressed_at) >= DRAG_FROM:
			# A drag now: the big card gives way to a small one by the finger.
			_dragging = true
			_hide_zoom()
			_ghost.show_card(_shown[_held])
			_fit(_ghost, ZOOM if big_drag else SLOT * 1.3)
			_ghost.modulate.a = 1.0 if big_drag else 0.85
			_ghost.visible = true
		if _dragging:
			_follow(moved_to)
	var released_at = null
	if event is InputEventMouseButton and not (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		released_at = (event as InputEventMouseButton).position
	elif event is InputEventScreenTouch and not (event as InputEventScreenTouch).pressed:
		released_at = (event as InputEventScreenTouch).position
	if released_at == null:
		return
	var id := _held
	var was_dragged := _dragging
	_held = &""
	_dragging = false
	_ghost.visible = false
	# Let go without dragging, it was a look: the big card stays up until the
	# next press. Dragged, it goes where it was let go.
	if was_dragged:
		dropped.emit(id, released_at)

func _follow(at: Vector2) -> void:
	var gap := BESIDE_FINGER_TOUCH if big_drag else BESIDE_FINGER
	var screen := get_viewport_rect().size
	# Kept wholly on screen, so all of it can be read wherever the finger goes.
	_ghost.global_position = Vector2(
		clampf(at.x - _ghost.size.x - gap, 0.0, maxf(0.0, screen.x - _ghost.size.x)),
		clampf(at.y - _ghost.size.y * 0.5, 0.0, maxf(0.0, screen.y - _ghost.size.y)))
