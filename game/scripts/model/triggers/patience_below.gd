class_name PatienceBelow extends Trigger
@export var at: int = 5
@export var once: bool = true

func matches(ctx: EffectContext) -> bool:
	return ctx.patience < at

func describe() -> String:
	return "when their patience drops under %d" % at
