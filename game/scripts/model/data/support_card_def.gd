class_name SupportCardDef extends CardDef
## A card whose whole content is a list of effects assembled in the Inspector.

@export var needs_offer: bool = true
@export var effects: Array[Effect]
@export var upgraded_effects: Array[Effect]
