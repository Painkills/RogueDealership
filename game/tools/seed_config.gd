extends SceneTree
## Bootstrap for the shift config.
##
##     godot --headless --path game --script res://tools/seed_config.gd

const PATH := "res://data/shift_config.tres"

const DESIGN_RULE := "Every number the game plays with lives here and nowhere else, so a retune is a data edit and the tests catch it if a RULE moved instead of a number. appeal_step is load-bearing against the interest pool: appeal = appeal_step x (interest_count - rank), so rank 1 opens at 40 and rank 9 at 0. Cards must always move LESS than one appeal_step for free, or a card becomes a substitute for a good read and diagnosis stops paying."

func _init() -> void:
	var cfg := ShiftConfig.new()
	cfg.design_rule = DESIGN_RULE
	cfg.shift_ticks = 24
	cfg.quota = 3600
	cfg.floor_size = 3
	cfg.walk_up_ticks = 4
	cfg.hand_size = 4
	cfg.approach_ticks = 1
	cfg.place_ticks = 1
	cfg.dig_ticks = 1
	cfg.failed_offer_patience = 1
	cfg.appeal_step = 5
	cfg.line_per_sale = 3
	cfg.patience_per_sale = 3
	cfg.patience_jitter = 2
	cfg.arrival_patience_min_fraction = 0.6
	cfg.arrival_patience_floor = 4
	cfg.leaving_soon_at = 4
	cfg.prior_slip = 0.2
	cfg.unique_archetypes_on_floor = true
	ResourceSaver.save(cfg, PATH)
	print("seeded shift config")
	quit(0)
