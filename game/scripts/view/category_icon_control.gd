class_name CategoryIconControl extends Control
## A badge for CategoryIcon.draw(), for slotting into ordinary Label-based
## layouts wherever a category's name is already written as prose - the hand
## card's body line, the offer detail's sub line - so the same glyph that
## marks a lit row on the interest grid marks the category everywhere else.

var _category_id: StringName = &""
var _color: Color = Color.WHITE

## An empty id hides the badge outright rather than drawing nothing into a
## visible box. Both places this is used share ONE row with text that is not
## always a category - a support card's effects, an archetype's own name -
## and those cases must not reserve a blank square next to themselves.
func set_category(category_id: StringName, color: Color) -> void:
	_category_id = category_id
	_color = color
	visible = category_id != &""
	queue_redraw()

func _draw() -> void:
	if _category_id == &"":
		return
	CategoryIcon.draw(self, Rect2(Vector2.ZERO, size), _category_id, _color)
