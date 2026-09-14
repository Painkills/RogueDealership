class_name Demand extends Resource
## Something a customer wants, on a fuse, with a consequence for ignoring it.
##
## The three parts a Demand must state, and none of them is optional:
##   a. how long you have        -> ticks
##   b. what answers it          -> resolve
##   c. what it costs to ignore  -> effects
##
## Raised by the RaiseDemand effect hung on an ordinary CustomerAction, so the
## existing trigger vocabulary (Every, PatienceBelow, OnOffer, OnSale) decides
## WHEN a customer asks and this decides what the asking means. No new trigger
## plumbing, and a new demand is a .tres like everything else.
##
## The fuse is counted in ticks, and since walking the floor is free, a tick is
## a unit of WORK rather than of wall-clock time. "Three ticks" means three
## things done, anywhere on the floor - which is what makes a deadline
## something you spend attention against rather than something you wait out.

@export var id: StringName
@export var display_name: String          ## "Asks for the manager"
## SHORT. This goes above their head on a card that may be 180px wide, so it
## is a shout and not a sentence: "MANAGER?", "BETTER QUOTE", "THINKING".
@export var telegraph: String
@export var dialogue: String              ## spoken when they raise it
@export var ticks: int = 3                ## a. the fuse
@export var resolve: DemandResolve        ## b. what answers it
@export var effects: Array[Effect]        ## c. what ignoring it costs
## Optional. What meeting it EARNS, over and above not paying the consequence.
## A demand with relief is an opportunity with a deadline rather than a threat,
## which is how an archetype stays in the player's favour while still
## interrupting them.
@export var relief: Array[Effect]
