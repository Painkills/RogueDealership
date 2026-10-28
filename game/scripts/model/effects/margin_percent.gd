class_name MarginPercent extends Effect
## Risky Business: the product on the table pays `amount` percent more - or
## `low_amount` percent, pushed on someone whose patience is under `low_below` of
## their most.

@export var low_amount: int = 50
@export var low_below: float = 0.2

func apply(ctx: EffectContext) -> void:
	if ctx.offer == null:
		return
	var percent := amount
	if ctx.customer != null and ctx.customer.patience < ctx.customer.max_patience * low_below:
		percent = low_amount
	ctx.offer.margin += roundi(ctx.offer.margin * percent / 100.0)

func describe() -> String:
	return "+%d%% Margin, +%d%% under %d%% patience" % [amount, low_amount,
		roundi(low_below * 100.0)]
