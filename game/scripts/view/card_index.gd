class_name CardIndex extends RefCounted
## Resolving a card's uid to its current position in hand.
##
## The view holds uids, never hand indices. Indices move under the view's feet
## constantly - dig() removes one, _draw_up() appends, and a customer action can
## discard at random - so an index captured when a drag started is routinely
## wrong by the time the drag ends. A uid is stable for the life of the card.
##
## Linear scan over a hand of four. Do not "optimise" this into a cached map:
## the cache is the bug this class exists to prevent.

static func of(shift: Shift, uid: int) -> int:
	for i in range(shift.hand.size()):
		if shift.hand[i].uid == uid:
			return i
	return -1
