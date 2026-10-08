class_name SupportCardDef extends CardDef
## A card whose whole content is a list of effects assembled in the
## Inspector - effects/upgraded_effects themselves live on CardDef now, so a
## product can carry them too (Shift.place()).

@export var needs_offer: bool = true

## Whether all this card does is give patience - to one customer, to everyone, or
## over a few ticks. A card you may play on someone you are not standing with
## (Shift.play_card()), because it asks nothing of the table in front of you.
func is_patience_card() -> bool:
	for list in [effects, upgraded_effects]:
		for e in list:
			if not _gives_patience(e):
				return false
	return not effects.is_empty()

static func _gives_patience(e: Effect) -> bool:
	if e is Linger:
		return _gives_patience(e.inner)
	return (e is ChangePatience or e is ChangePatienceFloor) and e.amount > 0
