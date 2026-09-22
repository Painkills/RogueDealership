class_name PullCards extends Effect
## Stages a reveal on Shift rather than resolving anything itself - the
## actual pick is a SEPARATE, later command (Shift.choose_pull()/
## cancel_pull()), the same two-step every other player decision in this
## game already is (approach then offer, approach then close). See
## Shift._start_pull()'s own comment for the scan rule.

@export var count: int = 3
@export var kind: StringName = &"any"   # &"any", &"support", &"product"

func apply(ctx: EffectContext) -> void:
	if ctx.shift:
		ctx.shift._start_pull(count, kind)

func describe() -> String:
	var what := "cards" if kind == &"any" else "%s cards" % kind
	return "Reveals %d %s from the draw pile. Keep one." \
		% [count, what]
