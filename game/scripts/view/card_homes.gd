class_name CardHomes extends RefCounted
## Where every card node BELONGS, derived purely from model state.
##
## The drop handler only issues model commands. It never decides where a card
## node ends up - this does, by reading the model afterwards. That split is what
## makes the table correct for things no drop caused: a customer walking out at
## zero patience takes their unsigned offer to the discard, and the node follows
## because the model says so, not because anyone dragged it.
##
## Every physical card is in exactly one of draw / discard / hand / a customer's
## table, so every uid always has a home. "The uid vanished" is not a reachable
## state, and reconciliation never has to guess.

const ZONE_DRAW := &"draw"
const ZONE_DISCARD := &"discard"
const ZONE_HAND := &"hand"

const _CHAIR_PREFIX := "chair_"

static func chair_zone(chair: int) -> StringName:
	return StringName(_CHAIR_PREFIX + str(chair))

static func is_chair_zone(zone: StringName) -> bool:
	return String(zone).begins_with(_CHAIR_PREFIX)

static func chair_of(zone: StringName) -> int:
	if not is_chair_zone(zone):
		return -1
	var tail := String(zone).substr(_CHAIR_PREFIX.length())
	return int(tail) if tail.is_valid_int() else -1

## uid -> {"zone": StringName, "ordinal": int}
##
## `ordinal` orders cards within a zone. It is what the hand fan reads; piles
## use it only so a reshuffle deals in a stable order.
static func desired(shift: Shift) -> Dictionary:
	var out := {}
	for i in range(shift.draw.size()):
		out[shift.draw[i].uid] = {"zone": ZONE_DRAW, "ordinal": i}
	for i in range(shift.discard.size()):
		out[shift.discard[i].uid] = {"zone": ZONE_DISCARD, "ordinal": i}
	# Hand and table last: they are the zones a player can see and act on, so if
	# the model ever did hold a card in two places at once, the visible one wins.
	for i in range(shift.hand.size()):
		out[shift.hand[i].uid] = {"zone": ZONE_HAND, "ordinal": i}
	for i in range(shift.chairs.size()):
		var c = shift.chairs[i]
		if c != null and c.offer != null:
			out[c.offer.instance.uid] = {"zone": chair_zone(i), "ordinal": 0}
	return out
