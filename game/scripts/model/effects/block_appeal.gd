class_name BlockAppeal extends Effect
## A debuff on YOU: for the next `amount` ticks nothing of yours can add appeal to
## a product - cards and the dealership's bonus alike. Appeal taken away still
## works, and so does everything that is not appeal. Does not stack: a second one
## only starts the count again.

func apply(ctx: EffectContext) -> void:
	if ctx.shift != null:
		ctx.shift.appeal_blocked_ticks = maxi(ctx.shift.appeal_blocked_ticks, amount)
		ctx.shift.events.append("You cannot add appeal for %d ticks." % amount)

func describe() -> String:
	return "you cannot add appeal for %d ticks" % amount
