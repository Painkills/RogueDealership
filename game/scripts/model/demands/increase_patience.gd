class_name IncreasePatience extends DemandResolve
## "Calm down, not calmed down FOR you." Answered by their own patience
## actually being higher than it was the moment this demand was raised -
## Shift._demand_saw() hands every resolve that comparison regardless of
## kind, so this reads as true whatever RAISED it: Small Talk today, any
## future patience-granting card or effect tomorrow, without this file
## changing. Unlike PlayConcession it never inspects which effect ran - only
## whether the number actually moved.

func satisfied(_kind: StringName, data: Dictionary) -> bool:
	return int(data.get("patience", 0)) > int(data.get("patience_at_raise", 0))

func describe() -> String:
	return "raise their patience"
