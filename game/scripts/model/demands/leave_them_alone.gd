class_name LeaveThemAlone extends DemandResolve
## "Give us a minute." The inverted demand: the fuse running out is the ANSWER,
## and touching them at all before it does is the failure.
##
## PRESENT is what makes this a real decision rather than a free pause. It fires
## when a tick burns while you are standing with them, so you cannot satisfy
## this by standing there doing nothing - and since walking is free and the
## clock only moves when you WORK, the only way to spend their minute is to go
## and spend it on somebody else. That is the whole triage loop in one card.

func satisfied(_kind: StringName, _data: Dictionary) -> bool:
	return false

func broken_by(kind: StringName, _data: Dictionary) -> bool:
	return kind == SUPPORT or kind == PLACE or kind == OFFER \
		or kind == CLOSE or kind == PRESENT

func succeeds_on_expiry() -> bool:
	return true

func describe() -> String:
	return "go and work someone else until they are ready"
