class_name ShiftConfig extends Resource
## Every number the game plays with lives here and nowhere else, so a retune
## is a data edit and the tests catch it if a RULE moved instead of a number.

@export_multiline var design_rule: String

@export var shift_ticks: int = 24
@export var quota: int = 3600
@export var floor_size: int = 3
## Ticks between one customer coming in the door and the next, rolled fresh
## each time rather than fixed - a door that always opened on the same tick
## told you exactly when to be looking at it, which is the opposite of the
## triage pressure the floor is supposed to apply. They come in whether or
## not a chair is free, and wait for one (see waiting_max).
@export var walk_up_ticks_min: int = 6
@export var walk_up_ticks_max: int = 8
## How many customers can be waiting for a chair at once. Nobody else comes in
## while that many are - the door's clock waits with them - so a floor you are
## slow to clear stops drawing people in rather than stacking up a crowd. At
## least one: with no room to wait, nobody could come in to a full floor, and
## the floor's "next customer in N ticks" would have no answer.
@export_range(1, 10, 1, "or_greater") var waiting_max: int = 3

# --- the run ---------------------------------------------------------------
@export var shifts_in_run: int = 5
## A working week: the calendar shows one at a time, a category's weekday
## checkboxes count days within one, and a report comes between them.
@export var days_per_week: int = 5
## The quota climbs this fraction each shift, so the run keeps pace with a deck
## that is getting stronger in the shop between them.
@export var quota_growth: float = 0.15
## How far a premade shift's rating (ShiftProfile.difficulty) may sit from a
## slot's difficulty target and still be dealt there - see Week.
@export var difficulty_tolerance: int = 1
## How much of a scaling premade shift's spare difficulty - what its slot's
## target leaves over the cheapest lineup it could bring - goes to complicators
## rather than tougher customers (ShiftGenerator). 0 = customers only.
@export_range(0.0, 1.0, 0.05) var complicator_share: float = 0.3
## The run's HP. Standing hits 0 and the run ends, same as running out of
## shifts - a scorecard with no stakes was the whole problem this fixes.
@export var standing_start: int = 100
## Missing quota costs standing: never less than this, however close you came -
## "you shouldn't be able to 'lose' and keep going."
@export var miss_standing_min: int = 15
## ...and more the further short you fell, up to this at nothing banked. One
## entry per week of the run; weeks past the end use the last.
@export var miss_standing_max_by_week: Array[int] = [35, 45]
## Base salary: what a shift pays however it went, so one bad shift does not
## also mean a shop you cannot buy anything in. Beating quota adds a commission
## on top - see RunState.bonus_from() and ShiftProfile.commission.
@export var paycheck: int = 1000
## "Base pay should increase each week by a little bit": this much more in each
## week after the first. The end-of-week report says so.
@export var paycheck_raise_per_week: int = 100

## Base salary in `week` (1-based).
func paycheck_in_week(week: int) -> int:
	return paycheck + paycheck_raise_per_week * maxi(0, week - 1)
## Product quotas: from week 2, the boss names a category for each day and
## wants this many of its products sold on every shift but a boss day's. One
## entry per week of the run, weeks past the end using the last; 0 = none that
## week.
@export var category_quota_by_week: Array[int] = [0, 2]
## ...and missing it costs this much standing at the end of the shift.
@export var category_quota_standing: int = 10

## The product quota for a day in `week` (1-based) - see category_quota_by_week.
func category_quota_in_week(week: int) -> int:
	if category_quota_by_week.is_empty():
		return 0
	return category_quota_by_week[clampi(week - 1, 0, category_quota_by_week.size() - 1)]

## Zeroed in the shipped data: an ordinary shift never heals. A shift can heal
## on its own terms instead - see ShiftProfile.heal_up_to, which the boss
## fights use.
@export var standing_heal_scale: float = 15.0
## A walkout costs standing on its own, separate from the quota-delta above -
## letting people leave should threaten the job by itself, not only a thin
## till. Uniform per walkout regardless of who they were or what they had
## unsigned - a guess like every other standing number, not measured play.
@export var standing_cost_per_walkout: int = 8

@export var hand_size: int = 5
## A hand with no product in it is nearly a dead turn: needs_offer defaults to
## true, so 6 of the 8 starter support cards refuse to play with an empty table
## and dig is the only move left. This floors that away. 1 fires on the ~2.8% of
## hands that hold no product at all; 2 would fire on ~24% and hand you a second
## probe, which is a balance change rather than a guard. 0 disables the bias.
@export var hand_min_products: int = 1
## 0: walking the floor is free, and the clock measures WORK instead of
## distance. A tick to cross the floor made checking on someone and coming
## back cost 2 of 24, so the cheapest play was to never look up - a tax on
## exactly the decision this game is supposed to be about. Kept as a knob
## rather than deleted: if free movement reads as too loose, the charge is
## this one number, and it applies uniformly rather than discounting the
## walk back to whoever you were last with.
@export var approach_ticks: int = 0
@export var place_ticks: int = 1
@export var dig_ticks: int = 1
@export var failed_offer_patience: int = 1

## One rung of appeal: what a product opens at drops by this for every place
## down their list. Cards and Lines are tuned in rungs and half rungs of it.
@export var appeal_step: int = 4
@export var line_per_sale: int = 3
@export var patience_per_sale: int = 3
@export var patience_jitter: int = 2
## The appeal meter's own ceiling - fixed, not fitted to whatever the current
## negotiation happens to need. It used to grow (and only ever grow) to
## whatever the live appeal or Line required, which meant the bar's own scale
## was a different number on every card and every customer - "read this bar"
## was a skill you had to relearn per negotiation. A flat number instead: pick
## one comfortably above the highest Line anyone opens at (today's ceiling is
## the Tech Enthusiast's 30, which climbs as they buy) plus real headroom for
## appeal cards to stack on top of it. Appeal or Line past this just reads as a full bar rather than
## breaking anything - draw() already clamps the fill fraction to 1.0.
@export var appeal_meter_scale: int = 64

@export var arrival_patience_min_fraction: float = 0.6
@export var arrival_patience_floor: int = 4
@export var leaving_soon_at: int = 4
## A customer says so out loud once their patience is down to this or less -
## once per dip, the way the leaving-soon warning is logged once. A point above
## leaving_soon_at on purpose: they grumble just before their file turns red,
## while there is still time to do something about it.
@export var impatient_at: int = 5
## Ticks remaining in the WHOLE SHIFT, not one customer's patience, at which
## the clock starts warning you to close out what is unsigned before the bell
## takes it for free. See Shift.ticks_running_low().
@export var low_tick_warning: int = 5

# --- demands ---------------------------------------------------------------
## How long a customer sits before they may ask you for anything. Walking up
## and immediately making a demand reads as a bug rather than as character,
## and leaves no room to have chosen to see them first.
@export var demand_grace_ticks: int = 2
## And how long after one finishes - met or ignored - before the next. Both of
## these exist to stop three customers each opening a fresh fuse every few
## ticks against a 24-tick budget, which is not a floor you triage but one you
## lose. Guesses, and the first numbers to reach for if the floor feels frantic
## rather than busy.
@export var demand_cooldown_ticks: int = 4
## An Every-triggered action comes round up to this many ticks either side of
## its cadence, every time - its counter starts jittered when the customer sits
## down, and each interval after that is rolled again (Shift.fire()) - so two
## customers of the same archetype do not open demands on the same tick, and
## nobody's asks arrive like clockwork. Never sooner than one tick on.
@export var action_cadence_jitter_ticks: int = 2

## Never two of the same HARD archetype (CustomerArchetype.hard) on the floor
## or in the waiting room at once - two Lay-Downs can share a floor, two
## Karens cannot. Gives way when the pool has nobody else to send.
@export var unique_archetypes_on_floor: bool = true

# --- the shop --------------------------------------------------------------
## How many cards the house offers you after every shift, to take ONE of free.
@export var free_card_choices: int = 3
## What the store stocks after it - cards for sale, and cards of yours to
## upgrade - is the shift's business: see ShiftProfile.
## What a card costs to buy, by rarity - Basic, Economy, Value, Preferred, in
## the order of CardDef.Rarity. One ladder for every card: a card's own cost is
## its rarity's, so retuning the economy is four numbers. Cards you start with
## are never for sale, but their upgrades are priced off the same ladder.
@export var card_prices: Array[int] = [600, 900, 1200, 1500]
## An upgrade costs this share of what buying that card does. Half was too
## cheap for what an upgrade does - "upgrading in the store is really good, and
## should be more expensive" - so the shipped data has it at three quarters.
@export var upgrade_price_share: float = 0.5
@export var remove_price: int = 500
## Thinning below a full hand would leave _draw_up unable to fill one: nothing
## to dig, and nothing to wait for if you are seated. That is a softlock.
@export var min_deck_size: int = 8
## margin_banked only moves through close(), which only fires on a placed
## product's Offer - a deck with no products left can never bank a dollar, and
## since the shop budget only grows by whatever margin_banked clears the quota
## by, that budget is frozen forever with no other income. The run is dead but
## keeps playing.
## This floors the same trap
## min_deck_size floors, on composition instead of size.
@export var min_products: int = 3

func as_dict() -> Dictionary:
	return {
		"appeal_step": appeal_step,
		"line_per_sale": line_per_sale,
		"leaving_soon_at": leaving_soon_at,
	}
