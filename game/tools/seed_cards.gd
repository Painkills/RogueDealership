extends SceneTree
## Bootstrap for the card pool. Re-running rebuilds every card .tres and the
## pool that lists them, so keep this in step with any hand-edits you want to
## survive. Products only for now; support cards join in Task 3.
##
##     godot --headless --path game --script res://tools/seed_cards.gd

const PRODUCT_DIR := "res://data/products"
const POOL_PATH := "res://data/card_pool.tres"
const INTERESTS := "res://data/interests/interest_pool.tres"

## id, name, interest, margin, starter, text
const PRODUCTS := [
	[&"vsc", "Vehicle Service Contract", &"reliability", 1600, true,
		"Covers the repair bill when it breaks after the factory walks away."],
	[&"gap", "GAP Insurance", &"equity", 1400, true,
		"Pays the difference when the loan outlives the car."],
	[&"ppp", "Payment Protection Plan", &"stability", 1200, true,
		"Life, disability and job loss. The payment gets made even when they can't."],
	[&"theft", "Anti-Theft & Key Protection", &"security", 800, true,
		"Etching, tracking, and a replacement key that doesn't cost a weekend."],
	[&"flex", "Payment Flex Plan", &"affordability", 700, true,
		"Skip-a-payment and a deferred first month, for when the budget is thin."],
	[&"concierge", "Concierge & Roadside Plan", &"convenience", 600, true,
		"Pickup, delivery, loaners, roadside. They never sit in a waiting room."],
	[&"perf", "Performance & Tow Package", &"power", 1100, false,
		"Tow rating, all-weather traction, and a badge that says so."],
	[&"tvp", "Trade-In Value Protection", &"value_retention", 1000, false,
		"Guarantees a floor under what it books for at trade-in."],
	[&"appearance", "Appearance & Wheel Package", &"status", 900, false,
		"Ceramic coat, tint, and wheels people look at."],
]

const SUPPORT_DIR := "res://data/cards"

## id, name, ticks, copies, starter, needs_offer, effects, upgraded, text
const SUPPORT := [
	[&"explain", "Explain the Product", 1, 3, true, true,
		[["appeal", 4]], [["appeal", 7]],
		"You walk them through it properly. The workhorse: costs nothing but the clock, and moves you slightly less than one place up their list."],
	[&"discount", "Offer a Discount", 1, 2, true, true,
		[["appeal", 8], ["margin", -300]], [["appeal", 8], ["margin", -150]],
		"You come down on it. The biggest move you can make in a single tick, and you pay for it out of your own pocket."],
	[&"pad", "Pad the Deal", 1, 1, true, true,
		[["appeal", -5], ["margin", 400]], [["appeal", -3], ["margin", 400]],
		"You quietly widen the spread. Play it BEFORE you start conceding - padding a deal you have already dragged to the Line just pushes it back under."],
	[&"smalltalk", "Small Talk", 1, 1, true, false,
		[["patience", 5]], [["patience", 8]],
		"Kids, weather, the drive over. Buys one person time; the tick still costs everyone else theirs."],
	[&"readroom", "Read the Room", 1, 1, true, false,
		[["reveal", 0]], [["reveal", 0]],
		"You shut up and watch. Tells you their LINE - how high Appeal has to climb before they say yes - and which THIRD of the board they actually care about, before you spend a tick putting a product in front of them."],
	[&"framing", "Payment Framing", 1, 1, false, true,
		[["appeal", 4], ["margin", -150]], [["appeal", 6], ["margin", -150]],
		"'That's eleven dollars a month.' Half the price of a discount for half the movement."],
	[&"bundle", "Bundle It In", 1, 1, false, true,
		[["scale", ["appeal", 4]]], [["scale", ["appeal", 6]]],
		"'Since we're already doing the other two...' Worth nothing on your first offer to someone and enormous on your fourth."],
	[&"fearmonger", "Fearmonger", 1, 1, false, true,
		[["appeal", 7], ["patience", -4]], [["appeal", 10], ["patience", -4]],
		"You describe, vividly, what happens to people who skip it. It works. It also costs them a third of their afternoon."],
	[&"hardclose", "Hard Close", 2, 1, false, true,
		[["appeal", 12], ["patience", -6]], [["appeal", 16], ["patience", -6]],
		"You stop being pleasant about it. Two ticks off the whole floor, six off theirs, and it moves them further than anything else you own."],
]

const DESIGN_RULE := "One product per interest, exactly - nine interests, nine products, no gaps and no doubles. The STARTER six are two per category, which is load-bearing twice over: a category read is always actionable, and the Karen's demanded category is always servable. Margins are a ladder deliberately uncorrelated with how often an interest is ranked highly, so their number one might be the $600 concierge plan while the $1,600 service contract sits seventh. Ticks are the scarce currency, so the big concession is tick-cheap and margin-expensive and the small one is the reverse; a card better than another on both axes is a bug. No support card may move appeal by a full appeal_step for free, or it becomes a substitute for reading the customer and diagnosis stops paying."

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(PRODUCT_DIR)
	var interests: InterestPool = load(INTERESTS)

	var cards: Array[CardDef] = []
	for row in PRODUCTS:
		var p := ProductCardDef.new()
		p.id = row[0]
		p.display_name = row[1]
		p.interest = interests.by_id(row[2])
		p.margin = row[3]
		p.upgraded_margin = row[3] + 300
		p.starter = row[4]
		p.text = row[5]
		p.ticks = 1
		p.copies = 1
		var path := "%s/%s.tres" % [PRODUCT_DIR, row[0]]
		ResourceSaver.save(p, path)
		cards.append(load(path))

	DirAccess.make_dir_recursive_absolute(SUPPORT_DIR)
	var support := 0
	for row in SUPPORT:
		var s := SupportCardDef.new()
		s.id = row[0]
		s.display_name = row[1]
		s.ticks = row[2]
		s.copies = row[3]
		s.starter = row[4]
		s.needs_offer = row[5]
		s.effects = _build(row[6])
		s.upgraded_effects = _build(row[7])
		s.text = row[8]
		var path := "%s/%s.tres" % [SUPPORT_DIR, row[0]]
		ResourceSaver.save(s, path)
		cards.append(load(path))
		support += 1

	var pool := CardPool.new()
	pool.design_rule = DESIGN_RULE
	pool.cards = cards
	ResourceSaver.save(pool, POOL_PATH)

	print("seeded %d products, %d support" % [cards.size() - support, support])
	quit(0)

func _build(specs: Array) -> Array[Effect]:
	## specs are [ClassName, amount] pairs, or ["scale", inner_spec] for the
	## one combinator.
	var out: Array[Effect] = []
	for spec in specs:
		out.append(_one(spec))
	return out

func _one(spec: Array) -> Effect:
	var kind: String = spec[0]
	match kind:
		"appeal":
			var e := ChangeAppeal.new(); e.amount = spec[1]; return e
		"margin":
			var e := ChangeMargin.new(); e.amount = spec[1]; return e
		"line":
			var e := ChangeLine.new(); e.amount = spec[1]; return e
		"patience":
			var e := ChangePatience.new(); e.amount = spec[1]; return e
		"patience_floor":
			var e := ChangePatienceFloor.new(); e.amount = spec[1]; return e
		"reveal":
			return RevealRoom.new()
		"discard":
			var e := DiscardHand.new(); e.amount = spec[1]; return e
		"bonus":
			var e := MarginBonus.new(); e.amount = spec[1]; return e
		"scale":
			var e := ScaleBySales.new(); e.inner = _one(spec[1]); return e
	push_error("unknown effect spec: %s" % kind)
	return Effect.new()
