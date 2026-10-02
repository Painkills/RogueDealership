class_name AppealBar extends Control
## The appeal meter on the tablet, standing upright beside the product.
##
## Three things at once, and each answers a different question:
##
##   FILL   how much appeal is on this offer right now, rising from the bottom.
##          Always drawn, and it climbs as you play appeal cards - which is the
##          whole point. Before this, appeal cards changed nothing you could see
##          until you offered.
##   COLOUR how that compares with their Line. Red far, amber close, green once
##          you have cleared it. The tablet prints the band's word under it in
##          the same colour - INTERESTED, ALMOST, WARM, COOL, COLD.
##   MARKER where the Line actually is: a rule across the bar at its height.
##          Drawn ONLY once you know it, which is after Read the Room. That is
##          the one number the fog is protecting, so it is the one thing gated.
##
## Upright rather than lying across its panel: standing, it runs the whole
## height of the tablet's screen, where lying down it only ever had the panel's
## width to fill.
##
## And two numbers: the appeal you are AT, at the top of the fill, and - once
## the marker is drawn - the Line's own, on a tag on the marker. The fill says
## roughly; the numbers say exactly what a card has to add.

const TRACK_INSET := 4.0
const MARKER_WIDTH := 6.0
const NUB := 8.0
const RADIUS := 14
## The numbers: the appeal you are at, and the Line's once you know it.
const VALUE_FONT := 40
const LINE_FONT := 30

var _appeal: int = 0
var _line: int = 0
var _scale: int = 40
var _band: String = ""
var _line_known: bool = false

## `full_scale`, not `scale` - Control already has a `scale` property and
## shadowing it here produced a warning on every load.
##
## `band` comes from Shift.band_for() rather than being re-derived here, so the
## thresholds have exactly one definition and it lives in the model.
func set_state(appeal: int, line: int, full_scale: int, band: String,
		line_known: bool) -> void:
	_appeal = appeal
	_line = line
	_scale = max(1, full_scale)
	_band = band
	_line_known = line_known
	queue_redraw()

## Green once the offer would close, amber inside WARM, red beyond it. Note this
## is honest even when the Line is hidden: the colour is the guess the player is
## meant to be making, and the marker is the confirmation.
func fill_color() -> Color:
	if _appeal >= _line:
		return Palette.color(&"patience_ok")
	if _band == "ALMOST" or _band == "WARM":
		return Palette.color(&"patience_warn")
	return Palette.color(&"patience_bad")

## The part of `track` the fill covers: its full width, standing on its bottom
## edge, as tall as the appeal is a share of the scale. Hoisted out of _draw()
## for the same reason marker_y() is - _draw() needs a real canvas, so a rule
## that lived only in there could never be checked headless.
func fill_rect(track: Rect2) -> Rect2:
	var h: float = track.size.y * clampf(float(_appeal) / float(_scale), 0.0, 1.0)
	return Rect2(track.position.x, track.end.y - h, track.size.x, h)

## Where the Line marker goes, or -1 when it must not be drawn at all. Measured
## up from the bottom, the way the fill rises. The gate lives HERE rather than
## as a branch inside _draw(), so the one thing the fog is actually protecting
## is not the one thing nothing could test.
func marker_y(track: Rect2) -> float:
	if not _line_known:
		return -1.0
	return track.end.y \
		- track.size.y * clampf(float(_line) / float(_scale), 0.0, 1.0)

func _track() -> Rect2:
	return Rect2(TRACK_INSET, TRACK_INSET,
		size.x - TRACK_INSET * 2.0, size.y - TRACK_INSET * 2.0)

func _draw() -> void:
	draw_style_box(_rounded(Palette.color(&"neutral_1"), RADIUS), Rect2(Vector2.ZERO, size))
	var track := _track()
	var inner := RADIUS - int(TRACK_INSET)
	draw_style_box(_rounded(Palette.color(&"panel_hi"), inner), track)

	var fill := fill_rect(track)
	if fill.size.y > 0.0:
		draw_style_box(_rounded(fill_color(), inner), fill)

	var ink := Palette.color(&"text")
	var my := marker_y(track)
	var font := get_theme_default_font()
	var tag := Rect2()
	if my >= 0.0:
		# A rule across the whole bar plus a nub either side, so the Line stays
		# findable where the fill has already risen past it and the two are the
		# same brightness.
		draw_rect(Rect2(0.0, my - MARKER_WIDTH * 0.5, size.x, MARKER_WIDTH), ink)
		draw_rect(Rect2(0.0, my - NUB, TRACK_INSET + 3.0, NUB * 2.0), ink)
		draw_rect(Rect2(size.x - TRACK_INSET - 3.0, my - NUB, TRACK_INSET + 3.0, NUB * 2.0), ink)
		if font != null and line_text() != "":
			tag = line_tag_rect(my, font)
	if font == null:
		return
	# The appeal you are at, at the top of the fill - drawn before the Line's
	# tag, which sits on top of everything.
	var text := appeal_text()
	if text != "":
		var at := appeal_label_rect(fill, tag, font)
		var white := fill.size.y > 0.0 and fill.encloses(at)
		_text_in(at, text, VALUE_FONT, Palette.color(&"paper") if white else ink, font)
	if tag.size.x > 0.0:
		draw_style_box(_rounded(ink, 8), tag)
		_text_in(tag, line_text(), LINE_FONT, Palette.color(&"paper"), font)

# --- the numbers -----------------------------------------------------------

## What the bar prints for your appeal - nothing on an empty table.
func appeal_text() -> String:
	return "" if _band == "" else str(_appeal)

## The Line's number - only once you know it, the same gate as the marker.
func line_text() -> String:
	return str(_line) if _line_known and _band != "" else ""

## The Line's tag: a dark pill centred on the marker.
func line_tag_rect(my: float, font: Font) -> Rect2:
	var w: float = font.get_string_size(line_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, LINE_FONT).x + 16.0
	var h: float = LINE_FONT + 10.0
	return Rect2(size.x * 0.5 - w * 0.5, my - h * 0.5, w, h)

## Where your appeal's number goes: just inside the top of the fill, or just
## above it when the fill is too short to hold it - and clear of the Line's
## tag, stepping below it if the two would overlap.
func appeal_label_rect(fill: Rect2, tag: Rect2, font: Font) -> Rect2:
	var w: float = font.get_string_size(appeal_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, VALUE_FONT).x
	var h: float = VALUE_FONT + 6.0
	var top: float = fill.position.y + 6.0
	if fill.size.y < h + 12.0:
		top = fill.position.y - h - 4.0
	var r := Rect2(size.x * 0.5 - w * 0.5, top, w, h)
	if tag.size.x > 0.0 and r.intersects(tag):
		r.position.y = tag.end.y + 4.0
	return r

func _text_in(r: Rect2, text: String, px: int, color: Color, font: Font) -> void:
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	draw_string(font, Vector2(r.position.x + r.size.x * 0.5 - w * 0.5,
		r.position.y + r.size.y * 0.5 + px * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, color)

func _rounded(color: Color, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(maxi(0, radius))
	return s
