class_name RaiseDemand extends Effect
## Puts a Demand on the customer this action fired for.
##
## The whole bridge between the existing action machinery and the new one: an
## archetype authors an ordinary CustomerAction whose trigger says WHEN and
## whose single effect is this, which says WHAT. Shift.raise_demand() owns the
## throttles (one at a time, a grace period after sitting down, a cooldown
## after the last one), so they apply identically no matter which trigger asked.

@export var demand: Demand

func apply(ctx: EffectContext) -> void:
	if ctx.shift and ctx.customer and demand != null:
		ctx.shift.raise_demand(ctx.customer, demand)

func describe() -> String:
	if demand == null:
		return ""
	# The fuse belongs in the log line. "Asks for the manager" without "3 ticks"
	# is an event; with it, it is a decision.
	return "%s - %d ticks to %s" \
		% [demand.telegraph, demand.ticks,
			demand.resolve.describe() if demand.resolve else "answer"]
