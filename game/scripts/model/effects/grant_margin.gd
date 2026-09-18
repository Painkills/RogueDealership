class_name GrantMargin extends Effect
## A margin reward for a demand's relief - unlike ChangeMargin (a live offer's
## own arithmetic) or MarginBonus (a sale already being settled by an offer),
## a demand's OFFER-triggered relief can land on EITHER one: the customer may
## have just sold (offer() calls _settle() before the demand resolves it, so
## a sale exists and c.offer is already null) or the offer may still be open
## (the demand was satisfied - "show me something in your top 3" - without
## the appeal actually clearing the Line). Exactly one of ctx.sale / ctx.offer
## is populated at that moment, never both, so this always lands on whichever
## one the money is actually sitting in.
func apply(ctx: EffectContext) -> void:
	if not ctx.sale.is_empty():
		ctx.sale["margin"] = int(ctx.sale["margin"]) + amount
		ctx.sale["bonus"] = int(ctx.sale.get("bonus", 0)) + amount
	elif ctx.offer:
		ctx.offer.margin += amount

func describe() -> String:
	return "+$%d Margin" % amount
