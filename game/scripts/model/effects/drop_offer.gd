class_name DropOffer extends Effect
## Sweeps whatever is currently on their table back off it.
##
## The PLACED offer, not an agreed sale. What they have already said yes to
## sits in `unsigned` and stays there - taking that back would rewrite a deal
## the player has already banked attention on, and would have to decide what
## to do about the Line the sale already pushed up. This only costs you the
## negotiation in progress: the product, the tick that placed it, and every
## card you have spent dragging its appeal upward.

func apply(ctx: EffectContext) -> void:
	var c = ctx.customer
	if c == null or c.offer == null:
		return
	# Straight to the discard, exactly as drop_offer() and close() do - a card
	# that leaves the table without being accounted for is a card the deck
	# quietly loses for the rest of the shift.
	if ctx.shift:
		ctx.shift.discard.append(c.offer.instance)
	c.offer = null

func describe() -> String:
	return "sweeps your product off the table"
