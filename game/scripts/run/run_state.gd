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
var money: int = 0                   ## the shop budget: last shift's take OVER quota
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
	## The quota is the house's cut and it comes out first. Only what you banked
	## OVER it is yours to spend, and then it resets - no wallet to hoard into.
	##
	## So the quota is a threshold with teeth on both sides: miss it and you get
	## nothing, scrape past it and you get almost nothing. Neither ends the run.
	reports.append(report)
	var banked := int(report["margin_banked"])
	banked_total += banked
	money = maxi(0, banked - int(report["quota"]))
	shift_number += 1
