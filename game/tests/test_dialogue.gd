extends RefCounted
## DialogueLine / DialoguePool - the tagged, randomized library customer
## reactions draw from - plus Shift._support()'s hook into it. Unrelated to
## the archetype-action/demand dialogue migrated in a later commit; this file
## covers the pool mechanics and the support-card integration.
var h: Harness

const POOL := "res://data/dialogue/dialogue_pool.tres"

func _pool() -> DialoguePool:
	return load(POOL)

func _shift(floor_ids: Array, overrides: Dictionary = {}) -> Shift:
	var cfg: ShiftConfig = (load("res://data/shift_config.tres") as ShiftConfig).duplicate()
	cfg.patience_jitter = 0
	cfg.action_cadence_jitter_ticks = 0
	cfg.prior_slip = 0.0
	cfg.arrival_patience_min_fraction = 1.0
	for k in overrides:
		cfg.set(k, overrides[k])
	return Shift.new(cfg,
		load("res://data/interests/interest_pool.tres"),
		load("res://data/card_pool.tres"),
		load("res://data/archetype_pool.tres"), 1, floor_ids,
		null, 0, 1, 0, 0, _pool())

func _hand(s: Shift, ids: Array) -> void:
	s.hand.clear()
	var uid := 900
	for id in ids:
		s.hand.append(CardInstance.new(s.card_pool.by_id(id), uid))
		uid += 1

func _at(s: Shift, chair: int = 0) -> Customer:
	s.at = chair
	s.last_customer = s.chairs[chair]
	return s.chairs[chair]

## Hand position is not stable once _draw_up() refills behind you - a freshly
## drawn card lands at index 0 (Shift._draw_up()), pushing whatever _hand()
## set up further back by exactly one slot per refill. Scan by id instead of
## assuming a card stays wherever it started.
func _index_of(s: Shift, id: StringName) -> int:
	for i in range(s.hand.size()):
		if s.hand[i].card.id == id:
			return i
	return -1

func _valid_bands(s: Shift) -> Array[StringName]:
	var seen: Dictionary = {}
	for gap in range(-10, 41):
		seen[StringName(s.band_for(gap))] = true
	var out: Array[StringName] = []
	for k in seen:
		out.append(k)
	return out

# ----------------------------------------------------------- pool invariants
func test_the_pool_states_its_design_rule() -> void:
	var pool := _pool()
	h.check("non-empty", pool.design_rule.strip_edges() != "")
	h.check("warns an Inspector editor it will be overwritten",
		pool.design_rule.contains("GENERATED"))

func test_every_line_has_words_and_at_least_one_tag() -> void:
	for l in _pool().lines:
		h.check("has text (%s)" % l.text.substr(0, 20), l.text.strip_edges() != "")
		h.check("%s has at least one tag" % l.text.substr(0, 20), not l.tags.is_empty())

func test_every_line_is_a_quoted_sentence_that_fits_the_bubble() -> void:
	## 72 is a guess at what SpeechBubble's single Label can hold on the card
	## without reflowing everything below it - retune here if it turns out
	## wrong, the same way every other guessed number in this project is.
	for l in _pool().lines:
		h.check("%s starts quoted" % l.text, l.text.begins_with("\""))
		h.check("%s ends quoted" % l.text, l.text.ends_with("\""))
		h.check("%s fits the bubble (%d chars)" % [l.text, l.text.length()],
			l.text.length() <= 72)

func test_every_tag_used_is_a_tag_the_pool_declares() -> void:
	var pool := _pool()
	for l in pool.lines:
		for t in l.tags:
			h.check("%s uses a declared tag (%s)" % [l.text, t],
				pool.known_tags.has(t))

func test_every_narrowing_names_something_that_exists() -> void:
	var pool := _pool()
	var archetypes: ArchetypePool = load("res://data/archetype_pool.tres")
	var cards: CardPool = load("res://data/card_pool.tres")
	var bands := _valid_bands(_shift([&"easygoing"]))
	for l in pool.lines:
		for a in l.archetype_ids:
			h.check("%s names a real archetype (%s)" % [l.text, a],
				archetypes.by_id(a) != null)
		for p in l.product_ids:
			var card := cards.by_id(p)
			h.check("%s names a real product (%s)" % [l.text, p], card != null)
			if card != null:
				h.check("%s's product is actually a product, not a support card" % l.text,
					card is ProductCardDef)
		for b in l.appeal_bands:
			h.check("%s names a real band (%s)" % [l.text, b], bands.has(b))

func test_every_tag_keeps_a_line_with_no_narrowings() -> void:
	## This is what guarantees the system never goes silent: whatever the
	## archetype/product/band, a tag with a generic fallback always has
	## something to say.
	var pool := _pool()
	for tag in pool.known_tags:
		var has_generic := false
		for l in pool.lines:
			if l.tags.has(tag) and l.specificity() == 0:
				has_generic = true
				break
		h.check("tag %s keeps at least one fully generic line" % tag, has_generic)

func test_every_card_asks_only_for_tags_that_exist() -> void:
	var pool := _pool()
	var cards: CardPool = load("res://data/card_pool.tres")
	for c in cards.cards:
		for t in c.dialogue_tags:
			h.check("%s asks only for a declared tag (%s)" % [c.id, t],
				pool.known_tags.has(t))

func test_every_archetype_actions_tags_are_declared() -> void:
	var pool := _pool()
	var archetypes: ArchetypePool = load("res://data/archetype_pool.tres")
	for arch in archetypes.archetypes:
		for act in arch.actions:
			for t in act.dialogue_tags:
				h.check("%s's %s asks only for a declared tag (%s)"
						% [arch.id, act.id, t], pool.known_tags.has(t))

func test_every_demand_reachable_from_an_archetype_has_declared_tags() -> void:
	## Demands are not pooled - reached only through whichever archetype
	## action's RaiseDemand effect opens them - so this walks the same path
	## the real game does to find every one that exists.
	var pool := _pool()
	var archetypes: ArchetypePool = load("res://data/archetype_pool.tres")
	var seen := {}
	for arch in archetypes.archetypes:
		for act in arch.actions:
			for e in act.effects:
				if e is RaiseDemand and e.demand != null and not seen.has(e.demand.id):
					seen[e.demand.id] = true
					var d: Demand = e.demand
					for t in d.dialogue_tags_met:
						h.check("%s's met tag is declared (%s)" % [d.id, t],
							pool.known_tags.has(t))
					for t in d.dialogue_tags_missed:
						h.check("%s's missed tag is declared (%s)" % [d.id, t],
							pool.known_tags.has(t))
	h.check("found shipped demands to check (%d)" % seen.size(), not seen.is_empty())

# ------------------------------------------------------------- the filters
func test_a_line_is_only_offered_to_the_pools_it_is_tagged_for() -> void:
	var patience_line := "\"Ha. The 401 was a parking lot this morning too.\""
	var texts: Array[String] = []
	for l in _pool().candidates([&"appeal"], &"easygoing", &"", &""):
		texts.append(l.text)
	h.check("a patience line never shows up in the appeal pool",
		not texts.has(patience_line))

func test_a_line_written_for_one_archetype_is_unavailable_to_everybody_else() -> void:
	var karen_line := "\"And is that in writing, or just you saying it?\""
	var karen_texts: Array[String] = []
	for l in _pool().candidates([&"appeal"], &"karen", &"", &""):
		karen_texts.append(l.text)
	var hawk_texts: Array[String] = []
	for l in _pool().candidates([&"appeal"], &"hawk", &"", &""):
		hawk_texts.append(l.text)
	h.check("available to the karen", karen_texts.has(karen_line))
	h.check("unavailable to the hawk", not hawk_texts.has(karen_line))

func test_a_line_naming_a_product_is_unavailable_with_an_empty_table() -> void:
	var gap_line := "\"So if I total it, that is the part that covers me?\""
	var with_gap: Array[String] = []
	for l in _pool().candidates([&"appeal"], &"easygoing", &"gap", &""):
		with_gap.append(l.text)
	var with_nothing: Array[String] = []
	for l in _pool().candidates([&"appeal"], &"easygoing", &"", &""):
		with_nothing.append(l.text)
	h.check("available with the gap on the table", with_gap.has(gap_line))
	h.check("unavailable with nothing on the table", not with_nothing.has(gap_line))
	h.check("but the generic pool still has SOMETHING with nothing on the table",
		not with_nothing.is_empty())

func test_a_line_written_for_one_band_is_unavailable_at_another() -> void:
	var cold_line := "\"You are not really selling me here.\""
	var at_cold: Array[String] = []
	for l in _pool().candidates([&"appeal"], &"easygoing", &"", &"COLD"):
		at_cold.append(l.text)
	var at_almost: Array[String] = []
	for l in _pool().candidates([&"appeal"], &"easygoing", &"", &"ALMOST"):
		at_almost.append(l.text)
	h.check("available at COLD", at_cold.has(cold_line))
	h.check("unavailable at ALMOST", not at_almost.has(cold_line))

func test_an_unfiltered_line_is_available_in_every_circumstance() -> void:
	var generic_line := "\"Okay. Keep talking.\""
	for arch_id in [&"karen", &"hawk", &"tech", &"kicker", &"family",
			&"easygoing", &"laydown"]:
		for product_id in [&"", &"vsc", &"gap"]:
			for band in [&"", &"COLD", &"WARM", &"COOL", &"ALMOST"]:
				var texts: Array[String] = []
				for l in _pool().candidates([&"appeal"], arch_id, product_id, band):
					texts.append(l.text)
				h.check("available for %s/%s/%s" % [arch_id, product_id, band],
					texts.has(generic_line))

# ------------------------------------------------------------------ the draw
func test_a_specific_line_beats_the_generic_ones_without_silencing_them() -> void:
	## The single most important test in this file: a strict "most specific
	## wins" rule would make the karen line win EVERY time, retiring the five
	## generic lines for every karen for the rest of the game. Weighted
	## instead: dominant, but never exclusive.
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var counts: Dictionary = {}
	for _i in range(400):
		var said := _pool().pick(rng, [&"appeal"], &"karen", &"", &"")
		counts[said] = int(counts.get(said, 0)) + 1
	var karen_line := "\"And is that in writing, or just you saying it?\""
	h.check("the karen line was actually drawn", counts.has(karen_line))
	var karen_count: int = counts.get(karen_line, 0)
	var distinct_others := 0
	for text in counts:
		if text == karen_line:
			continue
		distinct_others += 1
		h.check("the karen line (%d picks) beats %s (%d picks)"
				% [karen_count, text, counts[text]],
			karen_count >= counts[text])
	h.check("and at least two OTHER lines still got picked - not silenced",
		distinct_others >= 2)

func test_the_same_seed_says_the_same_things() -> void:
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 7
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 7
	for _i in range(20):
		h.eq("same seed, same pick",
			_pool().pick(rng_a, [&"appeal"], &"karen", &"", &""),
			_pool().pick(rng_b, [&"appeal"], &"karen", &"", &""))

func test_nothing_matching_is_silence_not_a_crash() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	h.eq("an unknown tag returns silence, not a crash",
		_pool().pick(rng, [&"nonsense"], &"", &"", &""), "")
	h.eq("no tags at all returns silence too",
		_pool().pick(rng, [], &"", &"", &""), "")

# --------------------------------------------------------- the Shift hook
func test_playing_a_support_card_finally_reaches_the_shift_log() -> void:
	## Until this feature, playing a support card produced NO log line at
	## all - only archetype-fired actions did.
	var s := _shift([&"karen"])
	var c := _at(s)
	c.line = 0
	_hand(s, [&"vsc", &"explain"])
	s.place(0)
	# Putting the product down has its own say (see test_..._objection below);
	# what is counted here is the card's own entry.
	var before := s.action_log.size()
	s.play_card(_index_of(s, &"explain"))
	h.eq("one new entry", s.action_log.size(), before + 1)
	var entry: Dictionary = s.action_log[before]
	for key in ["key", "customer", "name", "dialogue", "descriptions", "floor_wide"]:
		h.check("entry carries %s" % key, entry.has(key))
	h.eq("named for the card", entry["name"], s.card_pool.by_id(&"explain").display_name)

func test_the_customer_says_something_back() -> void:
	var s := _shift([&"karen"])
	var c := _at(s)
	c.line = 0
	_hand(s, [&"vsc", &"explain"])
	s.place(0)
	var before := s.action_log.size()
	s.play_card(_index_of(s, &"explain"))
	var said: String = s.action_log[before]["dialogue"]
	h.check("something was said", said != "")
	h.check("in the house voice - a quoted sentence", said.begins_with("\""))

func test_a_karen_gets_a_karen_line() -> void:
	var s := _shift([&"karen"])
	var c := _at(s)
	c.line = 0
	_hand(s, [&"vsc", &"explain"])
	s.place(0)
	var before := s.action_log.size()
	var card: CardDef = s.card_pool.by_id(&"explain")
	s.play_card(_index_of(s, &"explain"))
	var said: String = s.action_log[before]["dialogue"]
	var band := StringName(s.band_for(c.line - c.offer.appeal))
	var eligible: Array[String] = []
	for l in _pool().candidates(card.dialogue_tags, c.archetype.id, c.offer.product.id,
			band, c.objection):
		eligible.append(l.text)
	h.check("the line said is one the karen actually qualifies for (got: %s)" % said,
		eligible.has(said))

func test_an_untagged_card_is_logged_but_silent() -> void:
	var s := _shift([&"easygoing"])
	var quiet := _a_support_card(s, [])
	quiet.dialogue_tags = []
	_play(s, quiet)
	h.eq("one entry", s.action_log.size(), 1)
	h.eq("but nothing said - the card carries no dialogue_tags",
		s.action_log[0]["dialogue"], "")

func test_a_shift_with_no_dialogue_pool_still_logs_every_card() -> void:
	var cfg: ShiftConfig = (load("res://data/shift_config.tres") as ShiftConfig).duplicate()
	cfg.patience_jitter = 0
	cfg.action_cadence_jitter_ticks = 0
	cfg.prior_slip = 0.0
	cfg.arrival_patience_min_fraction = 1.0
	var s := Shift.new(cfg,
		load("res://data/interests/interest_pool.tres"),
		load("res://data/card_pool.tres"),
		load("res://data/archetype_pool.tres"), 1, [&"easygoing"])
	var c := _at(s)
	c.line = 0
	_hand(s, [&"vsc", &"explain"])
	s.place(0)
	s.play_card(_index_of(s, &"explain"))
	h.eq("still logged", s.action_log.size(), 1)
	h.eq("but silent - no pool to draw from", s.action_log[0]["dialogue"], "")

func test_the_band_a_line_is_matched_against_is_the_one_after_the_card_lands() -> void:
	var cold_texts: Array[String] = []
	for l in _pool().lines:
		if l.appeal_bands.has(&"COLD"):
			cold_texts.append(l.text)
	h.check("the seed actually has COLD-only appeal lines to test against",
		not cold_texts.is_empty())

	for seed in range(1, 21):
		var s := _shift([&"easygoing"])
		var c := _at(s)
		c.line = 100
		_hand(s, [&"vsc", &"explain"])
		s.place(0)
		c.offer.appeal = 75   # gap 25 - COLD, before the card
		s.rng.seed = seed
		var before := s.action_log.size()
		s.play_card(_index_of(s, &"explain"))   # +4 appeal -> gap 21 - COOL, after
		var said: String = s.action_log[before]["dialogue"]
		h.check(("seed %d never drew a COLD-only line once the gap left COLD "
				+ "(got: %s)") % [seed, said], not cold_texts.has(said))

func test_a_card_played_on_an_empty_table_never_mentions_a_product() -> void:
	var s := _shift([&"easygoing"])
	_at(s)
	_hand(s, [&"smalltalk"])
	s.play_card(0)
	var said: String = s.action_log[0]["dialogue"]
	h.check("said something", said != "")
	var chosen: DialogueLine = null
	for l in _pool().lines:
		if l.text == said:
			chosen = l
			break
	h.check("found the line in the pool", chosen != null)
	if chosen != null:
		h.check("it names no specific product - none was on the table",
			chosen.product_ids.is_empty())

# ------------------------------------------ the migrated action/demand dialogue
func test_a_demand_raise_still_speaks_after_the_migration() -> void:
	var s := _shift([&"karen"])
	var c := _at(s)
	c.ticks_on_floor = s.cfg.demand_grace_ticks
	var guard := 0
	while c.demand == null and guard < 100:
		s.dig(0)
		guard += 1
	h.check("she actually raised it", c.demand != null)
	h.check("something reached the log", not s.action_log.is_empty())
	h.check("and it carries a spoken line - CustomerAction.dialogue_tags "
			+ "still works after replacing the old fixed dialogue string",
		s.action_log[-1]["dialogue"] != "")

func test_a_met_demand_finally_says_something() -> void:
	## Previously hardcoded to "" unconditionally - a demand being satisfied
	## has never spoken until this migration.
	var s := _shift([&"karen"])
	var c := _at(s)
	var d: Demand = load("res://data/demands/manager.tres")
	c.demand = d
	c.demand_due_tick = s.tick + d.ticks
	s._settle_demand(c, true)
	var entry: Dictionary = s.action_log[0]
	h.check("says something on relief", entry["dialogue"] != "")
	h.check("in the house voice", str(entry["dialogue"]).begins_with("\""))

func test_a_missed_demand_also_says_something() -> void:
	var s := _shift([&"karen"])
	var c := _at(s)
	var d: Demand = load("res://data/demands/manager.tres")
	c.demand = d
	c.demand_due_tick = s.tick + d.ticks
	s._settle_demand(c, false)
	h.check("says something when ignored too", s.action_log[0]["dialogue"] != "")

# ------------------------------------------------- what they say on their own
## Every line the shift says on its own, not as the voice of a card, an action
## or a demand - taking a product, running short of patience.
func _chatter(s: Shift, from: int = 0) -> Array:
	return s.action_log.slice(from).filter(func(e): return bool(e.get("chatter", false)))

func _texts(tag: StringName, archetype_id: StringName, product_id: StringName) -> Array[String]:
	var out: Array[String] = []
	for l in _pool().candidates([tag], archetype_id, product_id, &""):
		out.append(l.text)
	return out

func test_taking_a_product_says_so_out_loud() -> void:
	## "...or replace with a new one about how they are happy about the
	## product they accepted." Their own yes, from the accepted lines they
	## qualify for - and a line written for the very product they took is one.
	var s := _shift([&"easygoing"])
	var c := _at(s)
	_hand(s, [&"gap"])
	s.place(0)
	c.line = 0
	var before := s.action_log.size()
	var res := s.offer()
	h.eq("it sold (%s)" % res.msg, res.kind, "sale")
	var said := _chatter(s, before)
	h.eq("and they said one thing about it", said.size(), 1)
	if said.size() != 1:
		return
	var entry: Dictionary = said[0]
	var fits := _texts(&"accepted", &"easygoing", &"gap")
	h.check("a yes they qualify for (%s)" % entry["dialogue"], fits.has(entry["dialogue"]))
	h.check("among them one about the GAP itself",
		fits.has("\"Good. I am not paying off a car I do not have.\""))
	h.eq("said by the customer who took it", entry["key"], c.key)
	h.eq("chatter names no action", entry["name"], "")
	h.check("and did nothing", (entry["descriptions"] as Array).is_empty())
	for key in ["key", "customer", "name", "dialogue", "descriptions", "floor_wide"]:
		h.check("but carries everything the log reads (%s)" % key, entry.has(key))

func test_an_offer_that_falls_short_is_not_a_yes() -> void:
	var s := _shift([&"easygoing"])
	var c := _at(s)
	_hand(s, [&"gap"])
	s.place(0)
	c.line = 999
	var before := s.action_log.size()
	var res := s.offer()
	h.eq("it fell short (%s)" % res.msg, res.kind, "miss")
	var yes := _texts(&"accepted", &"easygoing", &"gap")
	var said_yes := _chatter(s, before).filter(func(e): return yes.has(e["dialogue"]))
	h.eq("and nobody said yes to it", said_yes.size(), 0)

func test_reaching_impatience_says_so_once_per_dip() -> void:
	## "Add a dialogue line for when a customer reaches 5 or less patience" - at
	## whatever impatient_at the config holds.
	var s := _shift([&"easygoing"])
	var at: int = s.cfg.impatient_at
	var c := _at(s)
	c.patience = at + 2
	var theirs := func() -> Array:
		return _chatter(s).filter(func(e): return e["key"] == c.key)
	s.dig(0)
	h.eq("one above it, not yet (%d)" % c.patience, theirs.call().size(), 0)
	s.dig(0)
	h.eq("at it, out loud (%d)" % c.patience, theirs.call().size(), 1)
	if theirs.call().size() == 1:
		var said: String = theirs.call()[0]["dialogue"]
		h.check("in their own impatient voice (%s)" % said,
			_texts(&"impatient", &"easygoing", &"").has(said))
	s.dig(0)
	h.eq("once per dip - not again below it (%d)" % c.patience, theirs.call().size(), 1)
	# Back out of it, then down again: a fresh dip is a fresh complaint.
	c.add_patience(10)
	s._settle_patience()
	c.patience = at
	s._settle_patience()
	h.eq("a second dip says it again", theirs.call().size(), 2)

func test_a_customer_nowhere_near_it_says_nothing() -> void:
	var s := _shift([&"easygoing"])
	_at(s)
	var before := s.action_log.size()
	s._settle_patience()
	h.eq("full patience, no grumbling", _chatter(s, before).size(), 0)

func test_with_no_pool_nobody_says_anything_on_their_own() -> void:
	## The same silence every other line falls back to - a shift built without
	## a pool still plays, it just has nothing to say.
	var cfg: ShiftConfig = (load("res://data/shift_config.tres") as ShiftConfig).duplicate()
	cfg.patience_jitter = 0
	cfg.prior_slip = 0.0
	cfg.arrival_patience_min_fraction = 1.0
	var s := Shift.new(cfg,
		load("res://data/interests/interest_pool.tres"),
		load("res://data/card_pool.tres"),
		load("res://data/archetype_pool.tres"), 1, [&"easygoing"])
	var c := _at(s)
	_hand(s, [&"gap"])
	s.place(0)
	c.line = 0
	c.patience = 5
	s.offer()
	s._settle_patience()
	h.eq("nothing logged as chatter", _chatter(s).size(), 0)

# ------------------------------------------------------------ what YOU say
# CardDef.player_dialogue_tags. Made-up lines on copies of whatever cards the
# pool holds, so no retune, rename or new line of dialogue can break these.

func test_every_card_asks_only_for_player_tags_that_exist() -> void:
	var pool := _pool()
	var cards: CardPool = load("res://data/card_pool.tres")
	for c in cards.cards:
		for t in c.player_dialogue_tags:
			h.check("%s's own line asks only for a declared tag (%s)" % [c.id, t],
				pool.known_tags.has(t))

## A library of made-up lines, a row each: [text, tags, archetype_ids,
## product_ids, objection_ids, becomes], all but the first two optional.
func _lines(rows: Array) -> DialoguePool:
	var pool := DialoguePool.new()
	for r in rows:
		var l := DialogueLine.new()
		l.text = r[0]
		l.tags.assign(r[1])
		l.archetype_ids.assign(r[2] if r.size() > 2 else [])
		l.product_ids.assign(r[3] if r.size() > 3 else [])
		l.objection_ids.assign(r[4] if r.size() > 4 else [])
		l.becomes = r[5] if r.size() > 5 else &""
		l.key = r[6] if r.size() > 6 else &""
		l.replies_to.assign(r[7] if r.size() > 7 else [])
		pool.lines.append(l)
	return pool

func _voiced_shift(pool: DialoguePool, seed_value: int = 1) -> Shift:
	return Shift.new(load("res://data/shift_config.tres"),
		load("res://data/interests/interest_pool.tres"),
		load("res://data/card_pool.tres"),
		load("res://data/archetype_pool.tres"), seed_value, [],
		null, 0, 1, 0, 0, pool)

## A copy of the first card in the pool that `keep` passes, saying `tags`.
func _copy_of(s: Shift, keep: Callable, tags: Array[StringName]) -> CardDef:
	for c in s.card_pool.cards:
		if keep.call(c):
			var copy := c.duplicate() as CardDef
			copy.player_dialogue_tags = tags
			return copy
	return null

## One that can go down on an empty table, so nothing has to be placed first.
func _a_support_card(s: Shift, tags: Array[StringName]) -> CardDef:
	return _copy_of(s, func(c): return c is SupportCardDef and not c.needs_offer, tags)

func _a_product(s: Shift, tags: Array[StringName]) -> CardDef:
	return _copy_of(s, func(c): return c is ProductCardDef, tags)

## Plays `card` on the customer in chair 0, from a hand of just that card.
func _play(s: Shift, card: CardDef) -> Result:
	_at(s)
	s.hand.clear()
	s.hand.append(CardInstance.new(card, 900))
	return s.play_card(0)

func test_playing_a_card_says_your_line() -> void:
	var s := _voiced_shift(_lines([["\"mine\"", [&"t_mine"]]]))
	var card := _a_support_card(s, [&"t_mine"])
	h.check("the pool has a support card to play", card != null)
	if card == null:
		return
	h.check("it went down", _play(s, card).ok)
	h.eq("and you said your line", s.player_lines.size(), 1)
	if s.player_lines.size() == 1:
		h.eq("the one it asked for", s.player_lines[0], "\"mine\"")

func test_a_card_with_nothing_to_say_is_played_in_silence() -> void:
	var s := _voiced_shift(_lines([["\"mine\"", [&"t_mine"]]]))
	h.check("it went down", _play(s, _a_support_card(s, [])).ok)
	h.eq("without a word from you", s.player_lines.size(), 0)

func test_a_product_going_down_is_pitched_by_name() -> void:
	## A line naming the product you put down, beside one naming another: only
	## the first is yours to say.
	var s := _voiced_shift(null)
	var product := _a_product(s, [&"t_pitch"])
	s.dialogue = _lines([
		["\"this one\"", [&"t_pitch"], [], [product.id]],
		["\"some other one\"", [&"t_pitch"], [], [&"not_on_the_table"]]])
	h.check("it went down", _play(s, product).ok)
	h.eq("you pitched it", s.player_lines.size(), 1)
	if s.player_lines.size() == 1:
		h.eq("by name", s.player_lines[0], "\"this one\"")

func test_your_line_can_be_written_for_who_you_are_talking_to() -> void:
	var s := _voiced_shift(null)
	var who: StringName = _at(s).archetype.id
	s.dialogue = _lines([
		["\"for them\"", [&"t_mine"], [who]],
		["\"for somebody else\"", [&"t_mine"], [&"nobody_here"]]])
	_play(s, _a_support_card(s, [&"t_mine"]))
	h.eq("you said something", s.player_lines.size(), 1)
	if s.player_lines.size() == 1:
		h.eq("the line written for them", s.player_lines[0], "\"for them\"")

func test_a_generic_line_keeps_you_talking_when_nothing_specific_fits() -> void:
	var s := _voiced_shift(null)
	s.dialogue = _lines([
		["\"to anyone\"", [&"t_mine"]],
		["\"for somebody else\"", [&"t_mine"], [&"nobody_here"]]])
	_play(s, _a_support_card(s, [&"t_mine"]))
	h.eq("you said something", s.player_lines.size(), 1)
	if s.player_lines.size() == 1:
		h.eq("the generic one", s.player_lines[0], "\"to anyone\"")

func test_what_you_say_never_moves_the_games_own_dice() -> void:
	## Two shifts dealt from one seed and one card played in each; the only
	## difference is whether it makes you talk. Whatever the game rolls next -
	## who walks in, what they want - has to be the same in both. Two lines to
	## choose between: with one, picking it takes no roll at all.
	var rows := [["\"mine\"", [&"t_mine"]], ["\"also mine\"", [&"t_mine"]]]
	var talking := _voiced_shift(_lines(rows), 7)
	var quiet := _voiced_shift(_lines(rows), 7)
	_play(talking, _a_support_card(talking, [&"t_mine"]))
	_play(quiet, _a_support_card(quiet, []))
	h.eq("you talked in one", talking.player_lines.size(), 1)
	h.eq("and not in the other", quiet.player_lines.size(), 0)
	h.eq("and the game's dice are where they would have been",
		talking.rng.state, quiet.rng.state)

func test_a_speaker_steers_clear_of_what_they_just_said() -> void:
	var pool := _lines([["\"one\"", [&"t"]], ["\"two\"", [&"t"]], ["\"three\"", [&"t"]]])
	var rng := RandomNumberGenerator.new()
	for seed_value in range(1, 13):
		rng.seed = seed_value
		h.eq("seed %d says the one thing not said lately" % seed_value,
			pool.pick(rng, [&"t"], &"", &"", &"", &"", ["\"one\"", "\"two\""]), "\"three\"")
	h.check("and with nothing else left, a repeat beats silence",
		pool.pick(rng, [&"t"], &"", &"", &"", &"", ["\"one\"", "\"two\"", "\"three\""]) != "")

func test_playing_the_same_card_again_says_something_new() -> void:
	var s := _voiced_shift(_lines([["\"one\"", [&"t_mine"]], ["\"two\"", [&"t_mine"]],
		["\"three\"", [&"t_mine"]], ["\"ah\"", [&"t_back"]], ["\"oh\"", [&"t_back"]]]))
	var card := _a_support_card(s, [&"t_mine"])
	card.dialogue_tags = [&"t_back"]
	var theirs: Array[String] = []
	for _i in range(3):
		var before := s.action_log.size()
		_play(s, card)
		s.pending_pull = null
		theirs.append(s.action_log[before]["dialogue"])
	var yours := s.player_lines.slice(-3)
	h.check("three plays, three different lines from you (%s)" % str(yours),
		yours[0] != yours[1] and yours[1] != yours[2] and yours[0] != yours[2])
	h.check("and they never answer the same way twice running (%s)" % str(theirs),
		theirs[0] != theirs[1] and theirs[1] != theirs[2])

func test_every_reply_answers_a_line_that_exists() -> void:
	## A typo in a key is a line that is never answered again.
	var keys := {}
	for l in _pool().lines:
		if l.key != &"":
			keys[l.key] = true
	for l in _pool().lines:
		for k in l.replies_to:
			h.check("%s answers a line that exists (%s)" % [l.text, k], keys.has(k))

func test_a_keyed_line_is_answered_by_its_own_replies_or_not_at_all() -> void:
	## "Nice jacket" must not get "yeah, parking's a mess".
	var rows := [["\"nice jacket\"", [&"t_mine"], [], [], [], &"", &"k_jacket"],
		["\"thanks, it was on sale\"", [&"t_back"], [], [], [], &"", &"", [&"k_jacket"]],
		["\"parking's a mess\"", [&"t_back"], [], [], [], &"", &"", [&"k_parking"]],
		["\"ha, yeah\"", [&"t_back"]]]
	for seed_value in range(1, 9):
		var s := _voiced_shift(_lines(rows), seed_value)
		var card := _a_support_card(s, [&"t_mine"])
		card.dialogue_tags = [&"t_back"]
		var before := s.action_log.size()
		_play(s, card)
		h.eq("seed %d: the jacket gets the jacket's answer" % seed_value,
			s.action_log[before]["dialogue"], "\"thanks, it was on sale\"")
	var lonely := _voiced_shift(_lines([rows[0], rows[2], rows[3]]))
	var card := _a_support_card(lonely, [&"t_mine"])
	card.dialogue_tags = [&"t_back"]
	var before := lonely.action_log.size()
	_play(lonely, card)
	h.eq("with no answer written for it, silence - not a generic one",
		lonely.action_log[before]["dialogue"], "")

func test_an_unkeyed_line_never_gets_someone_elses_answer() -> void:
	var s := _voiced_shift(_lines([["\"well then\"", [&"t_mine"]],
		["\"parking's a mess\"", [&"t_back"], [], [], [], &"", &"", [&"k_parking"]],
		["\"ha, yeah\"", [&"t_back"]]]))
	var card := _a_support_card(s, [&"t_mine"])
	card.dialogue_tags = [&"t_back"]
	var before := s.action_log.size()
	_play(s, card)
	h.eq("only the generic answer", s.action_log[before]["dialogue"], "\"ha, yeah\"")

# -------------------------------------------------------------- objections
# A product under their Line draws an objection, the method's techniques answer
# it, and offering closes on it. The library's own rules are checked against
# the shipped library; the behaviour against made-up lines and copies of
# whatever cards the pool holds.

func test_every_objection_a_line_answers_or_opens_is_declared() -> void:
	var pool := _pool()
	for l in pool.lines:
		for o in l.objection_ids:
			h.check("%s answers a declared objection (%s)" % [l.text, o],
				pool.known_objections.has(o))
		if l.becomes != &"":
			h.check("%s opens a declared objection (%s)" % [l.text, l.becomes],
				pool.known_objections.has(l.becomes))

func test_every_products_objection_tags_are_declared() -> void:
	var pool := _pool()
	var cards: CardPool = load("res://data/card_pool.tres")
	for c in cards.cards:
		if c is ProductCardDef:
			for t in (c as ProductCardDef).objection_tags:
				h.check("%s objects only from a declared tag (%s)" % [c.id, t],
					pool.known_tags.has(t))

func test_every_objection_that_can_be_opened_gets_an_answer() -> void:
	## An objection nothing answers is a conversation that goes generic the
	## moment it starts - almost certainly a typo in an id.
	var pool := _pool()
	var answered := {}
	for l in pool.lines:
		for o in l.objection_ids:
			answered[o] = true
	for l in pool.lines:
		if l.becomes != &"":
			h.check("%s is answered somewhere (opened by %s)" % [l.becomes, l.text],
				answered.has(l.becomes))

## A shift with `rows` for a library, its chair-0 customer's Line put where
## `under` says, and a copy of a product that objects from `raise_tags`.
func _objecting(rows: Array, under: bool, raise_tags: Array[StringName],
		seed_value: int = 1) -> Array:
	var s := _voiced_shift(_lines(rows), seed_value)
	var product := _a_product(s, [])
	(product as ProductCardDef).objection_tags = raise_tags
	_at(s).line = 999 if under else 0
	return [s, product]

func test_a_product_under_their_line_draws_an_objection() -> void:
	var made := _objecting([["\"too much\"", [&"t_raise"], [], [], [], &"o_cost"]],
		true, [&"t_raise"])
	var s: Shift = made[0]
	var before := s.action_log.size()
	h.check("it went down", _play(s, made[1]).ok)
	var said := _chatter(s, before)
	h.eq("they said something", said.size(), 1)
	if said.size() == 1:
		h.eq("the objection", said[0]["dialogue"], "\"too much\"")
	h.eq("and it is open", s.chairs[0].objection, &"o_cost")

func test_a_product_over_their_line_draws_something_warm_instead() -> void:
	var made := _objecting([
			["\"too much\"", [&"t_raise"], [], [], [], &"o_cost"],
			["\"nice\"", [&"interested"]]],
		false, [&"t_raise"])
	var s: Shift = made[0]
	var before := s.action_log.size()
	_play(s, made[1])
	var said := _chatter(s, before)
	h.eq("they said something", said.size(), 1)
	if said.size() == 1:
		h.eq("and it was warm", said[0]["dialogue"], "\"nice\"")
	h.eq("nothing to object to", s.chairs[0].objection, &"")

func test_an_open_objection_is_answered_by_the_line_written_for_it() -> void:
	## Every time, not most of the time: this is the one place the library
	## overrides instead of weighting.
	for seed_value in range(1, 13):
		var made := _objecting([
				["\"too much\"", [&"t_raise"], [], [], [], &"o_cost"],
				["\"generic\"", [&"t_mine"]],
				["\"also generic\"", [&"t_mine"]],
				["\"for the cost\"", [&"t_mine"], [], [], [&"o_cost"]],
				["\"they shrug\"", [&"t_reply"]],
				["\"they get it\"", [&"t_reply"], [], [], [&"o_cost"]]],
			true, [&"t_raise"], seed_value)
		var s: Shift = made[0]
		_play(s, made[1])
		var answer := _a_support_card(s, [&"t_mine"])
		answer.dialogue_tags = [&"t_reply"]
		s.hand.append(CardInstance.new(answer, 901))
		var before := s.action_log.size()
		s.play_card(s.hand.size() - 1)
		h.eq("seed %d: you answer the objection" % seed_value,
			s.player_lines[-1], "\"for the cost\"")
		h.eq("seed %d: and so do they" % seed_value,
			s.action_log[before]["dialogue"], "\"they get it\"")

func test_where_nothing_answers_it_the_generic_line_plays() -> void:
	var made := _objecting([
			["\"too much\"", [&"t_raise"], [], [], [], &"o_cost"],
			["\"generic\"", [&"t_mine"]],
			["\"for another\"", [&"t_mine"], [], [], [&"o_other"]]],
		true, [&"t_raise"])
	var s: Shift = made[0]
	_play(s, made[1])
	var answer := _a_support_card(s, [&"t_mine"])
	s.hand.append(CardInstance.new(answer, 901))
	s.play_card(s.hand.size() - 1)
	h.eq("the generic line", s.player_lines[-1], "\"generic\"")

func test_an_answer_can_flush_out_the_real_objection() -> void:
	## "No thanks" -> "is it the payment, or the coverage?" -> "the payment".
	var made := _objecting([
			["\"no thanks\"", [&"t_raise"], [], [], [], &"o_no"],
			["\"the payment?\"", [&"t_mine"], [], [], [&"o_no"]],
			["\"yes, the payment\"", [&"t_reply"], [], [], [&"o_no"], &"o_cost"]],
		true, [&"t_raise"])
	var s: Shift = made[0]
	_play(s, made[1])
	h.eq("they open with no thanks", s.chairs[0].objection, &"o_no")
	var answer := _a_support_card(s, [&"t_mine"])
	answer.dialogue_tags = [&"t_reply"]
	s.hand.append(CardInstance.new(answer, 901))
	s.play_card(s.hand.size() - 1)
	h.eq("and answering it turns it into the real one", s.chairs[0].objection, &"o_cost")

func test_the_objection_goes_with_the_product() -> void:
	var made := _objecting([
			["\"too much\"", [&"t_raise"], [], [], [], &"o_cost"],
			["\"generic\"", [&"t_mine"]],
			["\"for the cost\"", [&"t_mine"], [], [], [&"o_cost"]]],
		true, [&"t_raise"])
	var s: Shift = made[0]
	_play(s, made[1])
	h.check("taken back off the table", s.drop_offer().ok)
	h.eq("nothing is objected to now", s.chairs[0].objection, &"")
	var answer := _a_support_card(s, [&"t_mine"])
	s.hand.append(CardInstance.new(answer, 901))
	s.play_card(s.hand.size() - 1)
	h.eq("so a card says its generic line again", s.player_lines[-1], "\"generic\"")

func test_offering_is_the_trial_close() -> void:
	var made := _objecting([
			["\"too much\"", [&"t_raise"], [], [], [], &"o_cost"],
			["\"shall we?\"", [&"player_close"]],
			["\"the whole year?\"", [&"player_close"], [], [], [&"o_cost"]]],
		true, [&"t_raise"])
	var s: Shift = made[0]
	_play(s, made[1])
	var c: Customer = s.chairs[0]
	c.line = c.offer.appeal          # clears now, so the close sells
	h.check("offered", s.offer().ok)
	h.eq("you closed on the objection they had", s.player_lines[-1], "\"the whole year?\"")
	h.eq("and the sale ends it", c.objection, &"")

func test_with_no_pool_nobody_objects() -> void:
	var s := _voiced_shift(null)
	var product := _a_product(s, [])
	(product as ProductCardDef).objection_tags = [&"t_raise"]
	_at(s).line = 999
	var before := s.action_log.size()
	h.check("it went down", _play(s, product).ok)
	h.eq("nothing said", _chatter(s, before).size(), 0)
	h.eq("nothing open", s.chairs[0].objection, &"")

func test_objecting_never_moves_the_games_own_dice() -> void:
	## Two raises to choose between, so picking one really rolls.
	var rows := [["\"too much\"", [&"t_raise"], [], [], [], &"o_cost"],
		["\"no thanks\"", [&"t_raise"], [], [], [], &"o_no"]]
	var objecting := _objecting(rows, true, [&"t_raise"], 7)
	var silent := _objecting(rows, true, [], 7)
	_play(objecting[0], objecting[1])
	_play(silent[0], silent[1])
	h.check("one objected", (objecting[0] as Shift).chairs[0].objection != &"")
	h.eq("the other did not", (silent[0] as Shift).chairs[0].objection, &"")
	h.eq("and the game's dice are where they would have been",
		(objecting[0] as Shift).rng.state, (silent[0] as Shift).rng.state)
