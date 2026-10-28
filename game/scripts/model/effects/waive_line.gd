class_name WaiveLine extends Effect
## Mind Games: the next `amount` products put in front of them face a Line of 0 -
## anything is enough - each for as long as it is on the table. Their Line comes
## back when it leaves, carrying whatever moved it meanwhile (Customer.clear_table()).

func apply(ctx: EffectContext) -> void:
	if ctx.customer:
		ctx.customer.line_waivers += amount

func describe() -> String:
	if amount == 1:
		return "their Line is 0 for the next product placed"
	return "their Line is 0 for the next %d products placed" % amount
