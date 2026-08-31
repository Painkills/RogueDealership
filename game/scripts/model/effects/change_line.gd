class_name ChangeLine extends Effect
func apply(ctx: EffectContext) -> void:
	if ctx.customer:
		ctx.customer.line += amount

func describe() -> String:
	return "their Line moves %+d" % amount
