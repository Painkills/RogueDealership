class_name SupportCardDef extends CardDef
## A card whose whole content is a list of effects assembled in the
## Inspector - effects/upgraded_effects themselves live on CardDef now, so a
## product can carry them too (Shift.place()).

@export var needs_offer: bool = true
