class_name AppealBar extends Control
## The appeal meter on a product's detail card.
##
## Three things at once, and each answers a different question:
##
##   FILL   how much appeal is on this offer right now. Always drawn, and it
##          grows as you play appeal cards - which is the whole point. Before
##          this, appeal cards changed nothing you could see until you offered.
##   COLOUR how that compares with their Line. Red far, amber close, green once
##          you have cleared it. This replaces the COOL / WARM / ALMOST words:
##          the band was always a colour pretending to be a noun.
##   MARKER where the Line actually is. Drawn ONLY once you know it, which is
##          after you offer or after Read the Room. That is the one number the
##          fog is protecting, so it is the one thing gated.
##
## No text. A bar with a number printed on it is two readouts disagreeing about
## which one you should look at.

const TRACK_INSET := 3.0
const MARKER_WIDTH := 5.0
const NUB := 7.0

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

## Where the Line marker goes, or -1 when it must not be drawn at all. The gate
## lives HERE rather than as a branch inside _draw(), because _draw() needs a
## real canvas and cannot be called from a headless check - so the one thing the
## fog is actually protecting would have been the one thing nothing could test.
func marker_x(track: Rect2) -> float:
	if not _line_known:
		return -1.0
	return track.position.x \
		+ track.size.x * clampf(float(_line) / float(_scale), 0.0, 1.0)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Palette.color(&"neutral_1"))
	var track := Rect2(TRACK_INSET, TRACK_INSET,
		size.x - TRACK_INSET * 2.0, size.y - TRACK_INSET * 2.0)
	draw_rect(track, Palette.color(&"panel_hi"))

	var frac: float = clampf(float(_appeal) / float(_scale), 0.0, 1.0)
	if frac > 0.0:
		draw_rect(Rect2(track.position, Vector2(track.size.x * frac, track.size.y)),
			fill_color())

	var mx := marker_x(track)
	if mx < 0.0:
		return
	# Full-height rule plus a nub top and bottom, so the Line stays findable
	# where the fill has already passed it and the two are the same brightness.
	var ink := Palette.color(&"text")
	draw_rect(Rect2(mx - MARKER_WIDTH * 0.5, 0.0, MARKER_WIDTH, size.y), ink)
	draw_rect(Rect2(mx - NUB, 0.0, NUB * 2.0, TRACK_INSET + 2.0), ink)
	draw_rect(Rect2(mx - NUB, size.y - TRACK_INSET - 2.0, NUB * 2.0,
		TRACK_INSET + 2.0), ink)
