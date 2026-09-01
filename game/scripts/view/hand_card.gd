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
	var def := inst.card
	_name.text = def.display_name
	_cost.text = "%dt" % def.ticks
	if inst.is_product():
		var p := def as ProductCardDef
		_kind.text = "PRODUCT  $%s" % Format.money(inst.margin())
		_kind.modulate = Palette.color(&"margin")
		_effect.text = p.interest.category.display_name + " . " + p.interest.display_name
	else:
		var s := def as SupportCardDef
		_kind.text = ""
		var effects := s.upgraded_effects if inst.upgraded and not s.upgraded_effects.is_empty() else s.effects
		var parts: Array[String] = []
		for e in effects:
			parts.append(e.describe())
		_effect.text = ", ".join(parts)
