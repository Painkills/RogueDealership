class_name LeaveThemAlone extends DemandResolve
## "Give us a minute." The inverted demand: the fuse running out is the ANSWER,
## and playing anything on them before it does is the failure.
##
## Only what you DO to them breaks it - a card, a product, an offer, a close.
## Standing with them while the clock moves does not: their minute can be spent
## anywhere, here included, as long as nothing is played on them.

func satisfied(_kind: StringName, _data: Dictionary) -> bool:
	return false

func broken_by(kind: StringName, _data: Dictionary) -> bool:
	return kind == SUPPORT or kind == PLACE or kind == OFFER or kind == CLOSE

func succeeds_on_expiry() -> bool:
	return true

func describe() -> String:
	return "play nothing on them until they are ready"

func how_to_answer() -> String:
	return "Leave them alone: play nothing on them until they are ready."
