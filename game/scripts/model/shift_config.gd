class_name ShiftConfig extends Resource
## Every number the game plays with lives here and nowhere else, so a retune
## is a data edit and the tests catch it if a RULE moved instead of a number.

@export_multiline var design_rule: String

@export var shift_ticks: int = 24
@export var quota: int = 3600
@export var floor_size: int = 3
@export var walk_up_ticks: int = 4

@export var hand_size: int = 4
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

func as_dict() -> Dictionary:
	return {
		"appeal_step": appeal_step,
		"line_per_sale": line_per_sale,
		"leaving_soon_at": leaving_soon_at,
	}
