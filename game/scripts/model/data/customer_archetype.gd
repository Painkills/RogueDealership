class_name CustomerArchetype extends Resource
## Every archetype exists to teach exactly ONE play pattern, and its numbers
## and actions are chosen to force that pattern rather than decorate it.

@export var id: StringName
@export var display_name: String
@export_multiline var pattern: String    ## the ONE behaviour this teaches
@export_multiline var tell: String       ## what you see on arrival
@export var line: int = 35
@export var patience: int = 16
@export var line_per_sale: int = 3       ## Family First runs at 0
@export var top_interests: Array[Interest]
@export var bottom_interests: Array[Interest]
@export var demands_category: bool = false
## The earliest shift this archetype may walk in on. Nine ticks of patience and
## a floor-wide drain are the two hardest problems in the game, and a first-ever
## run should open with neither. Defaults to 1, so a bare shift is unaffected.
@export var min_shift: int = 1
@export var actions: Array[CustomerAction]
