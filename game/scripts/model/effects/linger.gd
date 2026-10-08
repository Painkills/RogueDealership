class_name Linger extends Effect
## Another effect, played out over time: `inner` happens once a tick for `ticks`
## ticks, on the customer the card was played on - starting the tick AFTER it, so
## the card's own cost is not one of them - while you are busy with somebody else.
## "A coffee: +2 patience a tick for 4 ticks"; "Think on it: +2 appeal a tick for
## 4 ticks, until you play another card on them".
##
## `stops_on_card`: whatever is left of it is cancelled the moment you play any
## other card on that customer (Shift._card_played_on()) - what they had been
## given so far stays.
##
## The wrapped effect runs on the customer's own context at each tick - their
## offer as it is then, their patience as it is then - so it does nothing to a
## product that is no longer on the table. It lives on Customer.lingering, which
## Shift._burn() ticks.

@export var inner: Effect
@export var ticks: int = 4
@export var stops_on_card: bool = false

func apply(ctx: EffectContext) -> void:
	if ctx.customer == null or inner == null or ticks <= 0:
		return
	ctx.customer.lingering.append({
		"inner": inner,
		"ticks_left": ticks,
		"stops_on_card": stops_on_card,
		"card": ctx.card,
		# Begins on the next tick, not the one the card costs.
		"fresh": true,
	})

func describe() -> String:
	var what := inner.describe() if inner != null else "?"
	return "%s every tick for %d ticks%s" % [what, ticks,
		", until you play another card on them" if stops_on_card else ""]
