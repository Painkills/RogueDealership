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

@export var hand_size: int = 5
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
## since the shop budget is whatever margin_banked clears the quota by, that
## shop has $0 forever with no other income. The run is dead but keeps playing.
## This floors the same trap
## min_deck_size floors, on composition instead of size.
@export var min_products: int = 3

func as_dict() -> Dictionary:
	return {
		"appeal_step": appeal_step,
		"line_per_sale": line_per_sale,
		"leaving_soon_at": leaving_soon_at,
	}
