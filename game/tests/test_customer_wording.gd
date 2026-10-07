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
	out["demand %s" % d.id] = "%s | %s | %s | %s" % [d.display_name, d.telegraph,
		d.resolve.describe() if d.resolve != null else "",
		d.resolve.how_to_answer() if d.resolve != null else ""]
	for e in d.effects + d.relief:
		out["demand %s effect" % d.id] = out.get("demand %s effect" % d.id, "") + e.describe() + " | "

## Everyone who can sit down: the pool's, and whoever a shift names - a boss like
## the Whale comes in only that way.
func _everyone() -> Array:
	var out: Array = (load("res://data/archetype_pool.tres") as ArchetypePool).archetypes.duplicate()
	for category in (load("res://data/shift_profile_pool.tres") as ShiftProfilePool).categories:
		for p in category.shifts:
			for a in p.lineup + p.only_archetypes:
				if a != null and not out.has(a):
					out.append(a)
	return out

func _described() -> Dictionary:
	var out := {}
	var interests: InterestPool = load("res://data/interests/interest_pool.tres")
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	for a in _everyone():
		out["%s" % a.id] = "%s | %s | %s" % [a.display_name, a.pattern, a.tell]
		for act in a.actions:
			out["%s / %s" % [a.id, act.id]] = "%s | %s" % [act.display_name, act.tell]
			for e in act.effects:
				if e is RaiseDemand and e.demand != null:
					_demand_texts(e.demand, out)
		for d in a.moves:
			if d != null:
				_demand_texts(d, out)
		for t in a.timed_moves:
			if t != null and t.move != null:
				_demand_texts(t.move, out)
		# The back of their folder, which is built from all of the above and the
		# standing rules nothing fires for.
		var c := Customer.new("A", "Test Person", a,
			Customer.make_ranks(interests, rng), a.patience, a.patience, CFG, interests)
		if a.demands_category:
			c.demands_category = interests.categories[0].id
		if a.budget_share > 0.0:
			c.budget = 1000
		# What a boss's two side folders say - the budget, and each move live.
		if a.is_boss():
			c.start_timed_moves(0)
			out["%s budget folder" % a.id] = str(BossPanels.budget_note(c, 0))
			out["%s quiet folder" % a.id] = str(BossPanels.move_note(c, 0))
			var all_moves: Array = a.moves.duplicate()
			for t in a.timed_moves:
				if t != null and t.move != null:
					all_moves.append(t.move)
			for d in all_moves:
				c.demand = d
				c.demand_due_tick = 3
				out["%s folder, %s" % [a.id, d.id]] = str(BossPanels.move_note(c, 0))
			c.demand = null
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

func test_an_action_is_called_what_its_warning_says() -> void:
	## The back of the folder names an action; when it goes off, the front shouts
	## its demand's telegraph. "Waves a competitor's quote" on one side and PRICE
	## CHECK on the other read as two different things - one name, the short one,
	## on both sides and in the floor's log.
	var mismatched: Array[String] = []
	var checked := 0
	for a in _everyone():
		for act in a.actions:
			for e in act.effects:
				if not (e is RaiseDemand) or e.demand == null:
					continue
				checked += 1
				var d: Demand = e.demand
				if act.display_name.to_upper() != d.telegraph or d.display_name != act.display_name:
					mismatched.append("%s / %s: \"%s\", demand \"%s\", warning %s"
						% [a.id, act.id, act.display_name, d.display_name, d.telegraph])
		# A boss's move has no action: it goes by its own warning - in the
		# rotation, or at a budget.
		var moves: Array = a.moves.duplicate()
		for t in a.timed_moves:
			if t != null and t.move != null:
				moves.append(t.move)
		for d in moves:
			checked += 1
			if d != null and d.display_name.to_upper() != d.telegraph:
				mismatched.append("%s / move %s: \"%s\", warning %s"
					% [a.id, d.id, d.display_name, d.telegraph])
	h.check("every action and its demand go by their warning (%s)" % "; ".join(mismatched),
		mismatched.is_empty())
	h.check("and the check reads some actions, not none (%d)" % checked, checked > 0)
