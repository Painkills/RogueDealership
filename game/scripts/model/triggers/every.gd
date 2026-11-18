class_name Every extends Trigger
## Cadence is handled by the caller, which owns the per-customer tick count.

@export var ticks: int = 5
## Only when nothing of yours is on their table as it comes round - "bored,
## and filming the wait".
@export var only_when_table_empty: bool = false

func matches(ctx: EffectContext) -> bool:
	return not only_when_table_empty or ctx.offer == null

## "About": each interval is jittered either side of `ticks` - see
## ShiftConfig.action_cadence_jitter_ticks.
func describe() -> String:
	if only_when_table_empty:
		return "about every %d ticks with nothing on their table" % ticks
	return "about every %d ticks they are on the floor" % ticks
