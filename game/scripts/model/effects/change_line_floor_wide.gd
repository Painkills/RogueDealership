class_name ChangeLineFloorWide extends Effect
## ChangeLine's floor-wide sibling - every seated customer, not just the one
## this card was played on.
func apply(ctx: EffectContext) -> void:
	if ctx.shift:
		for c in ctx.shift.seated():
			c.line += amount

func describe() -> String:
	return "everyone's Line moves %+d" % amount
