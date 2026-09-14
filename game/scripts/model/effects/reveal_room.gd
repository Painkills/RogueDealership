class_name RevealRoom extends Effect
## exact: also name their number one outright, instead of only its category.
## This is what the UPGRADED Read the Room buys. Without it the card's upgrade
## was a second, identical copy of this effect behind an $1,100 price - a
## purchase the shop would happily sell you that changed nothing at all.
@export var exact: bool = false

func apply(ctx: EffectContext) -> void:
	if ctx.customer:
		ctx.customer.reveal_room(exact)

func describe() -> String:
	if exact:
		return "reveals their Line and names their number one"
	return "reveals their Line and the category of their number one"
