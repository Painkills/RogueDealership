class_name DealershipUpgrade extends Resource
## A run-wide improvement to the dealership itself - picked after a night shift
## (ShiftProfile.dealership_upgrades), kept for the rest of the run, and felt on
## every shift after it. Each one is owned at most once.
##
## Pure data, same shape as a card: every field below is a bonus that does
## nothing at its default, so an upgrade is whichever of them it sets - and a
## new one is a new .tres in data/dealership_upgrades, never a code change.
## Shift reads them all summed together - see Shift.perk().

@export var id: StringName
@export var display_name: String
@export_multiline var blurb: String          ## what it does, in the store

@export_group("What it does")
## Cards in your hand.
@export var hand_size: int = 0
## Every customer's patience - the most they can have and what they walk in
## with, both.
@export var patience: int = 0
## Added to every customer's Line as they sit down: negative makes them easier
## to sell to. Never takes a Line below 0.
@export var line: int = 0
## Added to every bit of appeal one of your cards or products adds - a card
## that adds +4 adds +5 with this at 1.
@export var appeal_per_card: int = 0
## Every product's margin, as a share on top: 0.05 is +5%.
@export var margin: float = 0.0
## Added to every customer's combo step - see CustomerArchetype.combo_step.
@export var combo_step: float = 0.0
## Who is already waiting for a chair when every shift opens - on top of
## whoever the door sends. Never more than the waiting room holds.
@export var waiting_at_open: Array[CustomerArchetype] = []
## Makes the Line drop of one brand of cards bigger: line_drop_extra 1.0 on
## brand &"walkaway" doubles every Line a WALKAWAY card lowers. Empty brand =
## every card. Raising a Line is never touched.
@export var line_drop_brand: StringName = &""
@export var line_drop_extra: float = 0.0
@export_group("")


## `field` summed over every upgrade in `owned` - 0 when none sets it.
static func total(owned: Array, field: StringName) -> float:
	var sum := 0.0
	for u in owned:
		if u != null:
			sum += float(u.get(field))
	return sum
