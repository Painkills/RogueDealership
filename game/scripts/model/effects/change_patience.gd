class_name ChangePatience extends Effect
func apply(ctx: EffectContext) -> void:
	if ctx.customer:
		ctx.customer.add_patience(amount)

func describe() -> String:
	return "%+d their Patience" % amount
