class_name DiscardHand extends Effect
func apply(ctx: EffectContext) -> void:
	if ctx.shift:
		ctx.shift.discard_random_from_hand(abs(amount))

func describe() -> String:
	return "you lose %d card(s) from hand" % abs(amount)
