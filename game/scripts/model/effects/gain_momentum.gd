class_name GainMomentum extends Effect
## Momentum: the next `amount` cards you play cost no ticks - and `per_sale` more
## for every product this customer has already taken. Support cards and products
## put down alike; never past ShiftConfig.momentum_max, and a card that costs
## nothing anyway spends none. The tick you do not spend is a tick nobody on the
## floor loses patience over.

@export var per_sale: int = 0

func apply(ctx: EffectContext) -> void:
	if ctx.shift == null or not ctx.yours:
		return
	ctx.shift.gain_momentum(amount + per_sale * ctx.sales_so_far)

func describe() -> String:
	var base := "Momentum: next card free" if amount == 1 \
		else "Momentum: next %d cards free" % amount
	if per_sale > 0:
		return "%s, +%d per product taken" % [base, per_sale]
	return base
