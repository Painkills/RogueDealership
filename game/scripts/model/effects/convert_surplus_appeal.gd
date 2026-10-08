class_name ConvertSurplusAppeal extends Effect
## Good Will: whatever appeal the product on the table has over their Line is
## wasted - a card that overshoots is margin thrown away (Shift._settle() accepts
## the moment appeal reaches the Line). This takes that waste back off the offer,
## down to exactly the Line, and pays it as margin: `amount` dollars for every
## point of it. Nothing happens at or under the Line.
##
## The margin goes on the offer, so the combo and a prized product's premium
## multiply it like the rest of the product's margin.

func apply(ctx: EffectContext) -> void:
	if ctx.offer == null or ctx.customer == null:
		return
	var surplus: int = ctx.offer.appeal - ctx.customer.line
	if surplus <= 0:
		return
	ctx.offer.appeal -= surplus
	ctx.offer.margin += surplus * amount

func describe() -> String:
	return "every point of appeal over their Line becomes $%d" % amount
