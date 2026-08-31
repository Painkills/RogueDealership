class_name Every extends Trigger
## Cadence is handled by the caller, which owns the per-customer tick count.

@export var ticks: int = 5

func matches(_ctx: EffectContext) -> bool:
	return true

func describe() -> String:
	return "every %d ticks they are on the floor" % ticks
