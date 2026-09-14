class_name DemandResolve extends Resource
## What a customer will accept as an answer to their Demand.
##
## Same shape as Effect and Trigger: one ~12-line file per verb, each of which
## then appears in every Inspector dropdown in the project. A new way to answer
## a customer is a new file here and nothing else; a new DEMAND is a .tres.
##
## The shift calls satisfied() and broken_by() with a KIND - one of the five
## constants below - every time the player does something to this customer.
## Most demands are answered by an action and fail when the fuse runs out.
## LeaveThemAlone inverts both halves: the fuse running out IS the answer, and
## doing anything at all is the failure.

## Every player action a Demand can be aware of. `PRESENT` is not an action the
## player takes - it fires when a tick burns while you are standing with this
## customer, which is the only honest way to express "you did not leave".
const SUPPORT := &"support"      ## a support card played on them
const PLACE := &"place"          ## a product put on their table
const OFFER := &"offer"          ## you asked for the business
const CLOSE := &"close"          ## you signed them
const PRESENT := &"present"      ## a tick burned while you stood with them

func satisfied(_kind: StringName, _data: Dictionary) -> bool:
	return false

func broken_by(_kind: StringName, _data: Dictionary) -> bool:
	return false

## True when running out of time is the ANSWER rather than the failure.
func succeeds_on_expiry() -> bool:
	return false

func describe() -> String:
	return ""
