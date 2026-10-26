class_name RevealRoom extends Effect
## Active Listening - see Customer.reveal_room(). exact: their top `top`, in
## order, rather than only the one they want most. Active Listening is exact;
## a customer who opens up of their own accord (Easygoing) gives just the one.
@export var exact: bool = false
## How many of their list an exact read gives, in order - 3, or 6 for the
## upgraded Active Listening.
@export var top: int = 3
## Their Line as well. Off for a customer who tells you what they want of their
## own accord - they say what they are after, never how far you are from it.
@export var line: bool = true

func apply(ctx: EffectContext) -> void:
	if ctx.customer:
		ctx.customer.reveal_room(exact, line, top)

func describe() -> String:
	var what := "their top %d, in order" % top if exact else "what they want most"
	return "reveals their Line and %s" % what if line else "tells you %s" % what
