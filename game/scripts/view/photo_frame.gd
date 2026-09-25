class_name PhotoFrame extends Control
## The customer's photo on their file - or rather the square where it will go.
## There is no portrait art yet, so this is the placeholder any modern profile
## has: a rounded tile with a head-and-shoulders silhouette in it.
##
## Small on purpose. An old portrait box took 268 of the card's 700 px for a
## grey rectangle, and the interest grid needed that room far more. This one
## sits BESIDE the name, in a row the name was already occupying.
##
## Drawn rather than built from nodes, like CategoryIcon: it is one picture,
## and the silhouette reuses CategoryIcon's own person glyph so "a person" is
## drawn one way everywhere in the game.

const RADIUS := 22

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var tile := StyleBoxFlat.new()
	tile.bg_color = Palette.color(&"photo_bg")
	tile.set_corner_radius_all(RADIUS)
	draw_style_box(tile, r)
	# Inset so the shoulders stop short of the rounded corners.
	var figure := Rect2(r.position + r.size * Vector2(0.14, 0.16), r.size * Vector2(0.72, 0.84))
	draw_circle(CategoryIcon.person_head_center(figure),
		CategoryIcon.person_head_radius(figure), Palette.color(&"photo_figure"))
	draw_colored_polygon(CategoryIcon.person_body(figure), Palette.color(&"photo_figure"))
