extends PanelContainer
## One card in hand. Purely a renderer: it knows how to show a CardInstance
## and how to say "I was clicked". It never calls a Shift method itself.

signal pressed

var index: int = -1
var instance: CardInstance

@onready var _name: Label = %NameLabel
@onready var _cost: Label = %CostLabel
@onready var _kind: Label = %KindLabel
@onready var _effect: Label = %EffectLabel
@onready var _clicker: Button = %Clicker

func _ready() -> void:
	_clicker.pressed.connect(func(): pressed.emit())

func setup(inst: CardInstance) -> void:
	instance = inst
	# Wording lives in CardText so this face and the 3D one cannot drift apart.
	_name.text = CardText.title(inst)
	_cost.text = CardText.cost(inst)
	_effect.text = CardText.body(inst)
	if inst.is_product():
		_kind.text = "PRODUCT  %s" % CardText.margin(inst)
		_kind.modulate = Palette.color(&"margin")
	else:
		_kind.text = ""
