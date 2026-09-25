class_name PhotoFrame extends Control
## The customer's photo, clipped to the front of their file - or rather the
## square where it will go. There is no portrait art yet, so this is the
## placeholder a real file would have: a polaroid with a head-and-shoulders
## silhouette in it, held on by a paper clip.
##
## Small on purpose. The last portrait box took 268 of the card's 700 px for a
## grey rectangle, and the interest grid needed that room far more. This one
## sits BESIDE the name, in a row the name was already occupying.
##
## Drawn rather than built from nodes, like CategoryIcon: it is one picture,
## and the silhouette reuses CategoryIcon's own person glyph so "a person" is
## drawn one way everywhere in the game.

const BORDER := 8.0

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	# A shadow a few pixels down and right, so the photo lies on the page.
	draw_rect(Rect2(r.position + Vector2(4, 5), r.size), Color(0, 0, 0, 0.18))
	draw_rect(r, Palette.color(&"panel_hi"))
	draw_rect(r, Palette.color(&"neutral_3"), false, 2.0)
	var photo := r.grow(-BORDER)
	draw_rect(photo, Palette.color(&"photo_bg"))
	var figure := Rect2(photo.position + Vector2(photo.size.x * 0.1, photo.size.y * 0.12),
		photo.size * Vector2(0.8, 0.88))
	draw_circle(CategoryIcon.person_head_center(figure),
		CategoryIcon.person_head_radius(figure), Palette.color(&"photo_figure"))
	draw_colored_polygon(CategoryIcon.person_body(figure), Palette.color(&"photo_figure"))
	_draw_clip(Vector2(r.size.x * 0.2, -10.0))

## A paper clip over the top edge: two nested loops of wire.
func _draw_clip(at: Vector2) -> void:
	var wire := Palette.color(&"clip")
	var outer := [at + Vector2(0, 34), at + Vector2(0, 6), at + Vector2(6, 0),
		at + Vector2(12, 0), at + Vector2(18, 6), at + Vector2(18, 40)]
	var inner := [at + Vector2(5, 40), at + Vector2(5, 10), at + Vector2(9, 6),
		at + Vector2(13, 10), at + Vector2(13, 30)]
	draw_polyline(PackedVector2Array(outer), wire, 3.0, true)
	draw_polyline(PackedVector2Array(inner), wire, 3.0, true)
