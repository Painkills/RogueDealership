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
## Never come in on this shift, whatever else lets them - "remove Lay-Down
## Larry and Easygoing from the night pool".
@export var excluded_archetypes: Array[CustomerArchetype] = []
## Multiplies the weight of every hard archetype (CustomerArchetype.hard) in
## this shift's pool - night brings in more of the difficult ones.
@export var hard_weight_scale: float = 1.0
## Lets two of the same hard archetype share the floor - see
## ShiftConfig.unique_archetypes_on_floor, which this shift waives.
@export var allow_hard_duplicates: bool = false
## Per-archetype multipliers on CustomerArchetype.weight for this shift, by
## archetype id - {&"family": 0.5} makes Family First half as common. Anyone
## not named keeps their own weight.
@export var archetype_weight_scales: Dictionary[StringName, float] = {}
## The first day of the run this shift is offered on - a regular tier only
## shows on the calendar from then. See Week.
@export var from_day: int = 1
## Heals standing by up to this fraction of the run's full standing (0.25 = up
## to 25 of 100): all of it for making quota, a share of it for banking that
## share of the quota. On top of anything missing quota costs. The boss fights'
## reward - see Shift.healed().
@export_range(0.0, 1.0, 0.05) var heal_up_to: float = 0.0
## The shift's quota against the run's climbing one: scaled by this, then
## `quota_offset` added. Raising an easy shift's quota makes it pay less - the
## bonus is only what you bank OVER quota. A flat offset costs the same every
## day of the week; a scale bites harder as the quota climbs. A premade
## shift's own `quota` replaces both outright.
@export var quota_scale: float = 1.0
@export var quota_offset: int = 0            ## dollars; negative lowers it
## Commission: this share of what you bank OVER quota is paid on top of the
## base salary - a harder shift paying out in money as well as in what its
## store stocks (morning lowest, then midday, night, and the boss highest). See
## RunState.bonus_from().
@export_range(0.0, 1.0, 0.01) var commission: float = 0.25
## The base salary for working this shift, as a multiple of the week's
## (ShiftConfig.paycheck_in_week) - a night differential. It is paid whether or
## not quota is made, so it is the part of a shift's reward you can count on.
@export_range(0.0, 3.0, 0.05) var pay_scale: float = 1.0

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
## A budget shift: every customer comes in with their archetype's budget
## (CustomerArchetype.budget) times this, and there is no clock - it is over
## when the whole lineup has been dealt with, and what presses you is their
## patience, which every card you play still wears down. Needs a lineup, or
## nothing would ever end it. 0 = an ordinary shift, on the clock.
@export var budget_scale: float = 0.0
## How likely this shift is to be dealt in place of the regular one, on a day
## and in a slot its category allows - see Week. Only a premade shift uses it.
@export_range(0.0, 1.0, 0.05) var chance: float = 1.0
@export_group("")

## The store that follows it. Every visit starts with one card free, picked
## from a few, whatever the shift; this is what the store holds after that -
## see Shop. Buy or upgrade as many of them as the bonus covers.
@export var cards_for_sale: int = 0          ## cards put up for sale
@export var upgrades: int = 0                ## of your cards offered for an upgrade
## The lowest rarity the free pick after this shift offers - a boss's reward.
@export_enum("Basic", "Economy", "Value", "Preferred") var free_pick_min_rarity: int = 0
## How many dealership upgrades the store after this shift offers, to pick ONE
## from for the rest of the run - night's reward. 0 = none. See
## DealershipUpgrade.
@export var dealership_upgrades: int = 0

## Set on the copy Week deals onto the calendar, never authored: the slot it
## took, and the category that dealt it. A regular tier has neither.
var time_of_day: StringName = &""
var dealt_by: ShiftCategory = null

## This shift's quota on a day whose own is `base` - the one number RunState
## runs it to and the calendar shows.
func quota_on(base: int) -> int:
	return quota if quota > 0 else roundi(base * quota_scale) + quota_offset

## Which part of the day it is worked in - &"morning", &"midday" or &"night":
## its hours on the calendar and the tablet's clock, and what the office
## windows show. A tier is its own; a premade shift, the slot it was dealt.
func worked_at() -> StringName:
	return time_of_day if time_of_day != &"" else id

## Dealt by a category, rather than one of the regular tiers.
func is_premade() -> bool:
	return dealt_by != null

## Dealt as a boss - see ShiftCategory.boss_day.
func is_boss_day() -> bool:
	return dealt_by != null and dealt_by.boss_day

## A static preview of the shop that follows, for the picker screen, BEFORE any
## of it exists - Shop.perk_text() says the same thing from the live visit.
func reward_preview() -> String:
	var free := "a free card"
	if free_pick_min_rarity > 0:
		free += " (%s or better)" % String(CardDef.Rarity.keys()[free_pick_min_rarity]).capitalize()
	var extras: Array[String] = []
	if cards_for_sale > 0:
		extras.append("%d to buy" % cards_for_sale)
	if upgrades > 0:
		extras.append("%d to upgrade" % upgrades)
	# What only making quota earns - a boss's.
	var earned: Array[String] = []
	if heal_up_to > 0.0:
		earned.append("heal")
	if dealership_upgrades > 0:
		earned.append("dealership upgrade")
	var tail := " Make quota: %s." % " + ".join(earned) if not earned.is_empty() else ""
	if extras.is_empty():
		return "Shop: pick %s.%s" % [free, tail]
	return "Shop: pick %s, then a store with %s.%s" % [free, " and ".join(extras), tail]
