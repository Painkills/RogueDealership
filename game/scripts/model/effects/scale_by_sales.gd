class_name ScaleBySales extends Effect
## Combinator: applies the wrapped effect once per product already taken.
## Worth nothing on a first offer and enormous on a fourth.

@export var inner: Effect

func apply(ctx: EffectContext) -> void:
	if inner == null:
		return
	for _i in range(ctx.sales_so_far):
		inner.apply(ctx)

func describe() -> String:
	return "%s per product already taken" % (inner.describe() if inner else "?")
