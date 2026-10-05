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
	return "%dt" % inst.ticks()

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

## The line under the body. It used to be the authored flavour text; that is
## the dialogue's job now. On a product it is what the product DOES beyond its
## margin - WALKAWAY's "their Line moves -3" - generated from the effects that
## actually run, so an upgrade shows the upgraded amount and a rebalance never
## means rewriting a card. Empty on a support card, whose body already says
## what it does, and on a product that does nothing more.
static func flavor(inst: CardInstance) -> String:
	if not inst.is_product():
		return ""
	var p := inst.card as ProductCardDef
	var effects := p.upgraded_effects if inst.upgraded and not p.upgraded_effects.is_empty() \
		else p.effects
	var parts: Array[String] = []
	for e in effects:
		var d := e.describe()
		if d != "":
			parts.append(d)
	return ", ".join(parts)

## B/E/V/P - the corner badge. One letter, not a word, so it reads at the
## minified size every card face is actually viewed at.
static func rarity_letter(inst: CardInstance) -> String:
	match inst.card.rarity:
		CardDef.Rarity.BASIC: return "B"
		CardDef.Rarity.ECONOMY: return "E"
		CardDef.Rarity.VALUE: return "V"
		CardDef.Rarity.PREFERRED: return "P"
		_: return "?"

## The corner badge's word form - same KindLabel-style all-caps as "PRODUCT"
## / "SUPPORT" already use.
static func rarity_name(inst: CardInstance) -> String:
	match inst.card.rarity:
		CardDef.Rarity.BASIC: return "BASIC"
		CardDef.Rarity.ECONOMY: return "ECONOMY"
		CardDef.Rarity.VALUE: return "VALUE"
		CardDef.Rarity.PREFERRED: return "PREFERRED"
		_: return "?"
