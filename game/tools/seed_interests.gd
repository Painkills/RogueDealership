extends SceneTree
## One-off bootstrap: writes the interest/category resources from m2's board.
##
##     godot --headless --path game --script res://tools/seed_interests.gd
##
## This is a BOOTSTRAP, not a build step. Once written, the .tres files are the
## source of truth and are edited in the Inspector.

const DIR := "res://data/interests"

const CATEGORIES := [
	[&"vehicle", "Vehicle", "the car itself"],
	[&"deal", "Deal", "the money"],
	[&"person", "Person", "their life"],
]

const INTERESTS := [
	[&"reliability", "Reliability", &"vehicle", "will it break"],
	[&"security", "Security", &"vehicle", "will it get taken"],
	[&"power", "Power", &"vehicle", "what can it do"],
	[&"affordability", "Affordability", &"deal", "can I make the payment"],
	[&"equity", "Equity", &"deal", "am I upside-down"],
	[&"value_retention", "Value Retention", &"deal", "what's it worth later"],
	[&"stability", "Stability", &"person", "does my income hold up"],
	[&"convenience", "Convenience", &"person", "how much hassle is this"],
	[&"status", "Status", &"person", "how do I look in it"],
]

const DESIGN_RULE := "Exactly 3 categories x 3 interests = 9, and every interest has exactly one product answering it. The count is load-bearing: appeal = appeal_step x (interest_count - rank), so a tenth interest silently reflates every appeal number in the game. Categories exist so a read can hand you PARTIAL information - \"they are a Vehicle person\" is worth a tick precisely because it narrows nine to three rather than to one."

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)

	var cats := {}
	var cat_list: Array[Category] = []
	for row in CATEGORIES:
		var c := Category.new()
		c.id = row[0]
		c.display_name = row[1]
		c.blurb = row[2]
		var path := "%s/%s.tres" % [DIR, row[0]]
		ResourceSaver.save(c, path)
		cats[row[0]] = load(path)
		cat_list.append(cats[row[0]])

	var interest_list: Array[Interest] = []
	for row in INTERESTS:
		var i := Interest.new()
		i.id = row[0]
		i.display_name = row[1]
		i.category = cats[row[2]]
		i.blurb = row[3]
		var path := "%s/%s.tres" % [DIR, row[0]]
		ResourceSaver.save(i, path)
		interest_list.append(load(path))

	var pool := InterestPool.new()
	pool.design_rule = DESIGN_RULE
	pool.categories = cat_list
	pool.interests = interest_list
	ResourceSaver.save(pool, "%s/interest_pool.tres" % DIR)

	print("seeded %d categories, %d interests" % [cat_list.size(), interest_list.size()])
	quit(0)
