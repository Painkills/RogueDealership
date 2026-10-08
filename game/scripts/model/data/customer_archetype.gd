class_name CustomerArchetype extends Resource
## Every archetype exists to teach exactly ONE play pattern, and its numbers
## and actions are chosen to force that pattern rather than decorate it. What
## they want is not part of it: everyone's interests are ranked at random
## (Customer.make_ranks).

@export var id: StringName
@export var display_name: String
## What the customers of this archetype are called - a pun on it, so a name says
## who is sitting down. Each takes one from here, none twice on a floor until the
## list runs out, and no name belongs to two archetypes. Empty: they are named
## from the shared pool (ArchetypePool.names).
@export var names: Array[String] = []
## The picture on their folder, by ArchetypeIcon's name for it. Empty: the plain
## head-and-shoulders silhouette.
@export var icon: StringName = &""
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
## Ranks their interests a category at a time: their favourite category takes
## the top ranks, the next category the ranks after it, and so on - shuffled
## within each. One rank you learn then places its whole category, and Active
## Listening names the category they want most rather than one interest (see
## Customer.reveal_room()). The Karen's - they came in for a category. Off:
## ranked interest by interest, at random.
@export var ranks_by_category: bool = false
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
## The week of the run this archetype starts coming in: the hardest are held
## back for week 2. Within its week anyone unlocked may come in on any day -
## how many of the difficult ones a shift brings is its difficulty budget's
## business (see `difficulty` and ShiftGenerator). Defaults to 1, so a bare
## shift is unaffected.
@export var from_week: int = 1
## How much harder this customer makes a shift, in points: a shift's difficulty
## is what its customers add up to (plus its own rules - see
## ShiftProfile.difficulty). Measured with tools/rate_shifts.gd -- archetypes.
@export var difficulty: int = 1
## How often they come in, relative to everyone else in the pool - not a
## percentage. 0 never.
@export var weight: float = 1.0
## One of the hard ones: never two of the same on the floor at once, and a
## shift can weight them up (ShiftProfile.hard_weight_scale).
@export var hard: bool = false
@export var actions: Array[CustomerAction]

@export_group("Boss")
## Comes in with this share of the shift's quota to spend - 1.0 is all of it.
## Every sale spends its margin from it, and the last takes whatever is left
## (Shift._settle()); once it is gone they have nothing more to buy. 0 = they
## spend freely.
@export var budget_share: float = 0.0
## Their patience soaks up hits: a Hit comes out of it first, and only what it
## cannot cover reaches your standing. At 0 they do not walk out - the next hit
## just lands on you in full. (The words on screen only ever call it patience.)
@export var patience_is_shield: bool = false
## A boss's moves: one at a time, telegraphed with its fuse on their card, each
## raised as a Demand (what answers it, and what ignoring it costs - a Hit). A
## round deals every move once, in an order drawn fresh each round; skipped is
## any move that cannot apply yet (Demand.needs_offer_on_table).
@export var moves: Array[Demand] = []
## Moves that come on a clock of their own, ahead of the rotation - see TimedMove.
@export var timed_moves: Array[TimedMove] = []
## Ticks between one move landing or being answered and the next appearing. 0
## and a boss is never quiet: something is always on its way.
@export var move_gap_ticks: int = 1
## Every product they buy leaves your deck for the rest of the fight - they will
## not take it twice, so it would only clog the draw pile.
@export var sold_products_leave_deck: bool = false
## The time limit: every round after the first, each Hit lands this much
## harder...
@export var escalate_damage: int = 2
## ...and each move's fuse is this many ticks shorter - never below
## min_move_fuse.
@export var escalate_fuse: int = 1
@export var min_move_fuse: int = 1
@export_group("")

## Whether this is a boss fight rather than a customer: they come in with a
## budget to drain or moves to make.
func is_boss() -> bool:
	return budget_share > 0.0 or not moves.is_empty() or not timed_moves.is_empty()
