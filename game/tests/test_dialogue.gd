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
	s.play_card(0)
	h.eq("one new entry", s.action_log.size(), 1)
	var entry: Dictionary = s.action_log[0]
	for key in ["key", "customer", "name", "dialogue", "descriptions", "floor_wide"]:
		h.check("entry carries %s" % key, entry.has(key))
	h.eq("named for the card", entry["name"], "Explain the Product")

func test_the_customer_says_something_back() -> void:
	var s := _shift([&"karen"])
	var c := _at(s)
	c.line = 0
	_hand(s, [&"vsc", &"explain"])
	s.place(0)
	s.play_card(0)
	var said: String = s.action_log[0]["dialogue"]
	h.check("something was said", said != "")
	h.check("in the house voice - a quoted sentence", said.begins_with("\""))

func test_a_karen_gets_a_karen_line() -> void:
	var s := _shift([&"karen"])
	var c := _at(s)
	c.line = 0
	_hand(s, [&"vsc", &"explain"])
	s.place(0)
	s.play_card(0)
	var said: String = s.action_log[0]["dialogue"]
	var band := StringName(s.band_for(c.line - c.offer.appeal))
	var eligible: Array[String] = []
	for l in _pool().candidates([&"appeal"], c.archetype.id, c.offer.product.id, band):
		eligible.append(l.text)
	h.check("the line said is one the karen actually qualifies for (got: %s)" % said,
		eligible.has(said))

func test_an_untagged_card_is_logged_but_silent() -> void:
	var s := _shift([&"easygoing"])
	_at(s)
	_hand(s, [&"readroom"])
	s.play_card(0)
	h.eq("one entry", s.action_log.size(), 1)
	h.eq("but nothing said - readroom carries no dialogue_tags",
		s.action_log[0]["dialogue"], "")

func test_a_shift_with_no_dialogue_pool_still_logs_every_card() -> void:
	var cfg: ShiftConfig = (load("res://data/shift_config.tres") as ShiftConfig).duplicate()
	cfg.patience_jitter = 0
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
	s.play_card(0)
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
		s.play_card(0)        # +4 appeal -> gap 21 - COOL, after
		var said: String = s.action_log[0]["dialogue"]
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
