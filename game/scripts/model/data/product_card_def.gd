class_name ProductCardDef extends CardDef
## Answers exactly one interest. Margin is a ladder deliberately uncorrelated
## with how often an interest is ranked highly.

@export var interest: Interest
@export var margin: int
@export var upgraded_margin: int = 0    ## 0 means no upgrade authored yet
## Which DialoguePool tag(s) the customer's objection is drawn from when this
## goes down under their Line - see Shift._object(). A product with its own
## objections (WALKAWAY's are the deck's) names its own tag; the rest share the
## generic one. Empty means they never object to it.
@export var objection_tags: Array[StringName] = []
