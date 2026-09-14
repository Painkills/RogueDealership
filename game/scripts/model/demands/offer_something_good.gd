class_name OfferSomethingGood extends DemandResolve
## "Stop showing me junk." Answered by asking for the business with something
## that actually ranks well on their own list - not just by asking.
##
## The rank-aware sibling of MakeAnOffer, and the only resolve that cares WHAT
## you put in front of them. It is what lets an archetype whose whole pattern
## is "find their bullseye instead of grinding a mediocre product upward" keep
## teaching that pattern once its passive bonus becomes a timed ask.

## Inclusive: 3 means their 1st, 2nd or 3rd interest answers it.
@export var rank_better_than: int = 3

func satisfied(kind: StringName, data: Dictionary) -> bool:
	if kind != OFFER:
		return false
	# Absent rank reads as the worst possible, so a caller that forgets to pass
	# one fails the demand rather than accidentally satisfying it.
	return int(data.get("rank", 99)) <= rank_better_than

func describe() -> String:
	return "offer them something in their top %d" % rank_better_than
