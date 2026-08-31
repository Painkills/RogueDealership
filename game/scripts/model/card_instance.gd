class_name CardInstance extends RefCounted
## One physical card in a deck.
##
## NOT a Resource, deliberately: Resources are cached and shared project-wide,
## so a deck built from raw Resource references would upgrade all three copies
## of Explain the moment you upgraded one. uid also gives the shop and the view
## something stable to point at.

var card: CardDef
var upgraded: bool = false
var uid: int

func _init(p_card: CardDef, p_uid: int) -> void:
	card = p_card
	uid = p_uid

func is_product() -> bool:
	return card is ProductCardDef

func margin() -> int:
	var p := card as ProductCardDef
	return p.upgraded_margin if upgraded and p.upgraded_margin > 0 else p.margin
