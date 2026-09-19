class_name CardTypeIcon extends RefCounted
## Two small vector glyphs - a car for products, a wrench for support cards -
## for telling the two kinds of card apart at a glance: the front's kind
## badge and the whole card back both read through this.
##
## Filled silhouettes, matching CategoryIcon's own rule: a solid shape
## survives the downscale onto a hand-sized card, a hairline does not.
##
## The car REUSES CategoryIcon's own vehicle glyph rather than a second copy -
## a product's TYPE and a Vehicle-category product's own category icon happen
## to be the literal same shape in a game about selling cars, and drawing one
## shape twice on purpose is a decision, not an accident.

## An open-end wrench, in profile: a forked head (two prongs around a wide
## notch) tapering down through a neck into a straight handle. One concave
## polygon, no holes - Godot fills a concave outline correctly as long as it
## never crosses itself, and this one traces the shape's edge in one pass:
## across the top of both prongs, down into the notch and back out, down the
## outer edge of the right prong and the neck to the handle, across its tip,
## and back up the left side to the start.
static func wrench(rect: Rect2) -> PackedVector2Array:
	var o := rect.position
	var w := rect.size.x
	var h := rect.size.y
	return PackedVector2Array([
		o + Vector2(w * 0.18, h * 0.06),   # left prong, outer top
		o + Vector2(w * 0.38, h * 0.06),   # left prong, inner top
		o + Vector2(w * 0.38, h * 0.22),   # left prong, inner bottom
		o + Vector2(w * 0.50, h * 0.34),   # bottom of the notch
		o + Vector2(w * 0.62, h * 0.22),   # right prong, inner bottom
		o + Vector2(w * 0.62, h * 0.06),   # right prong, inner top
		o + Vector2(w * 0.82, h * 0.06),   # right prong, outer top
		o + Vector2(w * 0.66, h * 0.40),   # right prong, outer bottom -> neck
		o + Vector2(w * 0.60, h * 0.50),   # neck, right
		o + Vector2(w * 0.60, h * 0.86),   # handle, right
		o + Vector2(w * 0.50, h * 0.94),   # handle, tip
		o + Vector2(w * 0.40, h * 0.86),   # handle, left
		o + Vector2(w * 0.40, h * 0.50),   # neck, left
		o + Vector2(w * 0.34, h * 0.40),   # left prong, outer bottom -> neck
	])

## The one entry point every caller uses. is_product picks car vs wrench -
## there is no third card type, so unlike CategoryIcon.draw() this never
## silently draws nothing.
static func draw(ci: CanvasItem, rect: Rect2, is_product: bool, color: Color) -> void:
	if is_product:
		ci.draw_colored_polygon(CategoryIcon.car_body(rect), color)
		var r := CategoryIcon.car_wheel_radius(rect)
		for center in CategoryIcon.car_wheels(rect):
			ci.draw_circle(center, r, color)
	else:
		ci.draw_colored_polygon(wrench(rect), color)
