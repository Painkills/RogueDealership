class_name IncreasePatience extends DemandResolve
## "Calm down, not calmed down FOR you." Answered by their patience being
## RAISED since they asked - Customer.patience_raises, which counts every raise
## through add_patience(): a card played on them or on the whole floor, a sale,
## anything, and one at full patience too, where the number itself cannot move.
## Not "is it higher than when they asked": their patience drains while they
## wait, so a raise that only got them back to where they were still answered
## them ("the increase of patience caused by an accepted offer is NOT clearing
## the karen's request for a manager").
##
## Whoever the raise came from, the shift asks after every burn (Shift._burn()),
## so Smooth Jazz played on one customer answers a Karen at the next desk.
func satisfied(_kind: StringName, data: Dictionary) -> bool:
	return int(data.get("patience_raises", 0)) > int(data.get("patience_raises_at_raise", 0))

func met_on_expiry(data: Dictionary) -> bool:
	return satisfied(&"", data)

func describe() -> String:
	return "raise their patience"

func how_to_answer() -> String:
	return "Raise their patience: play a patience card, or close a sale."
