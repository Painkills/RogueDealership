class_name Hit extends Effect
## A boss's attack: `amount` off your standing, plus however much harder their
## moves have grown (Customer.move_damage_bonus()). A customer whose patience
## is a shield (CustomerArchetype.patience_is_shield) takes it out of their
## patience first, and only what that cannot cover reaches you - so a shield
## built up before a telegraphed hit is what keeps it off your standing.

func apply(ctx: EffectContext) -> void:
	if ctx.shift == null:
		return
	var c = ctx.customer
	var damage: int = amount + (c.move_damage_bonus() if c != null else 0)
	var blocked := 0
	if c != null and c.archetype.patience_is_shield:
		blocked = clampi(c.patience, 0, damage)
		c.patience -= blocked
	var landed: int = damage - blocked
	# Same clamp ChangeStanding and _walk() use: standing reaches 0 and ends the
	# run, but never reads negative.
	var before: int = ctx.shift.standing
	ctx.shift.standing = clampi(before - landed, 0, ctx.shift.cfg.standing_start)
	if c != null:
		ctx.shift.events.append("[%s] %s hits for %d: %d blocked by their patience, %d off your standing."
			% [c.key, c.display_name, damage, blocked, before - ctx.shift.standing])

func describe() -> String:
	return "hits for %d" % amount
