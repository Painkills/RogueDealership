class_name ShiftProfile extends Resource
## One of the tiers you can pick for the next shift - morning, midday, or
## night. Pure data, same shape as CustomerArchetype: everything a picked
## profile changes about the coming shift and the shop that follows it is a
## number here, never a branch in Shift.gd or Shop.gd keyed on an id string.

@export var id: StringName
@export var display_name: String
@export_multiline var blurb: String          ## what to expect, shown on the picker

## The coming shift.
## NOT currently wired into any shipped profile: the 3D floor's carousel
## (shift_controller.gd's station_for(), 120 degrees apart, hard-coded mod 3)
## and its fixed-size per-seat node arrays are built for exactly
## ShiftConfig.floor_size chairs and are not yet safe for a smaller live
## count. Reserved for once that carousel supports a variable seat count.
@export var floor_size_override: int = 0     ## 0 = use ShiftConfig.floor_size
@export var patience_scale: float = 1.0
## "Fewer customers" without touching the seat count above: every empty
## chair's wait for its next walk-up (Shift._vacate()) is multiplied by
## this, so fewer distinct customers get served across the same tick budget
## while every chair still starts, and stays, physically real.
@export var walk_up_scale: float = 1.0
@export var unlock_full_archetype_pool: bool = false

## The shop that follows it. Every visit lets you pick one card free whatever
## the tier; these are what the tier adds on top - see Shop.
@export var cards_for_sale: int = 0          ## cards put up for sale
@export var upgrades: int = 0                ## of your cards you may upgrade

## A static preview of the shop that follows, for the picker screen, BEFORE any
## of it exists - Shop.perk_text() says the same thing from the live visit.
func reward_preview() -> String:
	var extras: Array[String] = []
	if cards_for_sale > 0:
		extras.append("a card to buy" if cards_for_sale == 1
			else "%d cards to buy" % cards_for_sale)
	if upgrades > 0:
		extras.append("an upgrade" if upgrades == 1 else "%d upgrades" % upgrades)
	if extras.is_empty():
		return "Shop: pick a free card."
	return "Shop: pick a free card, and %s." % " and ".join(extras)
