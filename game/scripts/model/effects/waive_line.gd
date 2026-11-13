class_name WaiveLine extends Effect
## Mind Games: the next `amount` products put in front of them face a lower Line -
## `drop` lower, or with no drop set a Line of 0, anything is enough - each for as
## long as it is on the table. Their Line comes back when it leaves, carrying
## whatever moved it meanwhile (Customer.clear_table()).

## How far the Line comes down for each of them. 0: all the way to 0.
@export var drop: int = 0

func apply(ctx: EffectContext) -> void:
	if ctx.customer:
		ctx.customer.line_waivers += amount
		ctx.customer.line_waiver_drop = drop

func describe() -> String:
	var what := "%d lower" % drop if drop > 0 else "0"
	if amount == 1:
		return "their Line is %s for the next product placed" % what
	return "their Line is %s for the next %d products placed" % [what, amount]
