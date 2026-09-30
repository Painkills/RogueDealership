extends RefCounted
## Premade shifts: a ShiftProfile's own say over who comes in and how the day
## runs, and the categories that deal them onto the week's calendar (Week).
## Built from made-up pools, never data/shift_categories - what ships there is
## David's to change, and these check the rules rather than the examples.
var h: Harness

func _cfg() -> ShiftConfig:
	var cfg: ShiftConfig = (load("res://data/shift_config.tres") as ShiftConfig).duplicate()
	cfg.patience_jitter = 0
	cfg.action_cadence_jitter_ticks = 0
	cfg.arrival_patience_min_fraction = 1.0
	cfg.walk_up_ticks_min = 1
	cfg.walk_up_ticks_max = 1
	cfg.shift_ticks = 99
	return cfg

func _arch(id: StringName) -> CustomerArchetype:
	return (load("res://data/archetype_pool.tres") as ArchetypePool).by_id(id)

func _shift(cfg: ShiftConfig, only: Array = [], lineup: Array = [], seats: int = 0) -> Shift:
	return Shift.new(cfg, load("res://data/interests/interest_pool.tres"),
		load("res://data/card_pool.tres"), load("res://data/archetype_pool.tres"),
		7, [], null, 0, 1, 0, 0, null, seats, 1.0, 1.0, false, only, lineup)

func _ids(archetypes: Array) -> Array:
	return archetypes.map(func(a): return a.id)

# ------------------------------------------------------------ who comes in
func test_only_archetypes_is_everyone_who_comes_in() -> void:
	## "A shift that has only Karens" - on the first day of the run, too, which
	## the usual ladder would never allow.
	var cfg := _cfg()
	var karen := _arch(&"karen")
	var s := _shift(cfg, [karen])
	for c in s.seated():
		c.patience = 999
	s._burn(cfg.waiting_max, "cards")
	var seen: Array = s.seated().map(func(c): return c.archetype)
	seen.append_array(s.waiting)
	h.check("the floor and the waiting list filled up (%d)" % seen.size(),
		seen.size() > s.chairs.size())
	h.check("with nobody but the archetype the shift names (%s)" % ", ".join(_ids(seen)),
		seen.all(func(a): return a == karen))

func test_a_lineup_is_exactly_who_comes_in_and_in_that_order() -> void:
	## "A fixed number of customers coming in a specified order."
	var cfg := _cfg()
	var order: Array = [_arch(&"easygoing"), _arch(&"laydown"), _arch(&"family"),
		_arch(&"tech")]
	cfg.waiting_max = order.size()
	var s := _shift(cfg, [], order, 2)
	h.eq("the first of them take the seats, in order",
		_ids(s.chairs.map(func(c): return c.archetype)), _ids(order.slice(0, 2)))
	for c in s.seated():
		c.patience = 999
	s._burn(order.size(), "cards")
	h.eq("the rest come in after them, in order", _ids(s.waiting), _ids(order.slice(2)))
	h.check("and then nobody is due", s.door_closed() and s.next_arrival_in() == -1)
	s._burn(10, "cards")
	h.eq("however long the day runs", s.waiting.size(), order.size() - 2)

func test_a_short_lineup_leaves_chairs_empty_and_the_day_ends_with_them() -> void:
	var s := _shift(_cfg(), [], [_arch(&"easygoing")])
	h.eq("one customer, one chair taken", s.seated().size(), 1)
	s.chairs[0].patience = 0
	s._settle_patience()
	h.check("once they are gone nobody else is coming",
		s.seated().is_empty() and s.door_closed())
	var res := s.wait()
	h.check("so waiting runs out the day (%s)" % res.msg, res.ok and s.is_over())

# ------------------------------------------------------------ its numbers
func test_a_premade_shifts_own_numbers_reach_the_shift() -> void:
	var run := RunState.new(load("res://data/shift_config.tres"),
		load("res://data/interests/interest_pool.tres"),
		load("res://data/card_pool.tres"),
		load("res://data/archetype_pool.tres"), 7)
	var p := ShiftProfile.new()
	p.shift_ticks = run.cfg.shift_ticks + 5
	p.quota = run.quota_for(1) + 1000
	p.seats = 1
	p.waiting_room = run.cfg.waiting_max + 2
	var s := run.start_shift(p)
	h.eq("its ticks", s.tick_budget, p.shift_ticks)
	h.eq("its quota", s.quota, p.quota)
	h.eq("its seats", s.chairs.size(), 1)
	h.eq("its waiting room", s.cfg.waiting_max, p.waiting_room)
	h.check("and the run's own config is untouched",
		run.cfg.shift_ticks != p.shift_ticks and run.cfg.waiting_max != p.waiting_room)

# ------------------------------------------------------------ the week
## Three blank tiers in the regular slots' order, and no categories yet.
func _tiers() -> ShiftProfilePool:
	var pool := ShiftProfilePool.new()
	var tiers: Array[ShiftProfile] = []
	for id in ShiftCategory.SLOTS:
		var t := ShiftProfile.new()
		t.id = id
		tiers.append(t)
	pool.profiles = tiers
	return pool

## A category of made-up premade shifts, one per chance given.
func _category(days: int, slots: int, boss: bool, chances: Array) -> ShiftCategory:
	var c := ShiftCategory.new()
	c.days = days
	c.slots = slots
	c.boss_day = boss
	for i in range(chances.size()):
		var p := ShiftProfile.new()
		p.id = StringName("premade_%d" % i)
		p.chance = chances[i]
		c.shifts.append(p)
	return c

func test_a_category_deals_only_on_its_days_and_into_its_slots() -> void:
	## "These only show up at night" - on Fridays, here.
	var pool := _tiers()
	pool.categories.append(_category(1 << 4, 1 << 2, false, [1.0]))
	var week := Week.new(pool, 7, 1)
	for day in range(1, 8):
		var offers := week.offers(day)
		h.eq("day %d keeps a shift per tier" % day, offers.size(), pool.profiles.size())
		for i in range(offers.size()):
			var slot: StringName = pool.profiles[i].id
			var should := day == 5 and slot == &"night"
			h.check("day %d, %s: %s" % [day, slot, "premade" if should else "the tier"],
				offers[i].is_premade() == should)
	h.eq("worked in the slot it took", week.offers(5)[2].worked_at(), &"night")

func test_a_boss_day_is_the_days_only_shift() -> void:
	var pool := _tiers()
	pool.categories.append(_category(1 << 0, 0, true, [1.0]))
	var week := Week.new(pool, 5, 1)
	var monday := week.offers(1)
	h.check("Monday is the boss's alone", monday.size() == 1 and monday[0].is_boss_day())
	h.check("worked in one of the tiers' slots (%s)" % monday[0].worked_at(),
		ShiftCategory.SLOTS.has(monday[0].worked_at()))
	h.eq("and Tuesday is the tiers again", week.offers(2), pool.profiles)

func test_chance_is_how_often_a_premade_shift_beats_the_regular_one() -> void:
	## Never at 0, always at 1, sometimes each way between - over a sweep of
	## seeds rather than any one. Past 1 in total, the tier never comes up.
	var dealt := {}
	for chances in [[0.0], [0.5], [1.0], [0.8, 0.8]]:
		var pool := _tiers()
		pool.categories.append(_category(0, 1 << 0, false, chances))
		var n := 0
		for seed_value in range(40):
			if Week.new(pool, 1, seed_value).offers(1)[0].is_premade():
				n += 1
		dealt[str(chances)] = n
	h.eq("0 never", dealt["[0.0]"], 0)
	h.eq("1 always", dealt["[1.0]"], 40)
	h.check("in between, sometimes each way (%d of 40)" % dealt["[0.5]"],
		dealt["[0.5]"] > 0 and dealt["[0.5]"] < 40)
	h.eq("past 1 between them, the tier never", dealt["[0.8, 0.8]"], 40)

func test_a_run_deals_its_week_once_from_its_own_seed() -> void:
	## The calendar is reopened after the shop, the tutorial and the toolkit -
	## it has to show the same day every time, and the same week for a seed.
	var pool := _tiers()
	pool.categories.append(_category(0, 0, false, [0.3, 0.3]))
	var runs: Array[RunState] = []
	for _i in range(2):
		runs.append(RunState.new(load("res://data/shift_config.tres"),
			load("res://data/interests/interest_pool.tres"),
			load("res://data/card_pool.tres"),
			load("res://data/archetype_pool.tres"), 11, null, pool))
	var a: RunState = runs[0]
	h.eq("asking twice deals nothing new", a.todays_shifts(), a.todays_shifts())
	for day in range(1, a.cfg.shifts_in_run + 1):
		h.eq("day %d is the same week from the same seed" % day,
			a.week.offers(day).map(func(p): return p.id),
			runs[1].week.offers(day).map(func(p): return p.id))
