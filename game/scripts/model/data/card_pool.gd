class_name CardPool extends Resource
## Every card that exists, starter or not, plus the constraint new cards obey.

@export_multiline var design_rule: String
@export var cards: Array[CardDef]

func by_id(wanted: StringName) -> CardDef:
	for c in cards:
		if c.id == wanted:
			return c
	return null

func starter_cards() -> Array[CardDef]:
	var out: Array[CardDef] = []
	for c in cards:
		if c.starter:
			out.append(c)
	return out

func shoppable_cards() -> Array[CardDef]:
	## The shelf's own pool. Starter cards are already in every run's opening
	## deck - offering them for sale too would let a run stack duplicates of a
	## card everyone starts with, instead of the shop being where a run
	## diverges from every other run's deck.
	var out: Array[CardDef] = []
	for c in cards:
		if not c.starter:
			out.append(c)
	return out
