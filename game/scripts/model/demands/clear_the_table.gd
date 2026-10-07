class_name ClearTheTable extends DemandResolve
## "Get that off my desk." Answered by nothing being on their table - take the
## product back (drop it), or sell it to them, any time before it lands. Still
## on the table when the fuse runs out, and it was not answered.
##
## Reads the table rather than one particular action, so whichever way the
## product leaves, it counts: Shift._demand_saw() and the expiry check both hand
## over `table_empty`.

func satisfied(_kind: StringName, data: Dictionary) -> bool:
	return bool(data.get("table_empty", false))

func met_on_expiry(data: Dictionary) -> bool:
	return bool(data.get("table_empty", false))

func describe() -> String:
	return "take the product off their table"

func how_to_answer() -> String:
	return "Take the product off the table: drag it to the discard pile, or press D. Selling it works too."
