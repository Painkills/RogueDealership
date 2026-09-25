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

func _index_of(s: Shift, id: StringName) -> int:
	for i in range(s.hand.size()):
		if s.hand[i].card.id == id:
			return i
	return -1

func test_the_practice_floor_has_one_chair_and_one_easy_customer() -> void:
	var s := _shift()
	h.eq("one chair, so nothing else on the floor competes for the lesson",
		s.chairs.size(), 1)
	var c = s.chairs[0]
	h.check("and somebody sitting in it", c != null)
	if c == null:
		return
	h.eq("an easygoing buyer", c.archetype.id, Tutorial.ARCHETYPE)
	h.check("who has no actions of their own to interrupt a beginner",
		c.archetype.actions.is_empty())
	h.eq("with a name, not a random one", c.display_name, Tutorial.CUSTOMER_NAME)
	h.eq("at full patience", c.patience, c.max_patience)
	h.check("with their Line shown, for once, so the meter has a mark to aim at",
		c.known_line)
	h.eq("on a clock long enough never to be the lesson", s.tick_budget, Tutorial.TICKS)
	h.eq("and no quota, because practice has nothing to make", s.quota, 0)

func test_the_hand_is_dealt_for_the_lesson() -> void:
	var s := _shift()
	var ids: Array = []
	for inst in s.hand:
		ids.append(inst.card.id)
	h.eq("the scripted hand, left to right", ids, Tutorial.HAND)
	var uids := {}
	for inst in s.hand + s.draw:
		uids[inst.uid] = true
	h.eq("dealt from the deck, not conjured - no card twice",
		uids.size(), s.hand.size() + s.draw.size())
	h.eq("and none missing: it is exactly the starter deck",
		uids.size(), Deck.build_starting(_cards()).cards.size())

func test_one_support_card_tips_whichever_product_they_put_down() -> void:
	## The coach asks for ONE support card between placing and offering. That
	## has to hold whichever product the player happens to pick up.
	for product in [&"vsc", &"gap"]:
		var s := _shift()
		s.approach(0)
		var c: Customer = s.chairs[0]
		h.check("%s goes on the table" % product, s.place(_index_of(s, product)).ok)
		h.check("and the Line tunes to it", Tutorial.tune_line(c))
		h.check("leaving %s just short of their Line (%d < %d)"
			% [product, c.offer.appeal, c.line], c.offer.appeal < c.line)
		h.check("Explain the Product plays", s.play_card(_index_of(s, &"explain")).ok)
		h.check("and one Explain clears it (%d >= %d)" % [c.offer.appeal, c.line],
			c.offer.appeal >= c.line)
		var r := s.offer()
		h.check("so the offer sells", r.ok and not c.unsigned.is_empty())

func test_the_first_meter_anyone_sees_has_something_in_it() -> void:
	## Left to the shuffle, a product they rank last opens at 0 Appeal - an
	## empty bar with the Line's mark jammed against its start, found the first
	## time the lesson was played through in a browser.
	var s := _shift()
	var c: Customer = s.chairs[0]
	var ranks_seen := {}
	for iid in c.ranks:
		ranks_seen[int(c.ranks[iid])] = true
	h.eq("their list is still a list - every rank used once", ranks_seen.size(), c.ranks.size())
	for product in Tutorial.RANKS:
		var def := _cards().by_id(product) as ProductCardDef
		var appeal: int = c.appeal_for(def.interest.id)
		h.check("%s opens with a real Appeal to show (%d)" % [product, appeal], appeal >= 20)

func test_tuning_needs_something_on_the_table() -> void:
	var s := _shift()
	var c: Customer = s.chairs[0]
	var before: int = c.line
	h.check("nothing to tune with an empty table", not Tutorial.tune_line(c))
	h.eq("so their Line is left alone", c.line, before)

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
