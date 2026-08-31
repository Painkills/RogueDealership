class_name CustomerAction extends Resource
## One thing a customer does to you. TELEGRAPHED on arrival: you play around
## known behaviour, and stepping in the trap is on you.

@export var id: StringName
@export var display_name: String         ## "Asks for the manager, loudly"
@export_multiline var tell: String       ## shown before it ever fires
@export var dialogue: String             ## spoken when it fires
@export var trigger: Trigger
@export var effects: Array[Effect]
@export var cooldown: int = 0
