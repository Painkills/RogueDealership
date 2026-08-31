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

	var pool := CardPool.new()
	pool.design_rule = DESIGN_RULE
	pool.cards = cards
	ResourceSaver.save(pool, POOL_PATH)

	print("seeded %d products" % cards.size())
	quit(0)
