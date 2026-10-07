class_name RevealRoom extends Effect
## Active Listening - see Customer.reveal_room(). exact: their top three, in
## order, rather than only the one they want most. Active Listening is exact;
## a customer who opens up of their own accord (Easygoing) gives just the one.
@export var exact: bool = false
## Their Line as well. Off for a customer who tells you what they want of their
## own accord - they say what they are after, never how far you are from it.
@export var line: bool = true

func apply(ctx: EffectContext) -> void:
	if ctx.customer:
		ctx.customer.reveal_room(exact, line)

func describe() -> String:
	var what := "their top 3, in order" if exact else "what they want most"
	return "reveals their Line and %s" % what if line else "tells you %s" % what
