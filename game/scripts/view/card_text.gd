class_name CardText extends RefCounted
## The words on a card, in one place.
##
## Two faces render the same CardInstance now - the 3D table card and whatever
## 2D panel survives - and the branch below (upgraded_effects only when it is
## both upgraded and non-empty) is exactly the kind of rule that silently drifts
## when it is written twice. It is written once.
##
## No Node, no Control, no Label3D: this returns strings and nothing else.

static func title(inst: CardInstance) -> String:
	return inst.card.display_name

static func cost(inst: CardInstance) -> String:
	return "%dt" % inst.card.ticks

static func kind(inst: CardInstance) -> String:
	return "PRODUCT" if inst.is_product() else "SUPPORT"

## Products show what need they answer; support shows what it actually does.
static func body(inst: CardInstance) -> String:
	if inst.is_product():
		var p := inst.card as ProductCardDef
		return p.interest.category.display_name + " . " + p.interest.display_name
	var s := inst.card as SupportCardDef
	var effects := s.upgraded_effects if inst.upgraded and not s.upgraded_effects.is_empty() else s.effects
	var parts: Array[String] = []
	for e in effects:
		parts.append(e.describe())
	return ", ".join(parts)

## Empty for support cards - they have no margin of their own.
static func margin(inst: CardInstance) -> String:
	return Format.money(inst.margin()) if inst.is_product() else ""
