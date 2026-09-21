class_name CardDef extends Resource
## Anything that can sit in the deck. Products and support cards share one
## deck, so a product in hand is always legally placeable and can never clog
## the way m1's did.

@export var id: StringName
@export var display_name: String
## Flavour only, printed on the card face below the mechanics (CardText.flavor,
## FlavorLabel). The MECHANICAL text is instead generated from
## Effect.describe(), so what is printed can never drift from what executes.
@export_multiline var text: String
@export var ticks: int = 1
@export var copies: int = 1
@export var starter: bool = false
## What the shop charges to add this card to the deck. Authored rather than
## derived: support cards have no margin to compute a price from. Defaults to
## 0, not some plausible-looking number, so an unpriced card fails
## test_every_card_carries_a_price() instead of silently passing it.
@export var price: int = 0
## Which DialoguePool tag(s) a customer's reaction draws from when this card
## is played on them. Empty means they say nothing - the right answer for a
## card where you are the one doing the talking (e.g. Read the Room). Lives
## here rather than on Effect: a card's own effects and upgraded_effects are
## separate sub-resource instances, and tagging both in sync is a drift bug
## waiting to happen - one place per card avoids it entirely.
@export var dialogue_tags: Array[StringName] = []
