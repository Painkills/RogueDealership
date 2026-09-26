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
##          you have cleared it. This replaces the COOL / WARM / ALMOST words:
##          the band was always a colour pretending to be a noun.
##   MARKER where the Line actually is: a rule across the bar at its height.
##          Drawn ONLY once you know it, which is after Read the Room. That is
##          the one number the fog is protecting, so it is the one thing gated.
##
## Upright rather than lying across its panel: standing, it runs the whole
## height of the tablet's screen, where lying down it only ever had the panel's
## width to fill.
##
## No text. A bar with a number printed on it is two readouts disagreeing about
## which one you should look at.

const TRACK_INSET := 4.0
const MARKER_WIDTH := 6.0
const NUB := 8.0
const RADIUS := 14

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

	var my := marker_y(track)
	if my < 0.0:
		return
	# A rule across the whole bar plus a nub either side, so the Line stays
	# findable where the fill has already risen past it and the two are the
	# same brightness.
	var ink := Palette.color(&"text")
	draw_rect(Rect2(0.0, my - MARKER_WIDTH * 0.5, size.x, MARKER_WIDTH), ink)
	draw_rect(Rect2(0.0, my - NUB, TRACK_INSET + 3.0, NUB * 2.0), ink)
	draw_rect(Rect2(size.x - TRACK_INSET - 3.0, my - NUB, TRACK_INSET + 3.0, NUB * 2.0), ink)

func _rounded(color: Color, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(maxi(0, radius))
	return s
