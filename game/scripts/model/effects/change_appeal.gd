class_name ChangeAppeal extends Effect
func apply(ctx: EffectContext) -> void:
	if ctx.offer:
		# Under a debuff (BlockAppeal) nothing of yours can add appeal at all.
		if ctx.yours and amount > 0 and ctx.shift != null and ctx.shift.appeal_is_blocked():
			return
		# The dealership's bonus rides on appeal ADDED, never on appeal taken.
		ctx.offer.appeal += amount + (ctx.appeal_bonus if amount > 0 else 0)

func describe() -> String:
	return "%+d Appeal" % amount
