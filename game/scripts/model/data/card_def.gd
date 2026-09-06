class_name CardDef extends Resource
## Anything that can sit in the deck. Products and support cards share one
## deck, so a product in hand is always legally placeable and can never clog
## the way m1's did.

@export var id: StringName
@export var display_name: String
## Flavour only. The MECHANICAL text is generated from Effect.describe(), so
## what is printed can never drift from what executes.
@export_multiline var text: String
@export var ticks: int = 1
@export var copies: int = 1
@export var starter: bool = false
## What the shop charges to add this card to the deck. Authored rather than
## derived: support cards have no margin to compute a price from.
@export var price: int = 800
