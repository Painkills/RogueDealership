class_name RevealRoom extends Effect
## Active Listening - see Customer.reveal_room(). exact: what they want most,
## in order. This is what the UPGRADED card buys. Without it the card's upgrade
## was a second, identical copy of this effect behind a price - a purchase
## the shop would happily sell you that changed nothing at all.
@export var exact: bool = false
## Their Line as well. Off for a customer who tells you what they want of their
## own accord - they say what they are after, never how far you are from it.
@export var line: bool = true

func apply(ctx: EffectContext) -> void:
	if ctx.customer:
		ctx.customer.reveal_room(exact, line)

## Worded to hold whichever way ranks are dealt (CustomerArchetype.ranks_by_category):
## "what they want most" is their favourite category with anything left in it,
## or their top unsold interest.
func describe() -> String:
	var what := "what they want most" + (", in order" if exact else "")
	return "reveals their Line and %s" % what if line else "tells you %s" % what
