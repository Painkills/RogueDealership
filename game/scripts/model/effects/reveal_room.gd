class_name RevealRoom extends Effect
## Active Listening - see Customer.reveal_room(). exact: what they want most,
## in order. This is what the UPGRADED card buys. Without it the card's upgrade
## was a second, identical copy of this effect behind a price - a purchase
## the shop would happily sell you that changed nothing at all.
@export var exact: bool = false

func apply(ctx: EffectContext) -> void:
	if ctx.customer:
		ctx.customer.reveal_room(exact)

## Worded to hold whichever way ranks are dealt (ShiftConfig.ranks_by_category):
## "what they want most" is their favourite category with anything left in it,
## or their top unsold interest.
func describe() -> String:
	if exact:
		return "reveals their Line and what they want most, in order"
	return "reveals their Line and what they want most"
