class_name OnSale extends Trigger
@export var rank_better_than: int = 0  ## 0 = any sale

func matches(ctx: EffectContext) -> bool:
	return rank_better_than <= 0 or ctx.rank < rank_better_than

func describe() -> String:
	if rank_better_than > 0:
		return "a sale on one of their top %d" % (rank_better_than - 1)
	return "any sale"
