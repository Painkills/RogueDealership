class_name CardTypeIconControl extends Control
## A badge for CardTypeIcon.draw() - the front's small kind badge and the
## whole card back both slot this in, the same relationship
## CategoryIconControl has with CategoryIcon.

var _is_product: bool = true
var _color: Color = Color.WHITE

func set_type(is_product: bool, color: Color) -> void:
	_is_product = is_product
	_color = color
	visible = true
	queue_redraw()

func _draw() -> void:
	CardTypeIcon.draw(self, Rect2(Vector2.ZERO, size), _is_product, _color)
