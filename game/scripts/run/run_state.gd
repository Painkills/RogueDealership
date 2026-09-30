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
var dialogue: DialoguePool
var rng := RandomNumberGenerator.new()

var deck: Deck
var shift_number: int = 1            ## 1-based; the shift about to be played
var money: int = 0                   ## the shop budget: every over-quota bonus, stacked
var last_bonus: int = 0              ## what the shift just played added to it
var banked_total: int = 0
var standing: int                    ## the run's HP - no inline default, _init sets it from cfg
var reports: Array[Dictionary] = []
var sale_streak: int = 0             ## carried shift to shift - see Shift.sale_streak
## Which shifts each day offers, dealt when the run starts - see Week. Null for
## a run built without the pool, which then has no calendar of its own.
var week: Week = null

func _init(p_cfg: ShiftConfig, p_interests: InterestPool, p_cards: CardPool,
		p_arch: ArchetypePool, p_seed: int,
		p_dialogue: DialoguePool = null, p_shifts: ShiftProfilePool = null) -> void:
	cfg = p_cfg
	interests = p_interests
	card_pool = p_cards
	archetypes = p_arch
	dialogue = p_dialogue
	rng.seed = p_seed
	deck = Deck.build_starting(card_pool)
	standing = cfg.standing_start
	if p_shifts != null:
		week = Week.new(p_shifts, cfg.shifts_in_run, rng.randi(), cfg.days_per_week)

## What today - the shift about to be played - offers to pick from.
func todays_shifts() -> Array[ShiftProfile]:
	var out: Array[ShiftProfile] = []
	if week != null:
		out = week.offers(shift_number)
	return out

func is_over() -> bool:
	return shift_number > cfg.shifts_in_run or standing <= 0

## Which week of the run `day` (1-based) falls in, from 1.
func week_of(day: int) -> int:
	return (day - 1) / maxi(1, cfg.days_per_week) + 1

## The shift about to be played opens a new week - the one before it is done.
func week_starts_today() -> bool:
	return shift_number > 1 and (shift_number - 1) % maxi(1, cfg.days_per_week) == 0

func quota_for(n: int) -> int:
	## Compounded rather than stepped, so the curve is one number to retune.
	var q := float(cfg.quota)
	for _i in range(n - 1):
		q *= 1.0 + cfg.quota_growth
	return roundi(q)

func start_shift(profile: ShiftProfile) -> Shift:
	# A premade shift's own numbers ride in on a copy of the config, the way
	# the practice shift's do - the run's own is never touched.
	var shift_cfg := cfg
	if profile.shift_ticks > 0 or profile.waiting_room > 0:
		shift_cfg = cfg.duplicate() as ShiftConfig
		if profile.shift_ticks > 0:
			shift_cfg.shift_ticks = profile.shift_ticks
		if profile.waiting_room > 0:
			shift_cfg.waiting_max = profile.waiting_room
	var s := Shift.new(shift_cfg, interests, card_pool, archetypes,
		rng.randi(), [], deck, profile.quota_on(quota_for(shift_number)), shift_number,
		standing, sale_streak, dialogue, profile.seats,
		profile.patience_scale, profile.walk_up_scale,
		profile.unlock_full_archetype_pool, profile.only_archetypes, profile.lineup,
		profile.excluded_archetypes)
	s.bonus_scale = profile.bonus_scale
	s.heal_up_to = profile.heal_up_to
	return s

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
	# .get() rather than a bare index: several test_run_state.gd checks build a
	# report by hand with only the keys their own assertion needs, exactly as
	# this project's tests already do for every other key - a fabricated dict
	# missing this one should carry the streak forward unchanged, not crash.
	sale_streak = int(report.get("sale_streak_end", sale_streak))

static func bonus_from(report: Dictionary) -> int:
	## Static because the report panel needs this number BEFORE finish_shift runs
	## - it is on screen while you are still looking at the shift you just played,
	## and the run does not advance until you press the button.
	##
	## What you banked over quota, times the shift's own bonus_scale - see
	## ShiftProfile. A report without one (a hand-built one) pays it straight.
	var over := maxi(0, int(report["margin_banked"]) - int(report["quota"]))
	return roundi(over * float(report.get("bonus_scale", 1.0)))
