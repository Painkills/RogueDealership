class_name MarginBonus extends Effect
## Lands on the SALE being settled, not on the offer - the offer is already
## gone by the time a sale exists.
func apply(ctx: EffectContext) -> void:
	if ctx.sale.is_empty():
		return
	ctx.sale["margin"] = int(ctx.sale["margin"]) + amount
	ctx.sale["bonus"] = int(ctx.sale.get("bonus", 0)) + amount

func describe() -> String:
	return "+$%d on the sale" % amount
