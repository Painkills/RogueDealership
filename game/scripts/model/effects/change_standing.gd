class_name ChangeStanding extends Effect
## Hits your standing with the house directly, without anybody walking out.
##
## Needs no report accounting of its own: Shift.standing is live, and
## report()'s standing_delta is already (standing - _initial_standing) plus the
## quota term, so anything that moves the number mid-shift is in the delta for
## free. It needs no end-of-run wiring either - is_over() already reads
## `standing <= 0`, and _apply() shows the report the moment is_over() is true
## for any reason, so a demand that zeroes your standing fires you on the spot.

func apply(ctx: EffectContext) -> void:
	if ctx.shift == null:
		return
	# Same clamp _walk() uses: standing can reach 0 and end the shift, but must
	# never read negative on the HUD or in the report.
	ctx.shift.standing = clampi(ctx.shift.standing + amount,
		0, ctx.shift.cfg.standing_start)

func describe() -> String:
	return "standing %+d" % amount
