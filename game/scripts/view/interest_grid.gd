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

## Big enough to survive the SubViewport's downscale, small enough to leave
## the bottom of a 65 px cell free for the interest's own name below it.
## Numerals (and names) are only ever drawn on the FRONTED card - see
## `compact` on customer_card_3d.gd - which renders at worst at 0.512 of the
## authored face.
const NUMERAL := 40
## The name that used to only ever appear in "what you know"'s growing
## sentence - see customer_card_3d.gd's known_text() - now lives on the cell
## itself, so a rank means something without reading a second label to match
## it back to an interest. Shrinks toward MIN before it would overflow the
## cell ("Value Retention" is the longest name in the pool).
const NAME_FONT_MAX := 18
const NAME_FONT_MIN := 11
const GAP := 14.0
const RADIUS := 6.0
## A lit row used to say nothing about WHICH category lit - the reader had to
## already know pool order by heart to turn "three squares just changed" into
## "oh, they are a Person person". This column is CategoryIcon.draw()'s badge
## for each row, reserved on the left so the three columns of cells never move.
const ICON_COL := 90.0
const ICON_GAP := 12.0

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

	var grid_x: float = ICON_COL + ICON_GAP
	var cw: float = (size.x - grid_x - GAP * (cols - 1)) / float(cols)
	var ch: float = (size.y - GAP * (rows - 1)) / float(rows)
	var font := get_theme_default_font()

	for r in range(rows):
		var cat: Category = _pool.categories[r]
		# The whole row lights when Read the Room narrows nine to three. It used
		# to be the only thing on this card that said what that tick bought you
		# - which meant it said nothing at all unless you already knew which
		# category the lit row WAS. The badge is what answers that now.
		var in_cat: bool = _top_category != null and cat.id == _top_category
		_draw_row_icon(Rect2(Vector2(0.0, r * (ch + GAP)), Vector2(ICON_COL, ch)),
			cat, in_cat)
		var ordered := row_order(_pool.in_category(cat), _known)
		for c in range(ordered.size()):
			var cell := Rect2(Vector2(grid_x + c * (cw + GAP), r * (ch + GAP)),
				Vector2(cw, ch))
			_draw_cell(cell, ordered[c], in_cat, font)

## The badge shares its row's ground and its row's lit/unlit tint, so it reads
## as part of the row it labels rather than a caption stuck beside it.
func _draw_row_icon(row: Rect2, cat: Category, in_top_category: bool) -> void:
	var ground: Color = Palette.color(&"panel_hi") if in_top_category \
		else Palette.color(&"neutral_1")
	draw_rect(row, ground, true)
	var inset := row.grow(-minf(row.size.x, row.size.y) * 0.14)
	var tint: Color = Palette.color(&"text") if in_top_category \
		else Palette.color(&"text_dim")
	CategoryIcon.draw(self, inset, cat.id, tint)

## Steps down by 1 from max until the string fits max_width, floored at min -
## "Value Retention" and "Affordability" are wider than the cell at
## NAME_FONT_MAX, and a name that overflows into its neighbour is worse than
## a name that is merely small.
static func _fit_font_size(font: Font, text: String, max_width: float,
		max_size: int, min_size: int) -> int:
	var size := max_size
	while size > min_size \
			and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > max_width:
		size -= 1
	return size

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
		# that is finished. A solid colour reads at any size and at a glance;
		# a checkmark drawn small enough to fit a cell was the least visible
		# mark on the whole card, which defeated the point of it being the
		# strongest state.
		draw_rect(cell, Palette.color(&"patience_ok"), true)
	elif rank > 0:
		# Known but not yet taken - the same "still open" yellow the patience
		# bar itself uses, so green only ever means "done."
		draw_rect(cell, Palette.color(&"patience_warn"), true)

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
		var ink := Palette.color(&"neutral_1")
		var text := str(rank)
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			NUMERAL).x
		# Upper portion of the cell, not dead centre - the name below needs
		# the bottom, and both were tuned together against this cell's own
		# 65 px authored height rather than derived from first principles.
		var numeral_mid: float = cell.position.y + cell.size.y * 0.38
		var at := Vector2(cell.position.x + cell.size.x * 0.5 - w * 0.5,
			numeral_mid + NUMERAL * 0.34)
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, NUMERAL, ink)

		var name_text := interest.display_name
		var pad := 6.0
		var max_w: float = maxf(1.0, cell.size.x - pad * 2.0)
		var name_size := _fit_font_size(font, name_text, max_w,
			NAME_FONT_MAX, NAME_FONT_MIN)
		var name_w := font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT,
			-1, name_size).x
		var name_at := Vector2(cell.position.x + cell.size.x * 0.5 - name_w * 0.5,
			cell.position.y + cell.size.y - 6.0)
		draw_string(font, name_at, name_text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			name_size, ink)
