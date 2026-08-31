class_name OnOffer extends Trigger
## Fires when you ask. Asking is free in ticks; this is what it really costs.

@export var short_at: int = 0          ## 0 = any offer, short or not
@export var rank_worse_than: int = 0   ## 0 = any rank

func matches(ctx: EffectContext) -> bool:
	if short_at > 0 and ctx.short < short_at:
		return false
	if rank_worse_than > 0 and ctx.rank <= rank_worse_than:
		return false
	return true

func describe() -> String:
	if rank_worse_than > 0:
		return "any offer outside their top %d" % rank_worse_than
	if short_at > 0:
		return "any offer that falls %d or more short" % short_at
	return "any offer"
