class_name ChangeMargin extends Effect
func apply(ctx: EffectContext) -> void:
	if ctx.offer:
		ctx.offer.margin += amount

func describe() -> String:
	return "%s$%d Margin" % ["+" if amount > 0 else "-", abs(amount)]
