class_name OnReject extends Trigger
## Fires when they wave off a card you played on them
## (CustomerArchetype.rejects_every_nth_card) - "told you so" costs them patience
## as well as costing you the card.

func matches(_ctx: EffectContext) -> bool:
	return true

func describe() -> String:
	return "whenever they wave off a card"
