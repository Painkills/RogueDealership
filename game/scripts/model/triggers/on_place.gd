class_name OnPlace extends Trigger
## Fires the moment a product lands on the table - before you ever ask for
## the business. Placing is free in ticks, but showing them something off
## their list is not free in patience: this is what makes that cost real,
## rather than waiting until you formally offer to find out.

@export var rank_worse_than: int = 0   ## 0 = any rank

func matches(ctx: EffectContext) -> bool:
	return rank_worse_than <= 0 or ctx.rank > rank_worse_than

func describe() -> String:
	if rank_worse_than > 0:
		return "any product placed outside their top %d" % rank_worse_than
	return "any product placed"
