class_name PhotoFrame extends Control
## The picture on a customer's file: their archetype's glyph (ArchetypeIcon) on a
## tile of its own colour - or, for an archetype with no glyph yet, the
## placeholder any modern profile has: a rounded tile with a head-and-shoulders
## silhouette in it.
##
## Small on purpose. An old portrait box took 268 of the card's 700 px for a
## grey rectangle, and the interest grid needed that room far more. This one
## sits BESIDE the name, in a row the name was already occupying.
##
## Drawn rather than built from nodes, like CategoryIcon: it is one picture,
## and the silhouette reuses CategoryIcon's own person glyph so "a person" is
## drawn one way everywhere in the game.

## The tile's corner, as a share of its side - 22 px on the folder's 150, and
## the same shape on the small copy the queue shows.
const RADIUS_SHARE := 0.147

## ArchetypeIcon's name for the glyph to draw. Empty, or a name with no glyph:
## the silhouette.
var icon: StringName = &"":
	set(value):
		if value == icon:
			return
		icon = value
		queue_redraw()

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var tile := StyleBoxFlat.new()
	tile.bg_color = ArchetypeIcon.tile_color(icon)
	tile.set_corner_radius_all(roundi(minf(size.x, size.y) * RADIUS_SHARE))
	draw_style_box(tile, r)
	if ArchetypeIcon.has(icon):
		ArchetypeIcon.draw(self, r, icon)
		return
	# Inset so the shoulders stop short of the rounded corners.
	var figure := Rect2(r.position + r.size * Vector2(0.14, 0.16), r.size * Vector2(0.72, 0.84))
	draw_circle(CategoryIcon.person_head_center(figure),
		CategoryIcon.person_head_radius(figure), Palette.color(&"photo_figure"))
	draw_colored_polygon(CategoryIcon.person_body(figure), Palette.color(&"photo_figure"))
