class_name RevealRoom extends Effect
## exact: also mark the three interests they want most that are still open.
## This is what the UPGRADED Read the Room buys. Without it the card's upgrade
## was a second, identical copy of this effect behind a price - a purchase
## the shop would happily sell you that changed nothing at all.
@export var exact: bool = false

func apply(ctx: EffectContext) -> void:
	if ctx.customer:
		ctx.customer.reveal_room(exact)

func describe() -> String:
	if exact:
		return "reveals their Line and top interest, and marks their top 3"
	return "reveals their Line and names their top unsold interest"
