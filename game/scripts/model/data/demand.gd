class_name Demand extends Resource
## Something a customer wants, on a fuse, with a consequence for ignoring it.
##
## The three parts a Demand must state:
##   a. how long you have        -> ticks
##   b. what answers it          -> resolve
##   c. what it costs to ignore  -> effects
## c may be nothing, where what meeting it earns (relief) is the whole point -
## an offer you let pass, and all it costs you is missing out.
##
## Raised by the RaiseDemand effect hung on an ordinary CustomerAction, so the
## existing trigger vocabulary (Every, PatienceBelow, OnOffer, OnPlace, OnSale) decides
## WHEN a customer asks and this decides what the asking means. No new trigger
## plumbing, and a new demand is a .tres like everything else.
##
## The fuse is counted in ticks, and since walking the floor is free, a tick is
## a unit of WORK rather than of wall-clock time. "Three ticks" means three
## things done, anywhere on the floor - which is what makes a deadline
## something you spend attention against rather than something you wait out.

@export var id: StringName
## What the log and the back of their folder call it - its telegraph, in title
## case ("Manager?"), so both sides of the card name the same thing.
@export var display_name: String
## SHORT. This goes above their head on a card that may be 180px wide, so it
## is a shout and not a sentence: "MANAGER?", "BETTER QUOTE", "THINKING".
@export var telegraph: String
## Which DialoguePool tag(s) a settled demand draws its spoken line from -
## separate pools for met vs missed, since they are different emotional
## registers, not one blended tag. The RAISE itself speaks through the
## CustomerAction.dialogue_tags of whatever action's RaiseDemand effect
## opened this demand, not through here.
@export var dialogue_tags_met: Array[StringName] = []
@export var dialogue_tags_missed: Array[StringName] = []
@export var ticks: int = 3                ## a. the fuse
## Raised the moment its action fires, even inside the grace period after they
## sit down or the cooldown after their last ask - only a demand already live
## holds it back. For the ask that is a last chance: "I'll think about it" on
## the way out cannot wait its turn.
@export var urgent: bool = false
@export var resolve: DemandResolve        ## b. what answers it
@export var effects: Array[Effect]        ## c. what ignoring it costs
## Optional. What meeting it EARNS, over and above not paying the consequence.
## A demand with relief is an opportunity with a deadline rather than a threat,
## which is how an archetype stays in the player's favour while still
## interrupting them.
@export var relief: Array[Effect]

@export_group("As a boss's move")
## A demand raised as one of a boss's moves (CustomerArchetype.moves) has no
## action to speak for it: this is what they say as they telegraph it.
@export var dialogue_tags_raised: Array[StringName] = []
## Only made while a product is on their table - "get that off my desk" means
## nothing with an empty desk.
@export var needs_offer_on_table: bool = false
@export_group("")

## What it hits for, before the boss's escalation (Customer.move_damage()):
## every Hit in what ignoring it costs.
func hit_damage() -> int:
	var total := 0
	for e in effects:
		if e is Hit:
			total += e.amount
	return total

## Whether what ignoring it costs includes a hit their patience cannot soften.
func pierces_patience() -> bool:
	for e in effects:
		if e is Hit and e.through_patience:
			return true
	return false
