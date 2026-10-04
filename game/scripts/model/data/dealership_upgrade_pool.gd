class_name DealershipUpgradePool extends Resource
## Every dealership upgrade that exists - what a night shift's store offers
## from. See DealershipUpgrade.

@export var upgrades: Array[DealershipUpgrade] = []

func by_id(wanted: StringName) -> DealershipUpgrade:
	for u in upgrades:
		if u != null and u.id == wanted:
			return u
	return null
