class_name BudgetMove extends Resource
## A boss move that comes up once their budget has run down to a share of what it
## was - "get that off my desk at 75% and again at 25%" - rather than in the
## rotation. See CustomerArchetype.budget_moves and Shift._next_move().

## It comes up once what they have left is this share of their budget or less:
## 0.75 is a quarter spent.
@export_range(0.0, 1.0, 0.05) var at_share: float = 0.75
@export var move: Demand

## The dollars left at or below which it comes up, for a budget of `budget`.
func dollars_left(budget: int) -> int:
	return roundi(budget * at_share)
