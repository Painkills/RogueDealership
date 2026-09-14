class_name InterestGrid extends Control
## Their priority list, as nine cells instead of a sentence that grows.
##
## It replaced `"Reliability 1st . Status 7th . Power 3rd"` - a line that got
## longer every time you learned something, on a card that has to stay legible
## at 179 px wide once the carousel turns it out to the side. Nine cells in a
## fixed box say the same thing in the same space every time.
##
## ONE ROW PER CATEGORY, in pool order, and that is the load-bearing part: the
## rows never move, so you always know which third of the board you are looking
## at. Read the Room's base effect tells you a CATEGORY, and a category you can
## point at is worth a tick in a way that a category you have to remember is
## not. Within a row, cells you KNOW sort to the front by rank - the
## "arrange themselves in priority order" half - and the rest hold pool order
## behind them.
##
## Drawn rather than assembled from nodes, in the same spirit as appeal_bar.gd.
## There are no image assets in this project and nine cells is not a reason to
## start a texture pipeline.

## Big enough to survive the SubViewport's downscale, small enough to sit
## inside a 65 px cell with margin left. Numerals are only ever drawn on the
## FRONTED card - see `compact` on customer_card_3d.gd - which renders at worst
## at 0.512 of the authored face, so this lands near 27 px on screen.
const NUMERAL := 52
const GAP := 14.0
const RADIUS := 6.0

var _pool: InterestPool = null
var _known: Dictionary = {}          ## interest id -> rank, 1..9
var _top_category = null             ## StringName, or null
var _sold: Dictionary = {}           ## interest id -> true
## Flankers are small enough that a rank numeral stops being readable before
## the CELL does. Colour and fill survive the downscale; digits do not.
var _numerals: bool = true

func set_state(pool: InterestPool, known_ranks: Dictionary, top_category,
		sold: Dictionary, numerals: bool = true) -> void:
	_pool = pool
	_known = known_ranks
	_top_category = top_category
	_sold = sold
	_numerals = numerals
	queue_redraw()

## The cells of one category row, known-first by rank and pool order behind.
## Static and pure so a test can ask what the ordering is without a canvas -
## the same reason appeal_bar.gd hoisted marker_x() out of _draw().
static func row_order(in_row: Array, known: Dictionary) -> Array:
	var seen: Array = []
	var rest: Array = []
	for i in in_row:
		if known.has(i.id):
			seen.append(i)
		else:
			rest.append(i)
	seen.sort_custom(func(a, b): return int(known[a.id]) < int(known[b.id]))
	return seen + rest

func _draw() -> void:
	if _pool == null or _pool.categories.is_empty():
		return
	var rows: int = _pool.categories.size()
	var cols: int = 0
	for c in _pool.categories:
		cols = maxi(cols, _pool.in_category(c).size())
	if cols == 0:
		return

	var cw: float = (size.x - GAP * (cols - 1)) / float(cols)
	var ch: float = (size.y - GAP * (rows - 1)) / float(rows)
	var font := get_theme_default_font()

	for r in range(rows):
		var cat: Category = _pool.categories[r]
		# The whole row lights when Read the Room narrows nine to three. It is
		# the only thing on this card that says what that tick bought you.
		var in_cat: bool = _top_category != null and cat.id == _top_category
		var ordered := row_order(_pool.in_category(cat), _known)
		for c in range(ordered.size()):
			var cell := Rect2(Vector2(c * (cw + GAP), r * (ch + GAP)),
				Vector2(cw, ch))
			_draw_cell(cell, ordered[c], in_cat, font)

func _draw_cell(cell: Rect2, interest: Interest, in_top_category: bool,
		font: Font) -> void:
	var rank: int = int(_known.get(interest.id, 0))
	var sold: bool = _sold.has(interest.id)

	# Ground first, so every cell reads as the same kind of thing whatever else
	# is true of it. An unknown cell is not empty space - it is a slot you have
	# not filled in, and it should look like one.
	var ground: Color = Palette.color(&"panel_hi") if in_top_category \
		else Palette.color(&"neutral_1")
	draw_rect(cell, ground, true)

	if sold:
		# Taken. The strongest state on the card, because it is the only one
		# that is finished - and it reads at any size, numeral or not.
		draw_rect(cell, Palette.color(&"margin"), true)
		_draw_tick(cell)
	elif rank > 0:
		draw_rect(cell, Palette.color(&"appeal"), true)

	var edge: Color = Palette.color(&"neutral_3")
	var thickness := 2.0
	if rank == 1:
		# Their number one, named outright - which only upgraded Read the Room
		# can do. Worth its own mark rather than just being "the cell with a 1".
		edge = Palette.color(&"accent")
		thickness = 6.0
	elif in_top_category:
		edge = Palette.color(&"text_dim")
	draw_rect(cell, edge, false, thickness)

	if rank > 0 and _numerals and font != null:
		var text := str(rank)
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			NUMERAL).x
		var at := cell.get_center() + Vector2(-w * 0.5, NUMERAL * 0.34)
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, NUMERAL,
			Palette.color(&"neutral_1"))

func _draw_tick(cell: Rect2) -> void:
	var c := cell.get_center()
	var s: float = minf(cell.size.x, cell.size.y) * 0.22
	var ink := Palette.color(&"neutral_1")
	draw_line(c + Vector2(-s, 0.0), c + Vector2(-s * 0.2, s), ink, 7.0)
	draw_line(c + Vector2(-s * 0.2, s), c + Vector2(s, -s), ink, 7.0)
