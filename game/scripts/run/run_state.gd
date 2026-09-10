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
var money: int = 0                   ## the shop budget: every over-quota bonus, stacked
var last_bonus: int = 0              ## what the shift just played added to it
var banked_total: int = 0
var standing: int                    ## the run's HP - no inline default, _init sets it from cfg
var reports: Array[Dictionary] = []

func _init(p_cfg: ShiftConfig, p_interests: InterestPool, p_cards: CardPool,
		p_arch: ArchetypePool, p_seed: int) -> void:
	cfg = p_cfg
	interests = p_interests
	card_pool = p_cards
	archetypes = p_arch
	rng.seed = p_seed
	deck = Deck.build_starting(card_pool)
	standing = cfg.standing_start

func is_over() -> bool:
	return shift_number > cfg.shifts_in_run or standing <= 0

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
	## The quota is the house's cut and it comes out first. What you bank OVER it
	## is a bonus, and bonuses STACK for the length of the run - an overage too
	## small to buy anything this visit is not wasted, it waits.
	##
	## That is what makes a thin shift survivable. Nothing on the shelf costs less
	## than the cheapest product, so a reset budget would round most overages to
	## nothing at all; pooling them turns a run of near-misses into one real
	## purchase instead of three wasted ones.
	##
	## Missing quota still adds nothing to the bonus pot - but it is no longer
	## free. The same delta costs STANDING, the run's HP: enough total wipeouts
	## and standing hits 0 before shift_number ever would.
	reports.append(report)
	var banked := int(report["margin_banked"])
	banked_total += banked
	last_bonus = bonus_from(report)
	money += last_bonus
	standing = clampi(standing + int(report["standing_delta"]), 0, cfg.standing_start)
	shift_number += 1

static func bonus_from(report: Dictionary) -> int:
	## Static because the report panel needs this number BEFORE finish_shift runs
	## - it is on screen while you are still looking at the shift you just played,
	## and the run does not advance until you press the button.
	return maxi(0, int(report["margin_banked"]) - int(report["quota"]))
