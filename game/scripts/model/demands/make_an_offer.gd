class_name MakeAnOffer extends DemandResolve
## "Stop talking and give me a price." Answered by asking for the business,
## whether or not they take it - the demand is about being asked, not about
## the answer. A support card does not count, which is what separates this
## from PlayAnySupport: it cannot be satisfied by stalling.

func satisfied(kind: StringName, _data: Dictionary) -> bool:
	return kind == OFFER

func describe() -> String:
	return "ask them for the business"
