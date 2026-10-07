class_name PlayAppealCard extends DemandResolve
## "Explain it to me." Answered by any support card that adds APPEAL.
##
## Defined by what the card does rather than by its id, like PlayConcession: a
## new appeal card answers it without this file changing, and it reads the
## effects that ACTUALLY executed, so a card that stopped adding appeal would
## stop counting.

func satisfied(kind: StringName, data: Dictionary) -> bool:
	if kind != SUPPORT:
		return false
	for e in data.get("effects", []):
		if adds_appeal(e):
			return true
	return false

## Whether `e` raises appeal - itself, or wrapped (ScaleBySales).
static func adds_appeal(e: Effect) -> bool:
	if e is ChangeAppeal:
		return e.amount > 0
	if e is ScaleBySales:
		return e.inner != null and adds_appeal(e.inner)
	return false

func describe() -> String:
	return "play them an appeal card"

func how_to_answer() -> String:
	return "Play an appeal card."
