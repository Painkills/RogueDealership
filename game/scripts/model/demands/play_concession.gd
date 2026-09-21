class_name PlayConcession extends DemandResolve
## "Come down on it." Answered by any support card that costs you MARGIN.
##
## Defined by what the card does rather than by its id, so Offer a Discount and
## Payment Framing both answer it today and any future card that gives money
## away answers it tomorrow without this file changing. It reads the effects
## that ACTUALLY executed, which is how an upgraded card that stopped conceding
## would correctly stop counting.

func satisfied(kind: StringName, data: Dictionary) -> bool:
	if kind != SUPPORT:
		return false
	for e in data.get("effects", []):
		if e is ChangeMargin and e.amount < 0:
			return true
	return false

func describe() -> String:
	return "give them something off the price"
