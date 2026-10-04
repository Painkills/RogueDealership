class_name ChangeAppeal extends Effect
func apply(ctx: EffectContext) -> void:
	if ctx.offer:
		# The dealership's bonus rides on appeal ADDED, never on appeal taken.
		ctx.offer.appeal += amount + (ctx.appeal_bonus if amount > 0 else 0)

func describe() -> String:
	return "%+d Appeal" % amount
