class_name PlayAnySupport extends DemandResolve
## "Engage with me." Any support card played on them counts - Explain, Small
## Talk, Read the Room, a concession, anything. The cheapest demand to answer
## and the one to reach for when the point is that you turned up at all.

func satisfied(kind: StringName, _data: Dictionary) -> bool:
	return kind == SUPPORT

func describe() -> String:
	return "play them any support card"
