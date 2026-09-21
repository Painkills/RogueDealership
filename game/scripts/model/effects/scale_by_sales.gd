class_name ScaleBySales extends Effect
## Combinator: applies the wrapped effect once and then once again per product already taken.
## Worth nothing on a first offer and enormous on a fourth.

@export var inner: Effect

func apply(ctx: EffectContext) -> void:
	if inner == null:
		return
	inner.apply(ctx) # Add the value once, and then again for each sale.
	for _i in range(ctx.sales_so_far):
		inner.apply(ctx)

func describe() -> String:
	return "%s plus an additional %s per product taken" % [inner.describe() if inner else "?", inner.describe() if inner else "?"]
