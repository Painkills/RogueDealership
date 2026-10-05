class_name Every extends Trigger
## Cadence is handled by the caller, which owns the per-customer tick count.

@export var ticks: int = 5

func matches(_ctx: EffectContext) -> bool:
	return true

## "About": each interval is jittered either side of `ticks` - see
## ShiftConfig.action_cadence_jitter_ticks.
func describe() -> String:
	return "about every %d ticks they are on the floor" % ticks
