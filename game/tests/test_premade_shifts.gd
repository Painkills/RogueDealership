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

## `n` archetypes from the pool, whichever it holds, cycling if it holds fewer -
## no test here names one that could be renamed or retired.
func _some(n: int) -> Array:
	var all: Array = (load("res://data/archetype_pool.tres") as ArchetypePool).archetypes
	var out := []
	for i in range(n):
		out.append(all[i % all.size()])
	return out

func _shift(cfg: ShiftConfig, only: Array = [], lineup: Array = [], seats: int = 0,
		excluded: Array = [], unlock_all: bool = false) -> Shift:
	return Shift.new(cfg, load("res://data/interests/interest_pool.tres"),
		load("res://data/card_pool.tres"), load("res://data/archetype_pool.tres"),
		7, [], null, 0, 1, 0, 0, null, seats, 1.0, 1.0, unlock_all, only, lineup, excluded)

func _ids(archetypes: Array) -> Array:
	return archetypes.map(func(a): return a.id)

func test_a_lineup_is_exactly_who_comes_in_and_in_that_order() -> void:
	## "A fixed number of customers coming in a specified order."
	var cfg := _cfg()
	var order: Array = _some(4)
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
	var s := _shift(_cfg(), [], _some(1))
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

func test_a_day_never_goes_without_a_shift() -> void:
	## A calendar day with nothing on it would stop the run dead.
	var pool := _tiers()
	for t in pool.profiles:
		t.from_day = 99
	h.check("misauthored first days give way", not Week.new(pool, 1, 1, 5).offers(1).is_empty())

func test_a_premade_shift_comes_up_once_a_day() -> void:
	## One allowed in every slot still takes only one of them.
	var pool := _tiers()
	pool.categories.append(_category(0, 0, false, [1.0]))
	var dealt := Week.new(pool, 1, 1, 5).offers(1).filter(func(p): return p.is_premade())
	h.eq("once, not in every slot", dealt.size(), 1)

func test_a_boss_takes_the_place_of_one_of_the_days_shifts() -> void:
	## A choice on the calendar, not the whole day.
	var pool := _tiers()
	pool.categories.append(_category(1 << 0, 0, true, [1.0]))
	var week := Week.new(pool, 5, 1)
	var monday := week.offers(1)
	h.eq("Monday still offers a shift per tier", monday.size(), pool.profiles.size())
	var bosses := monday.filter(func(p): return p.is_boss_day())
	h.eq("one of them the boss", bosses.size(), 1)
	var at := monday.find(bosses[0])
	h.eq("worked in the slot of the shift it took the place of",
		bosses[0].worked_at(), pool.profiles[at].worked_at())
	h.eq("and Tuesday is the tiers again", week.offers(2), pool.profiles)
	# Only ever into a slot its category allows - nights, here.
	var nights := _tiers()
	nights.categories.append(_category(0, 1 << 2, true, [1.0]))
	var placed := {}
	for seed_value in range(12):
		for p in Week.new(nights, 1, seed_value).offers(1):
			if p.is_boss_day():
				placed[p.worked_at()] = true
	h.eq("a boss allowed only at night is only ever dealt at night", placed.keys(), [&"night"])

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
