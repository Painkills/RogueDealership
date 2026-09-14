class_name WalkOut extends Effect
## They have had enough and they leave.
##
## Implemented as "patience to zero" rather than as its own exit, deliberately:
## _settle_patience() runs immediately after demands come due, and it is the
## ONE path a customer leaves by. Going through it means this effect inherits
## the standing damage, the walkout log line, the unsigned-margin accounting
## and _vacate() by construction, and can never drift from what a customer
## running out of patience already does.
##
## It is its own verb rather than ChangePatience with a large negative number
## because describe() is load-bearing - the log has to say "walks out on you",
## not "-999 patience" - and because an Inspector dropdown should offer the
## thing you mean.

func apply(ctx: EffectContext) -> void:
	if ctx.customer:
		ctx.customer.patience = 0

func describe() -> String:
	return "walks out on you"
