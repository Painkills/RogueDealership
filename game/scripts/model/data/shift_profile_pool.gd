class_name ShiftProfilePool extends Resource
## The three tiers a player may pick between before a shift. Same shape as
## ArchetypePool: a design_rule, one Array, and a by_id lookup.

@export_multiline var design_rule: String
@export var profiles: Array[ShiftProfile]

func by_id(wanted: StringName) -> ShiftProfile:
	for p in profiles:
		if p.id == wanted:
			return p
	return null
