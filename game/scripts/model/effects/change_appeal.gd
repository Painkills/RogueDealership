class_name ChangeAppeal extends Effect
func apply(ctx: EffectContext) -> void:
	if ctx.offer:
		ctx.offer.appeal += amount

func describe() -> String:
	return "%+d Appeal" % amount
