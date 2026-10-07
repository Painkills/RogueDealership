class_name TimedMove extends Resource
## A boss move that comes on a clock of its own - "get that off my desk, every
## nine ticks or so" - rather than in the rotation. It is raised the moment it is
## due and a product is on the table (Demand.needs_offer_on_table), and the clock
## starts over from when it was raised. See CustomerArchetype.timed_moves and
## Shift._next_move().

## Ticks from the boss sitting down - and from each time it comes up - to when it
## is due.
@export_range(1, 60) var every_ticks: int = 9
@export var move: Demand
