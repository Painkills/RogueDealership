class_name ChangePatienceFloor extends Effect
## Everyone ELSE on the floor. The Karen's whole character.
func apply(ctx: EffectContext) -> void:
	if ctx.shift == null:
		return
	for other in ctx.shift.seated():
		if other != ctx.customer:
			other.add_patience(amount)

func describe() -> String:
	return "EVERYONE ELSE on the floor %s %d Patience" \
		% ["gains" if amount > 0 else "loses", abs(amount)]
