class_name EffectContext extends RefCounted
## Everything an effect may touch.
##
## shift/customer/offer are DELIBERATELY UNTYPED. Typing them would make
## Effect -> EffectContext -> Customer -> CustomerArchetype -> CustomerAction
## -> Effect a cyclic class_name dependency, which GDScript rejects.

var shift                       # Shift
var customer                    # Customer
var offer                       # Offer
var sale: Dictionary = {}       # the sale being settled, if any

var rank: int = 0               # rank of the offered interest, for filters
var short: int = 0              # how far the offer fell short
var sales_so_far: int = 0       # products this customer has already taken
var patience: int = 0           # the customer's patience, for PatienceBelow
## Added to any appeal a card or product of yours adds - the dealership's
## upgrades (see Shift._yours()). 0 for everything a customer does.
var appeal_bonus: int = 0
## Multiplies any Line a card of yours LOWERS - the dealership's upgrades for
## that card's brand (see Shift._yours()). 1.0 for everything else.
var line_drop_scale: float = 1.0
