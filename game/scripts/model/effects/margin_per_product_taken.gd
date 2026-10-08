class_name MarginPerProductTaken extends Effect
## Plus Service Fee: `amount` dollars on the product on the table for every
## product this customer has already agreed to - nothing on their first, a lot on
## their ninth. Added to the offer's margin, so the combo (and a prized product's
## premium) multiplies it when it sells.

func apply(ctx: EffectContext) -> void:
	if ctx.offer:
		ctx.offer.margin += amount * ctx.sales_so_far

func describe() -> String:
	return "+$%d Margin for every product they have taken" % amount
