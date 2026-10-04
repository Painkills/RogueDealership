class_name ChangeLine extends Effect
func apply(ctx: EffectContext) -> void:
	if ctx.customer:
		ctx.customer.line += lowered(amount, ctx)

## `amount`, with a Line drop scaled by the dealership's upgrades for the card
## that played it - see EffectContext.line_drop_scale. A rise is left alone.
static func lowered(amount: int, ctx: EffectContext) -> int:
	return roundi(amount * ctx.line_drop_scale) if amount < 0 else amount

func describe() -> String:
	return "their Line moves %+d" % amount
