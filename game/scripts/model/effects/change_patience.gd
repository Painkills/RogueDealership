class_name ChangePatience extends Effect
func apply(ctx: EffectContext) -> void:
	if ctx.customer:
		# What a card of yours gives is scaled by who it is given to; what is taken is not.
		ctx.customer.add_patience(roundi(amount * ctx.patience_scale) if amount > 0 else amount)

func describe() -> String:
	return "%+d their Patience" % amount
