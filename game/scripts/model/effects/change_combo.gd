class_name ChangeCombo extends Effect
## Raises the multiplier of the customer it is played on, by `amount` percent -
## their next sale and every one after it, on top of what their sales build up.
func apply(ctx: EffectContext) -> void:
	if ctx.customer:
		ctx.customer.combo_bonus += amount / 100.0

func describe() -> String:
	return "%+d%% Combo" % amount
