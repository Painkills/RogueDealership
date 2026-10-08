class_name CarouselTurn extends RefCounted
## Which way the table turns. The three seats sit a third of a turn apart, so any
## other seat is one step to the left or the right of the one in front - never
## two. Tweening the raw angle sent seat 3 to seat 1 the long way round, through
## seat 2; this is the same angle, whichever turn of the circle it is on, that is
## nearest where the table is now.

## The angle equal to `target` (in radians, any number of turns away) that is
## closest to `current`.
static func nearest(current: float, target: float) -> float:
	return current + wrapf(target - current, -PI, PI)
