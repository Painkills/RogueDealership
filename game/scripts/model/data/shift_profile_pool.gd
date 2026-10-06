class_name ShiftProfilePool extends Resource
## The three tiers a player may pick between before a shift, and the premade
## shifts that sometimes take a tier's place. Same shape as ArchetypePool: a
## design_rule, the Arrays, and a by_id lookup.

@export_multiline var design_rule: String
@export var profiles: Array[ShiftProfile]
## Premade shifts, pooled by when they may be dealt - see ShiftCategory and
## Week. Empty = the regular tiers every day.
@export var categories: Array[ShiftCategory] = []
## The twists a premade shift that scales may be dealt with, to make a harder
## slot's difficulty - see ShiftComplicator and ShiftGenerator.
@export var complicators: Array[ShiftComplicator] = []

func by_id(wanted: StringName) -> ShiftProfile:
	for p in profiles:
		if p.id == wanted:
			return p
	return null
