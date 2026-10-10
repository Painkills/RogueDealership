extends RefCounted
## A run saved and picked up again lands exactly where it was: the day's
## snapshot, then every move since played back from the same seed. Played by a
## made-up player who taps at random - refusals and all - so nothing here
## depends on what any card, customer or shift happens to be.
var h: Harness

func _run(seed_value: int) -> RunState:
	return RunState.new(load("res://data/shift_config.tres"),
		load("res://data/interests/interest_pool.tres"),
		load("res://data/card_pool.tres"),
		load("res://data/archetype_pool.tres"), seed_value,
		load("res://data/dialogue/dialogue_pool.tres"),
		load("res://data/shift_profile_pool.tres"),
		load("res://data/dealership_upgrades/upgrade_pool.tres"))

## `n` taps at random, the way a hand on a phone might make them - including
## the ones the rules refuse.
func _tap_about(s: Shift, taps: RandomNumberGenerator, n: int) -> void:
	for _i in range(n):
		if s.is_over():
			return
		if s.pending_pull != null:
			if taps.randi_range(0, 1) == 0:
				s.choose_pull(0)
			else:
				s.cancel_pull()
			continue
		if s.seated().is_empty():
			s.wait()
			continue
		var card := taps.randi_range(0, maxi(0, s.hand.size() - 1))
		var chair := taps.randi_range(0, s.chairs.size() - 1)
		match taps.randi_range(0, 8):
			0: s.approach(chair)
			1, 2: s.play_card(card)
			3: s.play_card(card, chair)
			4: s.offer()
			5: s.close()
			6: s.dig(card)
			7: s.leave()
			8: s.drop_offer()

## Digs the clock away - no way to fail - to reach the end of a shift.
func _run_out_the_clock(s: Shift) -> void:
	var guard := 0
	while not s.is_over() and guard < 1000:
		guard += 1
		if s.pending_pull != null:
			s.cancel_pull()
		elif s.seated().is_empty():
			s.wait()
		elif not s.hand.is_empty():
			s.dig(0)
		else:
			s.leave()
			s.wait()

## The save as it would come back off disk.
func _off_disk(save: RunSave) -> RunSave:
	return RunSave.from_dict(str_to_var(var_to_str(save.to_dict())))

## Starts today on `run`: its save, and the shift picked from today's offers.
## [save, shift].
func _pick_a_shift(run: RunState, history: Array, taps: RandomNumberGenerator) -> Array:
	var save := RunSave.start_of_day(run, history)
	var offers := run.todays_shifts()
	var profile: ShiftProfile = offers[taps.randi_range(0, offers.size() - 1)]
	save.picked(run, profile)
	var shift := run.start_shift(profile)
	save.shift_commands = shift.commands
	return [save, shift, profile]

func test_a_run_saved_mid_shift_comes_back_exactly() -> void:
	var taps := RandomNumberGenerator.new()
	taps.seed = 11
	var run := _run(4242)
	var picked := _pick_a_shift(run, [], taps)
	var save: RunSave = picked[0]
	var shift: Shift = picked[1]
	_tap_about(shift, taps, 40)
	save.fingerprint = RunSave.fingerprint_of(run, shift, null)
	var back := _off_disk(save).resume(_run(save.seed_value()))
	h.check("it says it landed where it was", back["ok"])
	var again: Shift = back["shift"]
	h.check("on a shift of its own", again != null and again != shift)
	h.eq("at the same tick", again.tick, shift.tick)
	h.eq("with the same money banked", again.margin_banked, shift.margin_banked)
	h.eq("the same hand", again.hand.map(func(i): return i.uid),
		shift.hand.map(func(i): return i.uid))
	h.eq("standing with the same customer", again.at, shift.at)
	h.eq("the same log, line for line", again.events, shift.events)
	h.eq("and every move on record to play back again", again.commands.size(),
		shift.commands.size())

func test_a_run_saved_in_the_store_comes_back_exactly() -> void:
	var taps := RandomNumberGenerator.new()
	taps.seed = 12
	var run := _run(777)
	var picked := _pick_a_shift(run, [], taps)
	var save: RunSave = picked[0]
	var shift: Shift = picked[1]
	_tap_about(shift, taps, 30)
	_run_out_the_clock(shift)
	run.finish_shift(shift.report())
	var shop := Shop.new(run, picked[2])
	save.shop_open = true
	save.shop_commands = shop.commands
	shop.add_money_for_testing(50000)
	if not shop.free_cards.is_empty():
		shop.take_free(shop.free_cards[0])
	if not shop.offers.is_empty():
		shop.buy(shop.offers[0])
	if not shop.upgrade_offers.is_empty():
		shop.upgrade(shop.upgrade_offers[0])
	shop.remove(run.deck.cards[0].uid)
	save.fingerprint = RunSave.fingerprint_of(run, shift, shop)
	var fresh := _run(save.seed_value())
	var back := _off_disk(save).resume(fresh)
	h.check("it says it landed where it was", back["ok"])
	h.check("with the store open", back["shop"] != null)
	h.eq("the same money left", fresh.money, run.money)
	h.eq("the same toolkit, card for card", fresh.deck.snapshot(), run.deck.snapshot())
	h.eq("and the shift worked in its history", (back["history"] as Array).size(), 1)

func test_day_after_day_plays_back_from_each_days_start() -> void:
	var taps := RandomNumberGenerator.new()
	taps.seed = 13
	var run := _run(31337)
	var history: Array = []
	for _day in range(3):
		if run.is_over():
			break
		var picked := _pick_a_shift(run, history, taps)
		var save: RunSave = picked[0]
		var shift: Shift = picked[1]
		# The testing shortcuts, so the run lives to see three days whatever the
		# taps do - and so they are played back too.
		shift.skip_for_testing()
		shift.give_standing_for_testing(1)
		_tap_about(shift, taps, 60)
		_run_out_the_clock(shift)
		var report := shift.report()
		history.append({"profile": picked[2], "report": report})
		run.finish_shift(report)
		if run.is_over():
			break
		var shop := Shop.new(run, picked[2])
		save.shop_open = true
		save.shop_commands = shop.commands
		if not shop.dealership_offers.is_empty():
			shop.take_dealership_upgrade(shop.dealership_offers[0])
		if not shop.free_cards.is_empty():
			shop.take_free(shop.free_cards[taps.randi_range(0, shop.free_cards.size() - 1)])
		save.fingerprint = RunSave.fingerprint_of(run, shift, shop)
		var fresh := _run(save.seed_value())
		var back := _off_disk(save).resume(fresh)
		h.check("day %d plays back from its own start" % run.reports.size(), back["ok"])
		h.eq("onto the same day", fresh.shift_number, run.shift_number)
		h.eq("with the same money", fresh.money, run.money)
		h.eq("the same standing", fresh.standing, run.standing)
		h.eq("the same perks", fresh.dealership, run.dealership)
		h.eq("and the same days behind it", (back["history"] as Array).size(),
			history.size())
	h.eq("three days played back, one after another", run.reports.size(), 3)

func test_moves_that_play_out_differently_are_caught() -> void:
	var taps := RandomNumberGenerator.new()
	taps.seed = 14
	var run := _run(99)
	var picked := _pick_a_shift(run, [], taps)
	var save: RunSave = picked[0]
	_tap_about(picked[1], taps, 30)
	save.fingerprint = RunSave.fingerprint_of(run, picked[1], null)
	# What a build that dealt the day differently would find: the same moves,
	# other dice.
	save.checkpoint["rng_state"] = int(save.checkpoint["rng_state"]) + 1
	h.check("a day that plays out differently says so",
		not save.resume(_run(save.seed_value()))["ok"])

func test_a_day_started_over_is_back_on_its_calendar() -> void:
	var taps := RandomNumberGenerator.new()
	taps.seed = 15
	var run := _run(5)
	var day_start := run.snapshot()
	var picked := _pick_a_shift(run, [], taps)
	var save: RunSave = picked[0]
	_tap_about(picked[1], taps, 20)
	save.restart_day()
	var fresh := _run(save.seed_value())
	var back := save.resume(fresh, false)
	h.check("with nothing picked", back["shift"] == null and back["shop"] == null
		and not save.has_pick())
	h.eq("and the run as the day found it", fresh.snapshot(), day_start)

func test_only_a_save_this_version_wrote_is_read() -> void:
	h.check("nothing at all", RunSave.from_dict(null) == null)
	h.check("another version's", RunSave.from_dict({"version": RunSave.VERSION + 1,
		"checkpoint": {"seed": 1}}) == null)
	h.check("one with no day in it", RunSave.from_dict({"version": RunSave.VERSION}) == null)

func test_a_deck_comes_back_card_for_card() -> void:
	var pool: CardPool = load("res://data/card_pool.tres")
	var deck := Deck.build_starting(pool)
	deck.upgrade(deck.cards[1].uid)
	deck.remove(deck.cards[0].uid)
	var back := Deck.from_snapshot(str_to_var(var_to_str(deck.snapshot())), pool)
	h.eq("the same cards, uids and upgrades", back.snapshot(), deck.snapshot())
	h.eq("and the next card added gets the uid it would have",
		back.add(pool.cards[0]).uid, deck.add(pool.cards[0]).uid)

func test_a_card_this_build_no_longer_has_is_left_out() -> void:
	var made_up := SupportCardDef.new()
	made_up.id = &"made_up_card"
	var gone := SupportCardDef.new()
	gone.id = &"gone_card"
	var now := CardPool.new()
	now.cards = [made_up]
	var deck := Deck.new()
	deck.add(made_up)
	deck.add(gone)
	var back := Deck.from_snapshot(deck.snapshot(), now)
	h.eq("only the card that is still there", back.cards.size(), 1)
	h.eq("which is it", back.cards[0].card, made_up)
