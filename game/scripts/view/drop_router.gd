class_name DropRouter extends RefCounted
## Turning "a card was dropped on that zone" into model commands.
##
## Geometry in, intent out. This deliberately does NOT ask whether the command
## will succeed: dropping on an empty chair still routes to approach(), so the
## model can refuse it in its own words and the player learns something. Letting
## the view pre-judge legality is the "grey out the button" mistake in another
## costume - the rules never say no silently.
##
## It returns an INTENT, not indices. The executor re-resolves the uid to a hand
## index before each command, because approach() burns a tick, a tick fires
## customer actions, and DiscardHand can remove the very card being dragged.

const PLAY := &"play"       ## play_card() - the model dispatches product vs support
const DIG := &"dig"         ## dig() - discard it and draw
const IGNORE := &"ignore"   ## cosmetic, no model call, no bounce
const NONE := &"none"       ## refuse and bounce; `reason` says why

## Returns {"command": StringName, "approach": int, "reason": String}
## `approach` is -1 when no move is needed.
static func plan(shift: Shift, uid: int, target: StringName) -> Dictionary:
	if target == CardHomes.ZONE_HAND:
		return _result(IGNORE)

	if CardIndex.of(shift, uid) == -1:
		return _result(NONE, -1, "That card is no longer in your hand.")

	if target == CardHomes.ZONE_DISCARD:
		return _result(DIG)

	if CardHomes.is_chair_zone(target):
		var chair := CardHomes.chair_of(target)
		if chair < 0 or chair >= shift.chairs.size():
			return _result(NONE, -1, "There is no such chair.")
		# shift.at is null on the floor, so compare only when standing somewhere.
		var needs_move: bool = shift.at == null or int(shift.at) != chair
		return _result(PLAY, chair if needs_move else -1)

	return _result(NONE, -1, "You cannot put a card there.")

static func _result(command: StringName, approach: int = -1, reason: String = "") -> Dictionary:
	return {"command": command, "approach": approach, "reason": reason}
