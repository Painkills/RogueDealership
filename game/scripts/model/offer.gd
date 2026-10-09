class_name Offer extends RefCounted
## One product on the table, mid-negotiation. Persists untouched while you go
## work someone else - leaving costs you the tick and your memory, nothing more.
##
## Placing it tells you where it ranks on their list and, as a band, how near it
## is to their Line; only Read the Room gives the number.

var instance: CardInstance      ## the physical card, so it can be discarded
var product: ProductCardDef     ## convenience accessor for instance.card
var appeal: int
var opened_at: int
var margin: int
var applied: Array[String] = []
## Something played on it gave margin away - what a customer with
## CustomerArchetype.needs_concession_past_rank is waiting for.
var conceded: bool = false

func _init(p_instance: CardInstance, p_appeal: int, p_margin: int) -> void:
	instance = p_instance
	product = p_instance.card as ProductCardDef
	appeal = p_appeal
	opened_at = p_appeal
	margin = p_margin
