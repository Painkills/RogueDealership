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

@export_group("Difficulty")
## How hard this shift is, in CustomerArchetype.difficulty points - see
## tools/rate_shifts.gd for measuring it.
## - A premade shift with a lineup is FIXED: this is its rating, and the
##   calendar only deals it into a slot whose target is within
##   ShiftConfig.difficulty_tolerance of it. 0 = unrated: dealt by chance alone,
##   whatever the target - the way Monday Open House is.
## - One without a lineup SCALES: this is what its own rules add, and whatever
##   the slot's target leaves is filled with customers and complicators (see
##   ShiftGenerator) - so it can come back, harder, in week 2.
## Every copy the calendar deals carries the total it came to.
@export var difficulty: int = 0
## A regular tier's lineup length: every shift dealt in its slot brings exactly
## this many customers, picked to the slot's difficulty target (ShiftGenerator).
## 0 = the door as it used to be, random and open all shift. On a premade shift
## that scales, its own length in place of the slot's.
@export var customers: int = 0
## A regular tier's difficulty target on day 1 of the run, and how much it
## climbs each day after - see difficulty_on().
@export var difficulty_start: int = 0
@export var difficulty_per_day: float = 0.0

@export_group("Premade shift")
## Ticks in the shift. 0 = ShiftConfig.shift_ticks.
@export var shift_ticks: int = 0
## The shift's own quota, in place of the run's climbing one. 0 = the run's.
@export var quota: int = 0
## How many customers can wait for a chair. 0 = ShiftConfig.waiting_max.
@export var waiting_room: int = 0
## Only these come in - "a shift that has only Karens". The week each archetype
## joins the run (CustomerArchetype.from_week) no longer applies. Empty = the
## usual customers.
@export var only_archetypes: Array[CustomerArchetype] = []
## Exactly these customers, in this order: the first fill the seats, the rest
## come in the door one after another, and nobody comes after the last - the
## shift is over once they are all dealt with. Empty = the door as usual.
@export var lineup: Array[CustomerArchetype] = []
## How likely this shift is to be dealt in place of the regular one, on a day
## and in a slot its category allows - see Week. Only a premade shift uses it.
@export_range(0.0, 1.0, 0.05) var chance: float = 1.0
## The hand you draw to. 0 = ShiftConfig.hand_size. A dealership upgrade's
## bigger hand still adds to it.
@export var hand_size: int = 0
## Added to every customer's Line as they sit down - a tough crowd, or an easy
## one. Never below 0.
@export var line_offset: int = 0
## Multiplies every customer's combo step (CustomerArchetype.combo_step): 0 is
## no combos, 2 double. A dealership upgrade's combo bonus is added after.
@export var combo_scale: float = 1.0
## The shift's own product quota - sell this many from this category - in place
## of the day's (ShiftConfig.category_quota_by_week). A count of 0 = the day's.
@export var product_quota_category: Category = null
@export var product_quota_count: int = 0
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
## Set on a dealt copy of a premade shift that scales: the twists it came with
## to make the slot's difficulty (see ShiftGenerator). Never authored.
var complicators: Array[ShiftComplicator] = []

## This shift's quota on a day whose own is `base` - the one number RunState
## runs it to and the calendar shows.
func quota_on(base: int) -> int:
	return quota if quota > 0 else roundi(base * quota_scale) + quota_offset

## A regular tier's difficulty target on `day` (1-based) of the run.
func difficulty_on(day: int) -> int:
	return roundi(difficulty_start + difficulty_per_day * (day - 1))

## A premade shift without a lineup of its own: it is filled to whatever
## difficulty the slot it is dealt into wants - see `difficulty`.
func scales() -> bool:
	return lineup.is_empty()

## Which of the rules a complicator can change this shift sets itself - see
## ShiftComplicator.touches().
func touches() -> Array[StringName]:
	var out: Array[StringName] = []
	if line_offset != 0:
		out.append(&"line")
	if shift_ticks > 0:
		out.append(&"ticks")
	if patience_scale != 1.0:
		out.append(&"patience")
	if hand_size > 0:
		out.append(&"hand")
	if combo_scale != 1.0:
		out.append(&"combo")
	return out

## The rules the shift is played under - its own, and its complicators' on top.
## `base` is the config's number, for a shift that does not set its own.
func ticks_on(base: int) -> int:
	var ticks := shift_ticks if shift_ticks > 0 else base
	for c in complicators:
		ticks += c.ticks_delta
	return maxi(1, ticks)

func hand_on(base: int) -> int:
	var hand := hand_size if hand_size > 0 else base
	for c in complicators:
		hand += c.hand_size_delta
	return maxi(1, hand)

func total_line_offset() -> int:
	var offset := line_offset
	for c in complicators:
		offset += c.line_offset
	return offset

func total_patience_scale() -> float:
	var scale := patience_scale
	for c in complicators:
		scale *= c.patience_scale
	return scale

func total_combo_scale() -> float:
	var scale := combo_scale
	for c in complicators:
		scale *= c.combo_scale
	return scale

## What a premade shift does differently, for the calendar - its own rules, then
## the complicators it came with. Empty for a regular tier: what sets those
## apart is in their blurbs.
func rules_preview() -> String:
	var parts: Array[String] = []
	if hand_size > 0:
		parts.append("Hand of %d" % hand_size)
	if line_offset != 0:
		parts.append("Line %+d" % line_offset)
	if combo_scale != 1.0:
		parts.append("No combos" if combo_scale <= 0.0 else "Combos x%s" % String.num(combo_scale, 2))
	if product_quota_count > 0 and product_quota_category != null:
		parts.append("Sell %d %s" % [product_quota_count, product_quota_category.display_name])
	if shift_ticks > 0:
		parts.append("%d ticks" % shift_ticks)
	if seats > 0:
		parts.append("1 seat" if seats == 1 else "%d seats" % seats)
	if waiting_room > 0:
		parts.append("%d waiting" % waiting_room)
	if is_premade() and patience_scale != 1.0:
		parts.append("Patience %d%%" % roundi(patience_scale * 100.0))
	for c in complicators:
		if c != null:
			parts.append(c.display_text)
	return ", ".join(parts)

## A non-boss premade shift dealt into `tier`'s slot is paid like that slot:
## the commission, the base pay and the store after it are the tier's, so a
## morning stays a morning's money whatever happens on its floor.
func take_rewards_from(tier: ShiftProfile) -> void:
	commission = tier.commission
	pay_scale = tier.pay_scale
	heal_up_to = tier.heal_up_to
	cards_for_sale = tier.cards_for_sale
	upgrades = tier.upgrades
	free_pick_min_rarity = tier.free_pick_min_rarity
	dealership_upgrades = tier.dealership_upgrades

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
## The free card every shift ends with goes without saying; only what this
## shift's store adds is listed - a better free card, cards to buy or upgrade -
## and what making quota earns on top. Empty when it adds nothing.
func reward_preview() -> String:
	var stocked: Array[String] = []
	if free_pick_min_rarity > 0:
		stocked.append("%s+ free card"
			% String(CardDef.Rarity.keys()[free_pick_min_rarity]).capitalize())
	if cards_for_sale > 0:
		stocked.append("%d to buy" % cards_for_sale)
	if upgrades > 0:
		stocked.append("%d to upgrade" % upgrades)
	# What only making quota earns - a boss's.
	var earned: Array[String] = []
	if heal_up_to > 0.0:
		earned.append("heal")
	if dealership_upgrades > 0:
		earned.append("dealership upgrade")
	var parts: Array[String] = []
	if not stocked.is_empty():
		parts.append("Shop: %s." % " and ".join(stocked))
	if not earned.is_empty():
		parts.append("Make quota: %s." % " + ".join(earned))
	return " ".join(parts)
