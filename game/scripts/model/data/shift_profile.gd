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

## The shop that follows it.
@export var allow_upgrades_in_shop: bool = true
@export var free_purchases: int = 0          ## dedicated pool, buy() only
@export var free_upgrades: int = 0           ## dedicated pool, upgrade() only
@export var free_choices: int = 0            ## shared pool, first buy() OR upgrade()

## A static preview of the shop reward for the picker screen, BEFORE any of
## it exists to spend - Shop.perk_text() says the same thing from its own
## live, spend-as-you-go pools once a shift is actually underway.
func reward_preview() -> String:
	if free_purchases > 0 and free_upgrades > 0:
		return "Shop: one free purchase and one free upgrade."
	if free_choices > 0:
		return "Shop: your first purchase or upgrade is free."
	if not allow_upgrades_in_shop:
		return "Shop: purchases only, no upgrades."
	return "Shop: purchases and upgrades, as usual."
