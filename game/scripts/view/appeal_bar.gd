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
## The numbers: the appeal you are at, on a badge, and the Line's once you know
## it, on a tag. Type sizes, then the badge's height and the least clear space
## kept between it and the Line's tag.
const BADGE_FONT := 34
const BADGE_H := 50.0
const BADGE_GAP := 14.0
const LINE_FONT := 28
const CAPTION_FONT := 14
## Between the tag's caption and its number.
const TAG_GAP := 8.0

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
	var paper := Palette.color(&"paper")
	# The appeal you are at: a badge in the fill's own colour, ringed in paper
	# so it reads on the fill and on the empty track alike, with a soft shadow.
	var text := appeal_text()
	if text != "":
		var at := appeal_label_rect(fill, tag, font)
		var radius := int(at.size.y * 0.5)
		draw_style_box(_rounded(Color(0, 0, 0, 0.28), radius), Rect2(at.position + Vector2(0, 3), at.size))
		var badge := _rounded(fill_color().darkened(0.3), radius)
		badge.border_color = paper
		badge.set_border_width_all(3)
		draw_style_box(badge, at)
		_text_in(at, text, BADGE_FONT, paper, font)
	# The Line's number: a dark tag with a small caption, so the two numbers
	# cannot be mistaken for each other.
	if tag.size.x > 0.0:
		draw_style_box(_rounded(ink, int(tag.size.y * 0.5)), tag)
		var caption_w: float = font.get_string_size("LINE", HORIZONTAL_ALIGNMENT_LEFT, -1, CAPTION_FONT).x
		var number_w: float = font.get_string_size(line_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, LINE_FONT).x
		var x: float = tag.position.x + (tag.size.x - caption_w - TAG_GAP - number_w) * 0.5
		var mid: float = tag.position.y + tag.size.y * 0.5
		draw_string(font, Vector2(x, mid + CAPTION_FONT * 0.35), "LINE",
			HORIZONTAL_ALIGNMENT_LEFT, -1, CAPTION_FONT, Color(paper, 0.7))
		draw_string(font, Vector2(x + caption_w + TAG_GAP, mid + LINE_FONT * 0.35), line_text(),
			HORIZONTAL_ALIGNMENT_LEFT, -1, LINE_FONT, paper)

# --- the numbers -----------------------------------------------------------

## What the bar prints for your appeal - nothing on an empty table.
func appeal_text() -> String:
	return "" if _band == "" else str(_appeal)

## The Line's number - only once you know it, the same gate as the marker.
func line_text() -> String:
	return str(_line) if _line_known and _band != "" else ""

## The Line's tag: a dark pill, "LINE" and its number, centred on the marker.
func line_tag_rect(my: float, font: Font) -> Rect2:
	var caption_w: float = font.get_string_size("LINE", HORIZONTAL_ALIGNMENT_LEFT, -1, CAPTION_FONT).x
	var number_w: float = font.get_string_size(line_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, LINE_FONT).x
	var w: float = minf(caption_w + TAG_GAP + number_w + 28.0, size.x - 2.0)
	var h: float = LINE_FONT + 16.0
	return Rect2(size.x * 0.5 - w * 0.5, my - h * 0.5, w, h)

## Where the appeal badge goes: just inside the top of the fill, or just above
## it when the fill is too short to hold it - and never closer than BADGE_GAP
## to the Line's tag. Where the two would crowd (the appeal at, just over or
## just under the Line) it moves to the nearer side of the tag, above or below,
## and always stays on the bar.
func appeal_label_rect(fill: Rect2, tag: Rect2, font: Font) -> Rect2:
	var text_w: float = font.get_string_size(appeal_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, BADGE_FONT).x
	var w: float = minf(maxf(BADGE_H, text_w + 30.0), size.x - 2.0)
	var h: float = BADGE_H
	var lowest: float = size.y - TRACK_INSET - h - 2.0
	var highest: float = TRACK_INSET + 2.0
	var top: float = fill.position.y + 8.0
	if fill.size.y < h + 16.0:
		top = fill.position.y - h - 8.0
	top = clampf(top, highest, lowest)
	var r := Rect2(size.x * 0.5 - w * 0.5, top, w, h)
	if tag.size.x <= 0.0:
		return r
	var zone := tag.grow(BADGE_GAP)
	if not r.intersects(zone):
		return r
	var below: float = tag.end.y + BADGE_GAP
	var above: float = tag.position.y - BADGE_GAP - h
	var options: Array[float] = []
	for y in [below, above]:
		if y >= highest and y <= lowest:
			options.append(y)
	if options.is_empty():
		# No room either side (a very short bar): the one with more space.
		options.append(below if size.y - tag.end.y >= tag.position.y else above)
	options.sort_custom(func(a, b): return absf(a - top) < absf(b - top))
	r.position.y = options[0]
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
