class_name PatienceToAppeal extends Effect
## Insistence: `amount` percent of their patience - what is left of it, rounded
## down - comes off it and goes onto the product on the table as appeal, point for
## point. Pushing harder, at the cost of how long they will stand for it.

func apply(ctx: EffectContext) -> void:
	if ctx.customer == null or ctx.offer == null:
		return
	# Under a debuff (BlockAppeal) nothing of yours can add appeal - and nothing
	# is taken for it either.
	if ctx.yours and ctx.shift != null and ctx.shift.appeal_is_blocked():
		return
	var taken := taken_from(ctx.customer.patience, amount)
	if taken <= 0:
		return
	ctx.customer.patience -= taken
	ctx.offer.appeal += taken + ctx.appeal_bonus

## How much of `patience` it takes - the one sum the forecast reads too.
static func taken_from(patience: int, percent: int) -> int:
	return maxi(0, patience) * percent / 100

func describe() -> String:
	return "%d%% of their patience becomes Appeal" % amount
