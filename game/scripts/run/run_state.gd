class_name RunState extends RefCounted
## A run: five shifts, a shop between them, and the deck that carries what you
## did to it.
##
## Pure RefCounted like the model - no Node, no scene, no signal - so the
## headless suite drives the identical object the game does.
##
## It owns the run's ONE seeded RandomNumberGenerator and hands each shift its
## seed from it, exactly as Shift already does for its own rolls. The shop draws
## its offers from the same generator, so a run is reproducible end to end.

var cfg: ShiftConfig
var interests: InterestPool
var card_pool: CardPool
var archetypes: ArchetypePool
var rng := RandomNumberGenerator.new()

var deck: Deck
var shift_number: int = 1            ## 1-based; the shift about to be played
var money: int = 0                   ## the shop budget, set by the last shift
var banked_total: int = 0
var reports: Array[Dictionary] = []

func _init(p_cfg: ShiftConfig, p_interests: InterestPool, p_cards: CardPool,
		p_arch: ArchetypePool, p_seed: int) -> void:
	cfg = p_cfg
	interests = p_interests
	card_pool = p_cards
	archetypes = p_arch
	rng.seed = p_seed
	deck = Deck.build_starting(card_pool)

func is_over() -> bool:
	return shift_number > cfg.shifts_in_run

func quota_for(n: int) -> int:
	## Compounded rather than stepped, so the curve is one number to retune.
	var q := float(cfg.quota)
	for _i in range(n - 1):
		q *= 1.0 + cfg.quota_growth
	return roundi(q)

func start_shift() -> Shift:
	return Shift.new(cfg, interests, card_pool, archetypes,
		rng.randi(), [], deck, quota_for(shift_number), shift_number)

func finish_shift(report: Dictionary) -> void:
	## What you banked this shift IS the shop budget for the one that follows,
	## and then it resets. Missing quota costs you that budget, never the run.
	reports.append(report)
	banked_total += int(report["margin_banked"])
	money = int(report["margin_banked"])
	shift_number += 1
