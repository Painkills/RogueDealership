class_name CategoryIcon extends RefCounted
## Three small vector glyphs - Vehicle, Deal, Person - for the one thing the
## interest grid never said out loud: WHICH category a lit row or a known cell
## actually is. Read the Room lights a whole row, and a lit row with no label
## on it told you nothing except that something, somewhere, had changed.
##
## Filled silhouettes, not outlines: a hairline reads as a smudge once a card
## authored at 500x700 lands on a flanker rendering at 0.358 of that, and a
## solid shape survives the downscale a line never does.
##
## The SAME three shapes are used everywhere a category's name is written as
## prose too - a hand card's body line, the offer detail's sub line - via
## CategoryIconControl, so the glyph that marks a lit row on the grid is the
## exact glyph next to the word "Vehicle" on a Vehicle Service Contract.
##
## Geometry is exposed as pure functions for the same reason
## InterestGrid.row_order() and AppealBar.marker_y() are: draw_* calls only
## work inside a live _draw(), so the one thing a headless test CAN check is
## that the three shapes are actually shaped like three different things and
## stay inside the box they were given.

## Silhouette of a car in profile - body plus a roof bump, one polygon.
static func car_body(rect: Rect2) -> PackedVector2Array:
	var o := rect.position
	var w := rect.size.x
	var h := rect.size.y
	return PackedVector2Array([
		o + Vector2(w * 0.06, h * 0.66),
		o + Vector2(w * 0.06, h * 0.46),
		o + Vector2(w * 0.26, h * 0.46),
		o + Vector2(w * 0.36, h * 0.20),
		o + Vector2(w * 0.64, h * 0.20),
		o + Vector2(w * 0.74, h * 0.46),
		o + Vector2(w * 0.94, h * 0.46),
		o + Vector2(w * 0.94, h * 0.66),
	])

## Two wheel centres. Drawn as filled circles that OVERLAP the body's bottom
## edge - the same trick every flat car icon uses to read as one silhouette
## rather than a body floating over two separate dots.
static func car_wheels(rect: Rect2) -> PackedVector2Array:
	var o := rect.position
	var w := rect.size.x
	var h := rect.size.y
	return PackedVector2Array([
		o + Vector2(w * 0.28, h * 0.66),
		o + Vector2(w * 0.72, h * 0.66),
	])

static func car_wheel_radius(rect: Rect2) -> float:
	return rect.size.x * 0.12

## A price tag: a pointed left tip, a flat right edge. One polygon, no punched
## hole - a hole needs to know what colour is behind it, and this glyph is
## reused against three different grounds (unknown/known/lit cells and two
## different card panels) that a fixed hole colour would fight with.
static func tag(rect: Rect2) -> PackedVector2Array:
	var o := rect.position
	var w := rect.size.x
	var h := rect.size.y
	return PackedVector2Array([
		o + Vector2(w * 0.05, h * 0.5),
		o + Vector2(w * 0.42, h * 0.10),
		o + Vector2(w * 0.95, h * 0.10),
		o + Vector2(w * 0.95, h * 0.90),
		o + Vector2(w * 0.42, h * 0.90),
	])

## Head-and-shoulders: a circle plus a trapezoid.
static func person_body(rect: Rect2) -> PackedVector2Array:
	var o := rect.position
	var w := rect.size.x
	var h := rect.size.y
	return PackedVector2Array([
		o + Vector2(w * 0.22, h * 0.95),
		o + Vector2(w * 0.30, h * 0.58),
		o + Vector2(w * 0.50, h * 0.50),
		o + Vector2(w * 0.70, h * 0.58),
		o + Vector2(w * 0.78, h * 0.95),
	])

static func person_head_center(rect: Rect2) -> Vector2:
	return rect.position + Vector2(rect.size.x * 0.5, rect.size.y * 0.26)

static func person_head_radius(rect: Rect2) -> float:
	return rect.size.x * 0.17

## The one entry point every caller actually uses. An id outside the three
## categories draws nothing - the set is closed and fixed, so a silent no-op
## is the right failure mode for a badge, not a pushed error every frame.
static func draw(ci: CanvasItem, rect: Rect2, category_id: StringName,
		color: Color) -> void:
	match category_id:
		&"vehicle":
			ci.draw_colored_polygon(car_body(rect), color)
			var r := car_wheel_radius(rect)
			for center in car_wheels(rect):
				ci.draw_circle(center, r, color)
		&"deal":
			ci.draw_colored_polygon(tag(rect), color)
		&"person":
			ci.draw_circle(person_head_center(rect), person_head_radius(rect), color)
			ci.draw_colored_polygon(person_body(rect), color)
