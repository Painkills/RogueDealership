extends RefCounted
## Everything the game says ABOUT a customer uses they/them - an archetype's
## name, pattern and tell, what its actions and demands are called and say, the
## back of their folder, and the blurbs of the shifts that send them. Not what a
## customer says themselves: that is their own voice, in the dialogue library.
## One result for the lot, listing every offender - a new archetype or shift
## gets held to it without anybody writing a check for it.
var h: Harness

const CFG := {"appeal_step": 5, "line_per_sale": 3, "leaving_soon_at": 4}

func _gendered(text: String) -> Array[String]:
	var re := RegEx.new()
	re.compile("(?i)\\b(he|him|his|himself|she|her|hers|herself)\\b")
	var found: Array[String] = []
	for m in re.search_all(text):
		found.append(m.get_string())
	return found

## A demand, as the player reads it: its name, its shout above their head, what
## answers it, and what meeting or ignoring it does.
func _demand_texts(d: Demand, out: Dictionary) -> void:
	out["demand %s" % d.id] = "%s | %s | %s" % [d.display_name, d.telegraph,
		d.resolve.describe() if d.resolve != null else ""]
	for e in d.effects + d.relief:
		out["demand %s effect" % d.id] = out.get("demand %s effect" % d.id, "") + e.describe() + " | "

func _described() -> Dictionary:
	var out := {}
	var interests: InterestPool = load("res://data/interests/interest_pool.tres")
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var archetypes: ArchetypePool = load("res://data/archetype_pool.tres")
	for a in archetypes.archetypes:
		out["%s" % a.id] = "%s | %s | %s" % [a.display_name, a.pattern, a.tell]
		for act in a.actions:
			out["%s / %s" % [a.id, act.id]] = "%s | %s" % [act.display_name, act.tell]
			for e in act.effects:
				if e is RaiseDemand and e.demand != null:
					_demand_texts(e.demand, out)
		# The back of their folder, which is built from all of the above and the
		# standing rules nothing fires for.
		var c := Customer.new("A", "Test Person", a,
			Customer.make_ranks(interests, rng), a.patience, a.patience, CFG, interests)
		if a.demands_category:
			c.demands_category = interests.categories[0].id
		out["%s folder" % a.id] = CustomerCard3D.behaviour_text(c)
	var profiles: ShiftProfilePool = load("res://data/shift_profile_pool.tres")
	var shifts: Array[ShiftProfile] = profiles.profiles.duplicate()
	for category in profiles.categories:
		shifts.append_array(category.shifts)
	for p in shifts:
		out["shift %s" % p.id] = "%s | %s" % [p.display_name, p.blurb]
	return out

func test_customers_are_always_described_as_they_and_them() -> void:
	var described := _described()
	var offenders: Array[String] = []
	for where in described:
		var found := _gendered(str(described[where]))
		if not found.is_empty():
			offenders.append("%s says %s" % [where, ", ".join(found)])
	h.check("nobody is a he or a she (%s)" % "; ".join(offenders), offenders.is_empty())
	h.check("and the lint reads every archetype, not nothing (%d texts)" % described.size(),
		described.size() >= (load("res://data/archetype_pool.tres") as ArchetypePool).archetypes.size())
