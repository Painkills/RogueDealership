class_name Offer extends RefCounted
## One product on the table, mid-negotiation. Persists untouched while you go
## work someone else - leaving costs you the tick and your memory, nothing more.
##
## `revealed` stays false until you actually OFFER it: until then you know only
## a band, which is what stops placing products from being a free way to read
## their whole priority list.

var instance: CardInstance      ## the physical card, so it can be discarded
var product: ProductCardDef     ## convenience accessor for instance.card
var appeal: int
var opened_at: int
var margin: int
var revealed: bool = false
var applied: Array[String] = []

func _init(p_instance: CardInstance, p_appeal: int, p_margin: int) -> void:
	instance = p_instance
	product = p_instance.card as ProductCardDef
	appeal = p_appeal
	opened_at = p_appeal
	margin = p_margin
