class_name ShiftConfig extends Resource
## Every number the game plays with lives here and nowhere else, so a retune
## is a data edit and the tests catch it if a RULE moved instead of a number.

@export_multiline var design_rule: String

@export var shift_ticks: int = 24
@export var quota: int = 3600
@export var floor_size: int = 3
@export var walk_up_ticks: int = 4

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

@export var hand_size: int = 5
## A hand with no product in it is nearly a dead turn: needs_offer defaults to
## true, so 6 of the 8 starter support cards refuse to play with an empty table
## and dig is the only move left. This floors that away. 1 fires on the ~2.8% of
## hands that hold no product at all; 2 would fire on ~24% and hand you a second
## probe, which is a balance change rather than a guard. 0 disables the bias.
@export var hand_min_products: int = 1
@export var approach_ticks: int = 1
@export var place_ticks: int = 1
@export var dig_ticks: int = 1
@export var failed_offer_patience: int = 1

@export var appeal_step: int = 5
@export var line_per_sale: int = 3
@export var patience_per_sale: int = 3
@export var patience_jitter: int = 2

@export var arrival_patience_min_fraction: float = 0.6
@export var arrival_patience_floor: int = 4
@export var leaving_soon_at: int = 4

@export var prior_slip: float = 0.2
@export var unique_archetypes_on_floor: bool = true

# --- the shop --------------------------------------------------------------
@export var shop_offers: int = 3
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
