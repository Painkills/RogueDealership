class_name ArchetypePool extends Resource
@export_multiline var design_rule: String
@export var archetypes: Array[CustomerArchetype]
@export var names: Array[String]

func by_id(wanted: StringName) -> CustomerArchetype:
	for a in archetypes:
		if a.id == wanted:
			return a
	return null
