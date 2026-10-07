class_name Hit extends Effect
## A boss's attack: `amount` off your standing, plus however much harder their
## moves have grown (Customer.move_damage_bonus()). A customer whose patience
## soaks up hits (CustomerArchetype.patience_is_shield) takes it out of their
## patience first, and only what that cannot cover reaches you - so patience
## built up before a telegraphed hit is what keeps it off your standing.
##
## `through_patience`: a hit that goes straight past it, all of it to you - the
## big one, that has to be dodged rather than absorbed.
@export var through_patience: bool = false

func apply(ctx: EffectContext) -> void:
	if ctx.shift == null:
		return
	var c = ctx.customer
	var damage: int = amount + (c.move_damage_bonus() if c != null else 0)
	var blocked := 0
	if c != null and c.archetype.patience_is_shield and not through_patience:
		blocked = clampi(c.patience, 0, damage)
		c.patience -= blocked
	var landed: int = damage - blocked
	# Same clamp ChangeStanding and _walk() use: standing reaches 0 and ends the
	# run, but never reads negative.
	var before: int = ctx.shift.standing
	ctx.shift.standing = clampi(before - landed, 0, ctx.shift.cfg.standing_start)
	if c != null:
		if through_patience:
			ctx.shift.events.append("[%s] %s hits for %d - their patience cannot soften it: %d off your standing."
				% [c.key, c.display_name, damage, before - ctx.shift.standing])
		else:
			ctx.shift.events.append("[%s] %s hits for %d: %d off their patience, %d off your standing."
				% [c.key, c.display_name, damage, blocked, before - ctx.shift.standing])

func describe() -> String:
	return "hits for %d" % amount
