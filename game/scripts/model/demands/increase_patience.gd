class_name IncreasePatience extends DemandResolve
## "Calm down, not calmed down FOR you." Answered by their own patience
## actually being higher than it was the moment this demand was raised -
## Shift._demand_saw() hands every resolve that comparison regardless of
## kind, so this reads as true whatever RAISED it: Small Talk today, any
## future patience-granting card or effect tomorrow, without this file
## changing. Unlike PlayConcession it never inspects which effect ran - only
## whether the number actually moved.

##
## Also answered by whatever you just did RAISING it, wherever it started: their
## patience keeps draining while they wait, so after three ticks a sale's +3
## only got them back to where they asked - and "the increase of patience caused
## by an accepted offer is NOT clearing the karen's request for a manager."
func satisfied(_kind: StringName, data: Dictionary) -> bool:
	var now := int(data.get("patience", 0))
	if now > int(data.get("patience_at_raise", 0)):
		return true
	return data.has("patience_before") and now > int(data["patience_before"])

func describe() -> String:
	return "raise their patience"

func how_to_answer() -> String:
	return "Raise their patience: play a patience card, or close a sale."
