class_name MeetLineFloorWide extends Effect
## Everyone's Taking It!: every product on a table, anywhere on the floor, is
## brought up to its customer's Line - enough for them to say yes. One already
## past it keeps what it has.

func apply(ctx: EffectContext) -> void:
	if ctx.shift == null:
		return
	# Under a debuff (BlockAppeal) nothing of yours can add appeal at all.
	if ctx.yours and ctx.shift.appeal_is_blocked():
		return
	for c in ctx.shift.seated():
		if c.offer != null and c.offer.appeal < c.line:
			c.offer.appeal = c.line

func describe() -> String:
	return "every product on the floor meets its customer's Line"
