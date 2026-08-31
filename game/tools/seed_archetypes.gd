extends SceneTree
## Bootstrap for the seven archetypes and their actions.
##
##     godot --headless --path game --script res://tools/seed_archetypes.gd

const DIR := "res://data/archetypes"
const POOL_PATH := "res://data/archetype_pool.tres"
const INTERESTS := "res://data/interests/interest_pool.tres"

## id, name, pattern, tell, line, patience, line_per_sale, top, bottom, demands
const ARCHETYPES := [
	[&"easygoing", "Easygoing",
		"This is how the loop works.",
		"pleasant, unhurried, no strong opinions about anything",
		35, 16, 3, [], [], false],
	[&"laydown", "Lay-Down Larry",
		"Take the free money and LEAVE - they are worth two fast sales, not six ticks of optimising.",
		"already nodding, and has not asked a single question",
		20, 16, 3, [], [], false],
	[&"hawk", "Budget Hawk",
		"Over-build appeal BEFORE you ask, and pay for it in margin.",
		"brought a printout, and keeps saying 'out the door'",
		40, 16, 3, [&"affordability", &"equity"], [&"status", &"power"], false],
	[&"kicker", "Tire Kicker",
		"Do not diagnose. Sell them SOMETHING, now.",
		"keeps glancing at the lot, half out of the chair already",
		35, 9, 3, [], [], false],
	[&"tech", "Tech Enthusiast",
		"Hunt the bullseye. Do not grind a mediocre product upward when the right one pays a premium.",
		"asked about the drivetrain before asking about the price",
		35, 16, 3, [&"security", &"power"], [&"affordability"], false],
	[&"family", "Family First",
		"Sell them their favourites, fast. They never get harder - but fishing below their top five bleeds them.",
		"there are two car seats in the trade-in",
		35, 16, 0, [&"stability", &"reliability"], [&"status"], false],
	[&"karen", "The Karen",
		"See to them FIRST, and give them what they actually came in for.",
		"has already asked who the manager is, twice",
		35, 16, 3, [], [], true],
]

## archetype id -> [action id, name, tell, dialogue, trigger spec, effects]
const ACTIONS := {
	&"hawk": [[&"shops_you", "Tells you what the other guy quoted",
		"ANY offer that falls short moves their Line +5",
		"\"I had another dealer at less than that.\"",
		["on_offer", 1, 0], [["line", 5]]]],
	&"kicker": [[&"antsy", "Half out of the chair already",
		"every 4 ticks they are on the floor, they lose 2 more patience",
		"\"How long is this going to take?\"",
		["every", 4], [["patience", -2]]]],
	&"tech": [[&"bullseye", "Pays up for the right toy",
		"a sale on their 1st or 2nd interest banks an extra $300",
		"\"Now THAT I actually want.\"",
		["on_sale", 3], [["bonus", 300]]]],
	&"family": [[&"not_here_for_that", "Not what they came in for",
		"offering anything outside their top five costs 4 patience, sold or not",
		"\"...that's really not what we're here for.\"",
		["on_offer", 0, 5], [["patience", -4]]]],
	&"karen": [[&"manager", "Asks for the manager, loudly",
		"every 5 ticks, EVERYONE ELSE on the floor loses 1 patience",
		"\"Is there someone else I can speak to?\"",
		["every", 5], [["patience_floor", -1]]]],
}

const NAMES := [
	"Sandra Okonkwo", "Marcus Reyes", "Dee Whitfield", "Priya Raman",
	"Tom Bergeron", "Alice Nakamura", "Ray Castellano", "Nadia Haddad",
	"Glen Murphy", "Bev Chalmers", "Oscar Delgado", "Junie Park",
	"Hank Voss", "Imani Brooks", "Wes Kowalczyk", "Lorna Fitch",
	"Dmitri Sokolov", "Carmen Ruiz", "Ellis Tran", "Maureen Doyle",
]

const DESIGN_RULE := "Every archetype exists to teach exactly ONE play pattern, and its numbers and actions are chosen to force that pattern rather than to decorate it. State the pattern before writing any numbers; if you cannot say it in one sentence, the archetype is not designed yet. A RESOURCE archetype moves one number off base so you can always tell which resource you are failing at; a READ archetype leaves the numbers alone and differs only in priors. Priors must be reliable but not certain - prior_slip means each seeding can fail, because a prior that is never wrong is a lookup table, not a read. Actions are TELEGRAPHED on arrival: you play around known behaviour, and stepping in the trap is on you. Keep at least two archetypes in the player's favour, or the system reads as punishment instead of personality - a favour can be an action (Tech pays a premium) or a property (Family First never gets harder, Lay-Down starts low)."


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var interests: InterestPool = load(INTERESTS)

	var list: Array[CustomerArchetype] = []
	for row in ARCHETYPES:
		var a := CustomerArchetype.new()
		a.id = row[0]
		a.display_name = row[1]
		a.pattern = row[2]
		a.tell = row[3]
		a.line = row[4]
		a.patience = row[5]
		a.line_per_sale = row[6]
		a.top_interests = _interests_from(interests, row[7])
		a.bottom_interests = _interests_from(interests, row[8])
		a.demands_category = row[9]
		a.actions = _actions_for(row[0])
		var path := "%s/%s.tres" % [DIR, row[0]]
		ResourceSaver.save(a, path)
		list.append(load(path))

	var pool := ArchetypePool.new()
	pool.design_rule = DESIGN_RULE
	pool.archetypes = list
	var names: Array[String] = []
	for n in NAMES:
		names.append(n)
	pool.names = names
	ResourceSaver.save(pool, POOL_PATH)

	print("seeded %d archetypes" % list.size())
	quit(0)


func _interests_from(pool: InterestPool, ids: Array) -> Array[Interest]:
	var out: Array[Interest] = []
	for id in ids:
		out.append(pool.by_id(id))
	return out


func _actions_for(arch_id: StringName) -> Array[CustomerAction]:
	var out: Array[CustomerAction] = []
	if not ACTIONS.has(arch_id):
		return out
	for row in ACTIONS[arch_id]:
		var act := CustomerAction.new()
		act.id = row[0]
		act.display_name = row[1]
		act.tell = row[2]
		act.dialogue = row[3]
		act.trigger = _trigger(row[4])
		act.effects = _effects(row[5])
		out.append(act)
	return out


func _trigger(spec: Array) -> Trigger:
	match spec[0]:
		"on_offer":
			var t := OnOffer.new()
			t.short_at = spec[1]
			t.rank_worse_than = spec[2]
			return t
		"on_sale":
			var t := OnSale.new()
			t.rank_better_than = spec[1]
			return t
		"every":
			var t := Every.new()
			t.ticks = spec[1]
			return t
		"patience_below":
			var t := PatienceBelow.new()
			t.at = spec[1]
			return t
	push_error("unknown trigger: %s" % spec[0])
	return Trigger.new()


func _effects(specs: Array) -> Array[Effect]:
	var out: Array[Effect] = []
	for spec in specs:
		match spec[0]:
			"line":
				var e := ChangeLine.new(); e.amount = spec[1]; out.append(e)
			"appeal":
				var e := ChangeAppeal.new(); e.amount = spec[1]; out.append(e)
			"margin":
				var e := ChangeMargin.new(); e.amount = spec[1]; out.append(e)
			"patience":
				var e := ChangePatience.new(); e.amount = spec[1]; out.append(e)
			"patience_floor":
				var e := ChangePatienceFloor.new(); e.amount = spec[1]; out.append(e)
			"discard":
				var e := DiscardHand.new(); e.amount = spec[1]; out.append(e)
			"bonus":
				var e := MarginBonus.new(); e.amount = spec[1]; out.append(e)
			_:
				push_error("unknown effect: %s" % spec[0])
	return out
