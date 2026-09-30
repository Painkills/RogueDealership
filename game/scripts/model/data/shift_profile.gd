class_name ShiftProfile extends Resource
## One shift you can pick for the day: one of the regular tiers - morning,
## midday, night - or a premade shift that a ShiftCategory deals onto the
## calendar in a tier's place (see Week). Pure data, same shape as
## CustomerArchetype: everything a picked profile changes about the coming
## shift and the shop that follows it is a number here, never a branch in
## Shift.gd or Shop.gd keyed on an id string.

@export var id: StringName
@export var display_name: String
@export_multiline var blurb: String          ## what to expect, shown on the picker

## The coming shift.
## How many of the floor's chairs are in use. 0 = all of them
## (ShiftConfig.floor_size); never more, since the floor has no others.
@export var seats: int = 0
@export var patience_scale: float = 1.0
## "Fewer customers" without touching the seat count above: the gap between
## one customer coming in the door and the next (Shift._arrival_gap()) is
## multiplied by this, so fewer distinct customers get served across the same
## tick budget while every chair still starts, and stays, physically real.
@export var walk_up_scale: float = 1.0
@export var unlock_full_archetype_pool: bool = false

@export_group("Premade shift")
## Ticks in the shift. 0 = ShiftConfig.shift_ticks.
@export var shift_ticks: int = 0
## The shift's own quota, in place of the run's climbing one. 0 = the run's.
@export var quota: int = 0
## How many customers can wait for a chair. 0 = ShiftConfig.waiting_max.
@export var waiting_room: int = 0
## Only these come in - "a shift that has only Karens". The shift ladder and
## unlock_full_archetype_pool no longer apply. Empty = the usual customers.
@export var only_archetypes: Array[CustomerArchetype] = []
## Exactly these customers, in this order: the first fill the seats, the rest
## come in the door one after another, and nobody comes after the last - the
## shift is over once they are all dealt with. Empty = the door as usual.
@export var lineup: Array[CustomerArchetype] = []
## How likely this shift is to be dealt in place of the regular one, on a day
## and in a slot its category allows - see Week. Only a premade shift uses it.
@export_range(0.0, 1.0, 0.05) var chance: float = 1.0
@export_group("")

## The shop that follows it. Every visit lets you pick one card free whatever
## the tier; these are what the tier adds on top - see Shop.
@export var cards_for_sale: int = 0          ## cards put up for sale
@export var upgrades: int = 0                ## of your cards you may upgrade

## Set on the copy Week deals onto the calendar, never authored: the slot it
## took, and the category that dealt it. A regular tier has neither.
var time_of_day: StringName = &""
var dealt_by: ShiftCategory = null

## Which part of the day it is worked in - &"morning", &"midday" or &"night":
## its hours on the calendar and the tablet's clock, and what the office
## windows show. A tier is its own; a premade shift, the slot it was dealt.
func worked_at() -> StringName:
	return time_of_day if time_of_day != &"" else id

## Dealt by a category, rather than one of the regular tiers.
func is_premade() -> bool:
	return dealt_by != null

## Dealt as a boss day - the only shift on offer that day.
func is_boss_day() -> bool:
	return dealt_by != null and dealt_by.boss_day

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
