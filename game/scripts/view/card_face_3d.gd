class_name CardFace3D extends Card3D
## One physical card on the table.
##
## Inherits the vendored Card3D scene and hangs Label3D text on its front. The
## labels live under CardMesh/Front, NOT under the root: face_down rotates
## CardMesh by PI, so text parented anywhere else would keep facing the camera
## and float over the card's own back.
##
## setup() is re-run on every reconcile rather than only on creation, which is
## what keeps a product's margin honest while ChangeMargin mutates the live
## offer underneath it. That is the whole reason this face is text nodes and not
## a baked texture.

## World units per font pixel. One number decides how big every word on every
## card is; tune here, not per-label. See PIXEL_SIZE in card_face_3d.tscn - the
## scene and this constant must agree.
const PIXEL_SIZE := 0.02

var uid: int = -1
var instance: CardInstance

# Resolved on first use, NOT @onready. Reconciliation calls setup() on a card
# the moment it is instantiated, before it has been added to a collection and
# therefore before _ready() has run - at which point @onready vars are still
# null. The child nodes themselves exist as soon as the scene is instantiated,
# so looking them up on demand is always safe and @onready is not.
var _name: Label3D
var _cost: Label3D
var _kind: Label3D
var _body: Label3D
var _margin: Label3D

func _resolve_labels() -> void:
	if _name != null:
		return
	var front := $CardMesh/Front
	_name = front.get_node(^"NameLabel")
	_cost = front.get_node(^"CostLabel")
	_kind = front.get_node(^"KindLabel")
	_body = front.get_node(^"BodyLabel")
	_margin = front.get_node(^"MarginLabel")

func setup(inst: CardInstance) -> void:
	_resolve_labels()
	instance = inst
	uid = inst.uid

	_name.text = CardText.title(inst)
	_cost.text = CardText.cost(inst)
	_kind.text = CardText.kind(inst)
	_body.text = CardText.body(inst)
	_margin.text = CardText.margin(inst)

	_name.modulate = Palette.color(&"text")
	_cost.modulate = Palette.color(&"text_dim")
	_body.modulate = Palette.color(&"text")
	if inst.is_product():
		_kind.modulate = Palette.color(&"accent")
		_margin.modulate = Palette.color(&"margin")
	else:
		_kind.modulate = Palette.color(&"action")
		_margin.modulate = Palette.color(&"text_dim")

	# An upgraded card should be obvious without reading it.
	_name.outline_modulate = Palette.color(&"appeal") if inst.upgraded else Palette.color(&"neutral_1")
