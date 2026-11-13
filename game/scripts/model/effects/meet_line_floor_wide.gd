class_name MeetLineFloorWide extends Effect
## Everyone's Taking It!: every product on a table, anywhere on the floor, is
## brought up toward its customer's Line - by `amount` appeal at most, or with no
## amount set all the way, enough for them to say yes. Never past the Line: one
## already there keeps what it has.

func apply(ctx: EffectContext) -> void:
	if ctx.shift == null:
		return
	# Under a debuff (BlockAppeal) nothing of yours can add appeal at all.
	if ctx.yours and ctx.shift.appeal_is_blocked():
		return
	for c in ctx.shift.seated():
		if c.offer != null and c.offer.appeal < c.line:
			var short: int = c.line - c.offer.appeal
			c.offer.appeal += mini(short, amount) if amount > 0 else short

func describe() -> String:
	if amount > 0:
		return "every product on the floor: up to +%d Appeal, to its Line" % amount
	return "every product on the floor meets its customer's Line"
