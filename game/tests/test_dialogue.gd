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

## One result for the whole library, listing every line that is broken: a typo
## in a tag, an objection or an id is a line that quietly never plays, and this
## is what says so. Aggregated so the count of checks does not grow with the
## number of lines written.
func test_every_line_is_well_formed() -> void:
	var pool := _pool()
	var archetypes: ArchetypePool = load("res://data/archetype_pool.tres")
	var cards: CardPool = load("res://data/card_pool.tres")
	var bands := _valid_bands(_shift([&"easygoing"]))
	var broken: Array[String] = []
	for l in pool.lines:
		var who := l.text.substr(0, 30)
		if l.text.strip_edges() == "":
			broken.append("a line with no words")
		if l.tags.is_empty():
			broken.append("%s has no tag" % who)
		for t in l.tags:
			if not pool.known_tags.has(t):
				broken.append("%s uses undeclared tag %s" % [who, t])
		for a in l.archetype_ids:
			if archetypes.by_id(a) == null:
				broken.append("%s names no real archetype %s" % [who, a])
		for p in l.product_ids:
			if not (cards.by_id(p) is ProductCardDef):
				broken.append("%s names no real product %s" % [who, p])
		for b in l.appeal_bands:
			if not bands.has(b):
				broken.append("%s names no real band %s" % [who, b])
		for o in l.objection_ids:
			if not pool.known_objections.has(o):
				broken.append("%s answers undeclared objection %s" % [who, o])
		if l.becomes != &"" and not pool.known_objections.has(l.becomes):
			broken.append("%s opens undeclared objection %s" % [who, l.becomes])
	h.check("every line is well formed (%s)" % ", ".join(broken), broken.is_empty())

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

func test_a_shift_with_no_dialogue_pool_still_logs_every_card() -> void:
	var cfg: ShiftConfig = (load("res://data/shift_config.tres") as ShiftConfig).duplicate()
	cfg.patience_jitter = 0
	cfg.action_cadence_jitter_ticks = 0
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

func test_speaking_never_moves_the_games_own_random_stream() -> void:
	# Everybody's words come from the voice's own stream. So the same shift
	# played the same way, with a library to speak from and without one, must
	# leave the game's dice in exactly the same place - adding lines (or a
	# library at all) never changes who walks in next or what they want.
	var talking := _shift([&"karen", &"hawk", &"easygoing"])
	var quiet := _shift([&"karen", &"hawk", &"easygoing"])
	quiet.dialogue = null
	var spoke := 0
	for s in [talking, quiet]:
		for step in range(60):
			if s.is_over():
				break
			s.approach(step % s.chairs.size())
			for i in range(s.hand.size()):
				if s.hand[i].is_product():
					s.place(i)
					break
			for i in range(s.hand.size()):
				if not s.hand[i].is_product():
					s.play_card(i)
					break
			s.offer()
			if step % 3 == 0:
				s.drop_offer()
		if s == talking:
			for entry in s.action_log:
				if str(entry.get("dialogue", "")) != "":
					spoke += 1
	h.check("they did speak, so the comparison means something", spoke > 0)
	h.eq("the same clock", talking.tick, quiet.tick)
	h.eq("the game's dice are where they were without any speech",
		talking.rng.state, quiet.rng.state)

# ------------------------------------------------- what they say on their own
## Every line the shift says on its own, not as the voice of a card, an action
## or a demand - taking a product, running short of patience.
func _chatter(s: Shift, from: int = 0) -> Array:
	return s.action_log.slice(from).filter(func(e): return bool(e.get("chatter", false)))

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

func test_a_speaker_steers_clear_of_what_they_just_said() -> void:
	var pool := _lines([["\"one\"", [&"t"]], ["\"two\"", [&"t"]], ["\"three\"", [&"t"]]])
	var rng := RandomNumberGenerator.new()
	for seed_value in range(1, 13):
		rng.seed = seed_value
		h.eq("seed %d says the one thing not said lately" % seed_value,
			pool.pick(rng, [&"t"], &"", &"", &"", &"", ["\"one\"", "\"two\""]), "\"three\"")
	h.check("and with nothing else left, a repeat beats silence",
		pool.pick(rng, [&"t"], &"", &"", &"", &"", ["\"one\"", "\"two\"", "\"three\""]) != "")

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

# -------------------------------------------------------------- objections
# A product under their Line draws an objection, the method's techniques answer
# it, and offering closes on it. The library's own rules are checked against
# the shipped library; the behaviour against made-up lines and copies of
# whatever cards the pool holds.

func test_every_products_objection_tags_are_declared() -> void:
	var pool := _pool()
	var cards: CardPool = load("res://data/card_pool.tres")
	for c in cards.cards:
		if c is ProductCardDef:
			for t in (c as ProductCardDef).objection_tags:
				h.check("%s objects only from a declared tag (%s)" % [c.id, t],
					pool.known_tags.has(t))

## A shift with `rows` for a library, its chair-0 customer's Line put where
## `under` says, and a copy of a product that objects from `raise_tags`.
func _objecting(rows: Array, under: bool, raise_tags: Array[StringName],
		seed_value: int = 1) -> Array:
	var s := _voiced_shift(_lines(rows), seed_value)
	var product := _a_product(s, [])
	(product as ProductCardDef).objection_tags = raise_tags
	_at(s).line = 999 if under else 0
	return [s, product]

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

func test_with_no_pool_nobody_objects() -> void:
	var s := _voiced_shift(null)
	var product := _a_product(s, [])
	(product as ProductCardDef).objection_tags = [&"t_raise"]
	_at(s).line = 999
	var before := s.action_log.size()
	h.check("it went down", _play(s, product).ok)
	h.eq("nothing said", _chatter(s, before).size(), 0)
	h.eq("nothing open", s.chairs[0].objection, &"")
