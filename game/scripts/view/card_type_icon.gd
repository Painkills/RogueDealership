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

## A wrench: a diagonal handle with a round head at each end.
static func wrench_handle(rect: Rect2) -> PackedVector2Array:
	var o := rect.position
	var w := rect.size.x
	var h := rect.size.y
	return PackedVector2Array([
		o + Vector2(w * 0.18, h * 0.88),
		o + Vector2(w * 0.32, h * 0.74),
		o + Vector2(w * 0.68, h * 0.26),
		o + Vector2(w * 0.82, h * 0.12),
		o + Vector2(w * 0.74, h * 0.04),
		o + Vector2(w * 0.60, h * 0.18),
		o + Vector2(w * 0.26, h * 0.50),
		o + Vector2(w * 0.10, h * 0.66),
	])

static func wrench_head_centers(rect: Rect2) -> PackedVector2Array:
	var o := rect.position
	return PackedVector2Array([
		o + Vector2(rect.size.x * 0.14, rect.size.y * 0.90),
		o + Vector2(rect.size.x * 0.86, rect.size.y * 0.10),
	])

static func wrench_head_radius(rect: Rect2) -> float:
	return rect.size.x * 0.16

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
		ci.draw_colored_polygon(wrench_handle(rect), color)
		var r := wrench_head_radius(rect)
		for center in wrench_head_centers(rect):
			ci.draw_circle(center, r, color)
