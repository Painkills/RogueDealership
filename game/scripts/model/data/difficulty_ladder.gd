class_name DifficultyLadder extends Resource
## The run's difficulty, planned: one target a day, a spread of it across the
## day's slots, and how each shift spends its target. Everything that makes a
## shift harder is priced in the same points (CustomerArchetype.difficulty,
## ShiftComplicator.points - see tools/rate_shifts.gd): its seats and waiting
## room, its quota, who comes in, its ticks and hand, its customers' patience,
## combos and Line, and the products it asks to be sold. See ShiftGenerator for
## how a shift is built to its target, and Week for how a day's are dealt.

## The day's target: `start` on day 1, `per_day` more each day after.
@export var start: float = 10.0
@export var per_day: float = 1.0
## Added to the day's target, one to each of the day's regular slots in an
## order drawn for the day - so which slot is the hard one changes day to day.
## Fewer offsets than slots: the rest get the day's own.
@export var spread: Array[int] = [-2, 0, 2]
## The share of a shift's budget spent on its quota, and on its conditions
## (seats, waiting room, ticks, hand, patience, combos, Line, product quota),
## each drawn between its min and max for every shift. Its customers get the
## rest - and whatever the others leave.
@export_range(0.0, 1.0, 0.05) var quota_share_min: float = 0.3
@export_range(0.0, 1.0, 0.05) var quota_share_max: float = 0.5
@export_range(0.0, 1.0, 0.05) var conditions_share_min: float = 0.1
@export_range(0.0, 1.0, 0.05) var conditions_share_max: float = 0.3

## What a shift pays follows how hard it is: its slot's store (cards for sale,
## upgrades) and commission times its difficulty over the day's target, kept
## between these two.
@export var reward_scale_min: float = 0.5
@export var reward_scale_max: float = 1.5
## The day's hardest shift is ROUGH: making its quota offers this many
## dealership perks to pick one from (ShiftProfile.dealership_upgrades).
@export var rough_perks: int = 3

## The seats every shift of a weekday has - Monday first: 1, 2, then 3 for the
## rest, so the floor fills up through the week. Each still costs its points
## (a seat count is a modifier), and the rest of the shift makes up the
## difference. 0, or a day past the end: the shift's budget picks.
@export var seats_by_weekday: Array[int] = []

## The seats `weekday` (0 = the week's first day) sets, or 0.
func seats_on(weekday: int) -> int:
	return seats_by_weekday[weekday] if weekday >= 0 and weekday < seats_by_weekday.size() else 0

## The day's target on `day` (1-based) of the run.
func target_on(day: int) -> int:
	return roundi(start + per_day * (day - 1))

## The day's target for each of `slots` regular slots, in slot order, the spread
## shuffled by `rng`.
func targets_on(day: int, slots: int, rng: RandomNumberGenerator) -> Array[int]:
	var offsets: Array[int] = spread.duplicate()
	while offsets.size() < slots:
		offsets.append(0)
	for i in range(offsets.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap := offsets[i]
		offsets[i] = offsets[j]
		offsets[j] = swap
	var out: Array[int] = []
	var base := target_on(day)
	for i in range(slots):
		out.append(maxi(0, base + offsets[i]))
	return out
