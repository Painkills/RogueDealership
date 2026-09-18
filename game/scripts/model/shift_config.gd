class_name ShiftConfig extends Resource
## Every number the game plays with lives here and nowhere else, so a retune
## is a data edit and the tests catch it if a RULE moved instead of a number.

@export_multiline var design_rule: String

@export var shift_ticks: int = 24
@export var quota: int = 3600
@export var floor_size: int = 3
## Rolled fresh per vacated chair, not a fixed wait - a seat that always
## refilled on the same tick told you exactly when to be looking at it, which
## is the opposite of the triage pressure the floor is supposed to apply.
@export var walk_up_ticks_min: int = 6
@export var walk_up_ticks_max: int = 8

# --- the run ---------------------------------------------------------------
@export var shifts_in_run: int = 5
## The quota climbs this fraction each shift, so the run keeps pace with a deck
## that is getting stronger in the shop between them.
@export var quota_growth: float = 0.15
## The run's HP. Standing hits 0 and the run ends, same as running out of
## shifts - a scorecard with no stakes was the whole problem this fixes.
@export var standing_start: int = 100
## The same over/under-quota delta that funds the shop bonus also funds
## standing, so failure has a second consequence without a second resource to
## learn. Asymmetric on purpose: beating quota by 100% (doubling it) heals only
## 15, while missing it completely costs 50 - "more likely to die," not "one
## bad shift and you're out." Both are single numbers, guessed and untested
## like quota_growth above; retune here, not in code.
@export var standing_damage_scale: float = 50.0
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

@export var appeal_step: int = 5
@export var line_per_sale: int = 3
@export var patience_per_sale: int = 3
@export var patience_jitter: int = 2
## The appeal meter's own ceiling - fixed, not fitted to whatever the current
## negotiation happens to need. It used to grow (and only ever grow) to
## whatever the live appeal or Line required, which meant the bar's own scale
## was a different number on every card and every customer - "read this bar"
## was a skill you had to relearn per negotiation. A flat number instead: pick
## one comfortably above the highest Line anyone opens at (today's ceiling is
## the Budget Hawk's 40) plus real headroom for appeal cards to stack on top
## of it. Appeal or Line past this just reads as a full bar rather than
## breaking anything - draw() already clamps the fill fraction to 1.0.
@export var appeal_meter_scale: int = 80

@export var arrival_patience_min_fraction: float = 0.6
@export var arrival_patience_floor: int = 4
@export var leaving_soon_at: int = 4
## Ticks remaining in the WHOLE SHIFT, not one customer's patience, at which
## the clock starts warning you to close out what is unsigned before the bell
## takes it for free. See Shift.ticks_running_low().
@export var low_tick_warning: int = 4

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

@export var prior_slip: float = 0.2
@export var unique_archetypes_on_floor: bool = true

# --- the shop --------------------------------------------------------------
@export var shop_offers: int = 3
## Every un-upgraded card with a real upgrade to sell used to get an "upgrade"
## button, all at once - eight or more rows deep by the back half of a run.
## Capped and rolled at random per visit instead, the same shape shop_offers
## already uses for new cards: a real choice among a few, not a checklist.
@export var shop_upgrade_slots: int = 3
## An upgrade costs this many times what it gains, so it pays back in that many
## sales. Both scale with the card, which is what keeps upgrading a cheap card
## and an expensive one the same decision.
@export var upgrade_price_multiple: int = 4
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
