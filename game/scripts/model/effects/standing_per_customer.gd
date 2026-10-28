class_name StandingPerCustomer extends Effect
## Meet and Greet: `amount` standing back for every customer on the floor, never
## past where a shift starts it (ShiftConfig.standing_start) - ChangeStanding's
## clamp.

func apply(ctx: EffectContext) -> void:
	if ctx.shift == null:
		return
	ctx.shift.standing = clampi(ctx.shift.standing + amount * ctx.shift.seated().size(),
		0, ctx.shift.cfg.standing_start)

func describe() -> String:
	return "standing %+d per customer on the floor" % amount
