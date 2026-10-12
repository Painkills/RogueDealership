extends RefCounted
## The practice shift's table setting - see scripts/run/tutorial.gd. The lesson
## itself is driven live, step by step, in tools/drive_tutorial.gd.
var h: Harness

func _cards() -> CardPool:
	return load("res://data/card_pool.tres")

func _shift() -> Shift:
	return Tutorial.build_shift(load("res://data/shift_config.tres"),
		load("res://data/interests/interest_pool.tres"), _cards(),
		load("res://data/archetype_pool.tres"))

func test_the_practice_floor_has_one_chair_and_one_easy_customer() -> void:
	var s := _shift()
	h.eq("one chair, so nothing else on the floor competes for the lesson",
		s.chairs.size(), 1)
	var c = s.chairs[0]
	h.check("and somebody sitting in it", c != null)
	if c == null:
		return
	h.eq("an easygoing buyer", c.archetype.id, Tutorial.ARCHETYPE)
	h.eq("with a name, not a random one", c.display_name, Tutorial.CUSTOMER_NAME)
	var walked_up: Array = s.events.filter(func(e): return e.contains("walks up"))
	h.check("and the log says the same name walked up (%s)" % ", ".join(walked_up),
		not walked_up.is_empty() and walked_up.all(
			func(e): return e.contains(Tutorial.CUSTOMER_NAME)))
	h.eq("at full patience", c.patience, c.max_patience)
	h.check("with their Line shown, for once, so the meter has a mark to aim at",
		c.known_line)
	h.eq("on a clock long enough never to be the lesson", s.tick_budget, Tutorial.TICKS)
	h.eq("and no quota, because practice has nothing to make", s.quota, 0)
	# Last, since it runs the practice clock out: whatever their kind asks for
	# on the floor, they ask for nothing while you learn.
	var asked := false
	for _i in range(Tutorial.TICKS):
		if s.is_over() or s.chairs[0] == null:
			break
		s._burn(1, "wait")
		asked = asked or (s.chairs[0] != null and s.chairs[0].demand != null)
	h.check("and nothing they ask for interrupts a beginner", not asked)

func test_practice_teaches_ranks_with_one_product_to_drop_and_one_to_sell() -> void:
	## "The tutorial needs to explain how appeal and interest rankings work, and
	## how you can drop a product if it's too low."
	var s := _shift()
	var c: Customer = s.chairs[0]
	var low := _cards().by_id(Tutorial.LOW) as ProductCardDef
	var high := _cards().by_id(Tutorial.HIGH) as ProductCardDef
	h.check("both are in the opening hand", s.hand.any(func(i): return i.card == low)
		and s.hand.any(func(i): return i.card == high))
	h.check("the one to drop ranks lower than the one to sell",
		int(c.ranks[low.interest.id]) > int(c.ranks[high.interest.id]))
	var step: int = int(s.cfg.appeal_step)
	# Put down first, the low one: more than a support card's worth short.
	s.place(_hand_index(s, Tutorial.LOW))
	h.check("the low one opens a long way under their Line (%d of %d)"
		% [c.offer.appeal, c.line], c.line - c.offer.appeal > step)
	Tutorial.tune_line(c)
	h.check("and the Line is left there for it", c.line - c.offer.appeal > step)
	var tick := s.tick
	h.check("taking it back works", s.drop_offer().ok and c.offer == null)
	h.eq("and is free", s.tick, tick)
	s.place(_hand_index(s, Tutorial.HIGH))
	Tutorial.tune_line(c)
	h.eq("the high one is one short support card away", c.line - c.offer.appeal,
		Tutorial.LINE_GAP)

func _hand_index(s: Shift, id: StringName) -> int:
	for i in range(s.hand.size()):
		if s.hand[i].card.id == id:
			return i
	return -1

func test_practice_never_touches_the_run() -> void:
	## Built from the run's pools but never its deck: nothing done in practice
	## - no card dug, no product sold - is something the run carries forward.
	var run := RunState.new(load("res://data/shift_config.tres"),
		load("res://data/interests/interest_pool.tres"), _cards(),
		load("res://data/archetype_pool.tres"), 11)
	var deck_before: Array = run.deck.cards.duplicate()
	var s := Tutorial.build_shift(run.cfg, run.interests, run.card_pool, run.archetypes)
	s.approach(0)
	s.dig(0)
	h.eq("the run's own deck is untouched", run.deck.cards, deck_before)
	h.check("and none of the practice cards IS a run card",
		not run.deck.cards.has(s.hand[0]))
	# The config is a shared, cached Resource: tuning it in place for practice
	# would quietly give every real shift afterwards a 30-tick clock and no
	# quota.
	h.check("practice runs on its own copy of the config", s.cfg != run.cfg)
	h.check("and the run's own still has a quota to make", run.cfg.quota > 0)
	h.check("and its own clock", run.cfg.shift_ticks != Tutorial.TICKS)
	h.eq("still on shift 1", run.shift_number, 1)
