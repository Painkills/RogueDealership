class_name CustomerArchetype extends Resource
## Every archetype exists to teach exactly ONE play pattern, and its numbers
## and actions are chosen to force that pattern rather than decorate it. What
## they want is not part of it: everyone's interests are ranked at random
## (Customer.make_ranks).

@export var id: StringName
@export var display_name: String
@export_multiline var pattern: String    ## the ONE behaviour this teaches
@export_multiline var tell: String       ## what you see on arrival
@export var line: int = 35
@export var patience: int = 16
@export var line_per_sale: int = 3       ## Lay-Down Larry runs at 0
## Extra margin multiplier per product ALREADY sold to this customer this
## visit - see Shift._settle(). Low for an easy moneybag (cheap to chain,
## not very lucrative to), high for someone worth the trouble of keeping
## seated. Every archetype sets this explicitly; nothing should rely on this
## default. Unrelated to Shift.sale_streak, a separate floor-wide streak.
@export var combo_step: float = 0.15
@export var demands_category: bool = false
## Will not take a product they rank worse than this unless something was
## conceded on it first - a card that gave margin away (Offer.conceded). No
## fuse and nothing swept away: the offer just falls short until you come
## down. 0 = takes anything that clears their Line.
@export var needs_concession_past_rank: int = 0
## Waves off every this-many-th card played on them - products and support
## cards alike: the card is spent, its ticks are gone, and nothing it does
## happens (Shift._reject()). Telegraphed the card before. 0 = never.
@export var rejects_every_nth_card: int = 0
## Will only look at products in this category - nothing else can even be put
## in front of them (Shift.place()). Its interests rank first, the way the
## category a Karen came in for does. Empty = anything.
@export var only_category: Category = null
## Sits down with this share of their patience - 0.5 is half. 0 = the usual
## arrival roll (ShiftConfig.arrival_patience_min_fraction).
@export var arrival_patience_share: float = 0.0
## Paid on signing for every point of patience they still have (Shift.close()).
## 0 = nothing.
@export var pays_per_patience_left: int = 0
## A sale of a product for one of these interests pays premium_margin_scale
## times its margin (Shift._settle()).
@export var premium_interests: Array[Interest] = []
@export var premium_margin_scale: float = 1.0
## What they will spend on a budget shift (ShiftProfile.budget_scale): dollars of
## what you sell them, the same dollars as a product's margin. A sale spends from
## it, and they will not take a product that costs more than they have left.
## 0 = no budget - they take whatever they are shown.
@export var budget: int = 0
## The day of the run this archetype joins the pool. The run opens on the easy
## ones and adds two more types a day.
## Defaults to 1, so a bare shift is unaffected.
@export var min_shift: int = 1
## How often they come in, relative to everyone else in the pool - not a
## percentage. 0 never.
@export var weight: float = 1.0
## One of the hard ones: never two of the same on the floor at once, and a
## shift can weight them up (ShiftProfile.hard_weight_scale).
@export var hard: bool = false
@export var actions: Array[CustomerAction]

## Their budget on a shift whose budgets are scaled by `scale`, to the nearest
## $50 - 0 for someone without one, or on a shift without budgets.
func budget_at(scale: float) -> int:
	if budget <= 0 or scale <= 0.0:
		return 0
	return roundi(budget * scale / 50.0) * 50
