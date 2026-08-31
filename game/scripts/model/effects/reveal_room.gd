class_name RevealRoom extends Effect
func apply(ctx: EffectContext) -> void:
	if ctx.customer:
		ctx.customer.reveal_room()

func describe() -> String:
	return "reveals their Line and the category of their number one"
