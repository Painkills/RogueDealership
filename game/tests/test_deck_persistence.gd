extends RefCounted
## The invariant the whole run layer rests on: a deck survives a shift.
##
## CardInstance.new is called only from Deck.add, and nothing in Shift ever
## creates or destroys one - a shift only borrows references into draw, hand and
## discard. So the run's deck needs no reconstitution step after a shift. That is
## load-bearing, it is true today by accident rather than by design, and nothing
## tested it.
var h: Harness

func _cfg() -> ShiftConfig:
	return load("res://data/shift_config.tres")

func _pool() -> CardPool:
	return load("res://data/card_pool.tres")

func _shift(deck: Deck) -> Shift:
	return Shift.new(_cfg(), load("res://data/interests/interest_pool.tres"),
		_pool(), load("res://data/archetype_pool.tres"), 7, [], deck)

func test_an_injected_deck_is_the_one_the_shift_deals_from() -> void:
	var deck := Deck.build_starting(_pool())
	var uids := {}
	for c in deck.cards:
		uids[c.uid] = true
	var s := _shift(deck)
	h.check("the shift dealt a hand", not s.hand.is_empty())
	for c in s.hand:
		h.check("hand card %d came from the injected deck" % c.uid, uids.has(c.uid))
	for c in s.draw:
		h.check("draw card %d came from the injected deck" % c.uid, uids.has(c.uid))

func test_a_shift_with_no_deck_still_builds_its_own() -> void:
	## The default that keeps every existing caller working.
	var s := Shift.new(_cfg(), load("res://data/interests/interest_pool.tres"),
		_pool(), load("res://data/archetype_pool.tres"), 7)
	h.check("it dealt a hand anyway", not s.hand.is_empty())

func test_a_deck_comes_out_of_a_shift_exactly_as_it_went_in() -> void:
	var deck := Deck.build_starting(_pool())
	var before: int = deck.cards.size()
	var uids_before: Array[int] = []
	for c in deck.cards:
		uids_before.append(c.uid)

	var s := _shift(deck)
	# Burn the clock down. dig is the one command that needs no customer, and
	# wait covers the stretches where the floor has emptied out.
	var guard := 0
	while not s.is_over() and guard < 500:
		guard += 1
		if not s.hand.is_empty():
			s.dig(0)
		elif s.seated().is_empty():
			s.wait()
		else:
			break
	h.check("the shift actually ran out (tick %d of %d)" % [s.tick, s.tick_budget],
		s.is_over())

	h.eq("the deck still holds every card", deck.cards.size(), before)
	var uids_after: Array[int] = []
	for c in deck.cards:
		uids_after.append(c.uid)
	h.eq("with the same uids in the same order", uids_after, uids_before)

func test_an_injected_quota_overrides_the_config() -> void:
	var deck := Deck.build_starting(_pool())
	var s := Shift.new(_cfg(), load("res://data/interests/interest_pool.tres"),
		_pool(), load("res://data/archetype_pool.tres"), 7, [], deck, 4140)
	h.eq("the shift runs to the quota it was given", s.quota, 4140)
	h.eq("and the report says the same", int(s.report()["quota"]), 4140)
