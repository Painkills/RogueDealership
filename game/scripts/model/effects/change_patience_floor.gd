class_name ChangePatienceFloor extends Effect
## Everyone on the floor.
func apply(ctx: EffectContext) -> void:
	if ctx.shift == null:
		return
	for customer in ctx.shift.seated():
		customer.add_patience(amount)

func describe() -> String:
	return "%+d Patience for everyone" % amount
