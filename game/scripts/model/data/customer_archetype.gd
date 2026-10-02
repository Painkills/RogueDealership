class_name CustomerArchetype extends Resource
## Every archetype exists to teach exactly ONE play pattern, and its numbers
## and actions are chosen to force that pattern rather than decorate it.

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
@export var top_interests: Array[Interest]
@export var bottom_interests: Array[Interest]
@export var demands_category: bool = false
## Will not take a product they rank worse than this unless something was
## conceded on it first - a card that gave margin away (Offer.conceded). No
## fuse and nothing swept away: the offer just falls short until you come
## down. 0 = takes anything that clears their Line.
@export var needs_concession_past_rank: int = 0
## The day of the run this archetype joins the pool. The run opens on the easy
## ones and adds one more type a day, so each new problem arrives on its own.
## Defaults to 1, so a bare shift is unaffected.
@export var min_shift: int = 1
## How often they come in, relative to everyone else in the pool - not a
## percentage. 0 never.
@export var weight: float = 1.0
## One of the hard ones: never two of the same on the floor at once, and a
## shift can weight them up (ShiftProfile.hard_weight_scale).
@export var hard: bool = false
@export var actions: Array[CustomerAction]
