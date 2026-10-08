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
		excluded: Array = []) -> Shift:
	return Shift.new(cfg, load("res://data/interests/interest_pool.tres"),
		load("res://data/card_pool.tres"), load("res://data/archetype_pool.tres"),
		7, [], null, 0, 1, 0, 0, null, seats, 1.0, 1.0, only, lineup, excluded)

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

func test_a_boss_that_takes_the_day_is_the_only_thing_offered() -> void:
	var pool := _tiers()
	var solo := _category(1 << 0, 0, true, [1.0])
	solo.takes_the_day = true
	pool.categories.append(solo)
	var week := Week.new(pool, 5, 1)
	var monday := week.offers(1)
	h.eq("one shift on the calendar", monday.size(), 1)
	h.check("and it is the boss", monday[0].is_boss_day())
	h.eq("Tuesday is the tiers again", week.offers(2), pool.profiles)
	# Without the flag it is one choice of three, as before.
	var shared := _tiers()
	shared.categories.append(_category(1 << 0, 0, true, [1.0]))
	h.eq("a boss that does not take the day is one of three",
		Week.new(shared, 5, 1).offers(1).size(), shared.profiles.size())

# -------------------------------------------------------------- the queue
func test_the_queue_shows_the_rest_of_a_lineup_in_order() -> void:
	var cfg := _cfg()
	cfg.waiting_max = 4
	var order: Array = _some(5)
	var s := _shift(cfg, [], order, 2)
	h.eq("who has not come in yet, in order", _ids(s.upcoming()), _ids(order.slice(2)))
	for c in s.seated():
		c.patience = 999
	s._burn(1, "cards")
	h.eq("one fewer once they have", _ids(s.upcoming()), _ids(order.slice(3)))
	s._burn(10, "cards")
	h.check("and nobody once they all have", s.upcoming().is_empty())

func test_the_queue_shows_who_the_door_sends_next() -> void:
	var s := _shift(_cfg(), [], [], 0)
	s._pick_archetype()
	var shown: Array = s.upcoming()
	h.eq("one is shown", shown.size(), 1)
	h.eq("and it is the one who comes", s._pick_archetype(), shown[0])
	h.eq("then the one after", s.upcoming().size(), 1)

func test_who_is_shown_coming_never_doubles_a_hard_archetype_already_waiting() -> void:
	var cfg := _cfg()
	cfg.waiting_max = 99
	var s := _shift(cfg, [], [], 0)
	var doubled := false
	var seen := {}
	for c in s.seated():
		if c.archetype.hard:
			seen[c.archetype.id] = true
	for _i in range(15):
		var shown: Array = s.upcoming()
		var a: CustomerArchetype = s._pick_archetype()
		if not shown.is_empty() and shown[0] != a:
			doubled = true
		if a.hard and seen.has(a.id):
			doubled = true
		if a.hard:
			seen[a.id] = true
		s.waiting.append(a)
	h.check("nobody comes who was not shown, and no hard one comes twice", not doubled)

func test_nobody_is_shown_who_the_bell_comes_before() -> void:
	var cfg := _cfg()
	var s := _shift(cfg, [], [], 0)
	s._pick_archetype()
	h.check("someone is on their way early in the day", not s.upcoming().is_empty())
	s.next_arrival = s.tick_budget - s.tick
	h.check("none when the next is due after the bell", s.upcoming().is_empty())
	s.waiting.assign(_some(cfg.waiting_max))
	h.check("unless the list is full: that clock is stopped, so who knows",
		not s.upcoming().is_empty())

# ------------------------------------------------------- dealt by difficulty
## Made-up archetypes worth 1, 2 and 3 points, open from week 1.
func _points_pool() -> ArchetypePool:
	var typed: Array[CustomerArchetype] = []
	for points in [1, 2, 3]:
		var a := CustomerArchetype.new()
		a.id = StringName("made_up_%d" % points)
		a.difficulty = points
		a.weight = 1.0
		typed.append(a)
	var p := ArchetypePool.new()
	p.design_rule = "test double"
	p.archetypes = typed
	return p

## Tiers that build their shifts: `customers` each, to a target of `start`
## climbing `per_day`.
func _built_tiers(start: int, per_day: float = 0.0, customers: int = 5) -> ShiftProfilePool:
	var pool := _tiers()
	for t in pool.profiles:
		t.customers = customers
		t.difficulty_start = start
		t.difficulty_per_day = per_day
	return pool

func _deal_cfg(tolerance: int = 1) -> ShiftConfig:
	var cfg: ShiftConfig = (load("res://data/shift_config.tres") as ShiftConfig).duplicate()
	cfg.difficulty_tolerance = tolerance
	cfg.complicator_share = 0.0
	return cfg

## A premade shift for the category below: fixed (a lineup) when `fixed`.
func _premade(id: StringName, rating: int, fixed: bool) -> ShiftProfile:
	var p := ShiftProfile.new()
	p.id = id
	p.difficulty = rating
	if fixed:
		p.lineup.assign(_points_pool().archetypes)
	return p

func _offered(week: Week, days: int) -> Array:
	var out := []
	for day in range(1, days + 1):
		out.append_array(week.offers(day))
	return out

func test_a_tier_follows_its_own_difficulty_climb() -> void:
	var t := ShiftProfile.new()
	t.difficulty_start = 6
	t.difficulty_per_day = 0.5
	h.eq("day 1 is where it starts", t.difficulty_on(1), 6)
	h.eq("and it climbs from there", t.difficulty_on(5), 8)

func test_a_tier_that_builds_deals_a_lineup_to_the_days_target() -> void:
	var pool := _built_tiers(7, 1.0)
	var week := Week.new(pool, 3, 1, 5, _points_pool(), _deal_cfg())
	for day in range(1, 4):
		for p in week.offers(day):
			h.eq("day %d %s: five customers" % [day, p.id], p.lineup.size(), 5)
			h.eq("day %d %s: to that day's target" % [day, p.id], p.difficulty, 6 + day)
			h.check("day %d %s: still the regular shift" % [day, p.id], not p.is_premade())
	var plain := _tiers()
	h.eq("a tier with no customers set is the old door",
		Week.new(plain, 1, 1, 5, _points_pool(), _deal_cfg()).offers(1), plain.profiles)

func test_a_fixed_shift_is_dealt_only_near_its_rating() -> void:
	var pool := _built_tiers(9)
	var category := ShiftCategory.new()
	category.shifts.append(_premade(&"near", 10, true))
	category.shifts.append(_premade(&"far", 12, true))
	for p in category.shifts:
		p.chance = 0.5
	pool.categories.append(category)
	var seen := {}
	for seed_value in range(20):
		for p in _offered(Week.new(pool, 5, seed_value, 5, _points_pool(), _deal_cfg(1)), 5):
			seen[p.id] = true
	h.check("within the tolerance, it comes up", seen.has(&"near"))
	h.check("outside it, never", not seen.has(&"far"))
	var unrated := _built_tiers(9)
	var anywhere := ShiftCategory.new()
	anywhere.shifts.append(_premade(&"unrated", 0, true))
	unrated.categories.append(anywhere)
	var dealt := _offered(Week.new(unrated, 1, 1, 5, _points_pool(), _deal_cfg(1)), 1)
	h.check("unrated, it comes up by chance alone",
		dealt.any(func(p): return p.id == &"unrated"))

func test_a_scaling_shift_comes_back_each_week_built_to_that_weeks_target() -> void:
	## "Short Staffed in week 1, and again in week 2 - harder."
	var pool := _built_tiers(6, 1.0)
	var category := ShiftCategory.new()
	category.slots = 1 << 0
	category.shifts.append(_premade(&"scales", 0, false))
	pool.categories.append(category)
	var week := Week.new(pool, 10, 1, 5, _points_pool(), _deal_cfg())
	var dealt := []
	for day in range(1, 11):
		for p in week.offers(day):
			if p.id == &"scales":
				dealt.append([day, p])
	h.eq("once a week, every week (%s)" % str(dealt.map(func(d): return d[0])), dealt.size(), 2)
	for d in dealt:
		var p: ShiftProfile = d[1]
		h.eq("day %d: built to that day's target" % d[0], p.difficulty, 5 + d[0])
		h.eq("day %d: with the slot's customers" % d[0], p.lineup.size(), 5)
	h.check("and a harder one the second time",
		(dealt[1][1] as ShiftProfile).difficulty > (dealt[0][1] as ShiftProfile).difficulty)

func test_a_scaling_shift_waits_for_a_slot_that_leaves_its_customers_enough() -> void:
	## Its rules take 8 of a 9-point slot: one point left for five customers who
	## cost at least one each is no shift at all.
	var pool := _built_tiers(9)
	var category := ShiftCategory.new()
	category.shifts.append(_premade(&"too_much", 8, false))
	pool.categories.append(category)
	var seen := _offered(Week.new(pool, 5, 1, 5, _points_pool(), _deal_cfg(1)), 5)
	h.check("never dealt", not seen.any(func(p): return p.id == &"too_much"))

func test_a_slot_never_takes_a_premade_shift_bringing_someone_it_keeps_out() -> void:
	## "Speedster and Family First never show at night" - a premade lineup, or a
	## shift that names its customers, included. A target five of them could
	## make, so the exclusion is the only thing keeping either out.
	var pool := _built_tiers(5)
	var kept_out: CustomerArchetype = _points_pool().archetypes[0]
	for t in pool.profiles:
		t.excluded_archetypes.assign([kept_out])
	var category := ShiftCategory.new()
	var lineup := _premade(&"brings_them", 0, true)
	lineup.lineup.assign([kept_out])
	var named := _premade(&"names_them", 0, false)
	named.only_archetypes.assign([kept_out])
	category.shifts.append_array([lineup, named])
	pool.categories.append(category)
	var seen := _offered(Week.new(pool, 5, 1, 5, _points_pool(), _deal_cfg()), 5)
	h.check("neither is ever dealt (%s)" % str(seen.map(func(p): return p.id)),
		not seen.any(func(p): return p.id == &"brings_them" or p.id == &"names_them"))

func test_a_premade_shift_bringing_someone_from_a_later_week_waits_for_it() -> void:
	## Only a boss brings anyone early.
	var pool := _built_tiers(5)
	var late := CustomerArchetype.new()
	late.id = &"made_up_late"
	late.difficulty = 1
	late.weight = 1.0
	late.from_week = 2
	var category := ShiftCategory.new()
	var brings := _premade(&"brings_late", 0, false)
	brings.only_archetypes.assign([late])
	category.shifts.append(brings)
	pool.categories.append(category)
	var week := Week.new(pool, 10, 1, 5, _points_pool(), _deal_cfg())
	var days: Array = []
	for day in range(1, 11):
		for p in week.offers(day):
			if p.id == &"brings_late":
				days.append(day)
	h.check("never in week 1 (dealt on %s)" % str(days), days.all(func(d): return d > 5))
	h.check("but in week 2", not days.is_empty())

func test_a_premade_shift_is_paid_like_its_slot_and_a_boss_like_itself() -> void:
	var pool := _built_tiers(9)
	for t in pool.profiles:
		t.commission = 0.9
		t.cards_for_sale = 7
	var category := ShiftCategory.new()
	category.days = 1 << 0
	var special := _premade(&"special", 0, true)
	special.commission = 0.1
	category.shifts.append(special)
	var bosses := ShiftCategory.new()
	bosses.days = 1 << 1
	bosses.boss_day = true
	var boss := _premade(&"boss", 0, true)
	boss.commission = 0.2
	bosses.shifts.append(boss)
	pool.categories.append_array([category, bosses])
	var week := Week.new(pool, 2, 1, 5, _points_pool(), _deal_cfg())
	var dealt: ShiftProfile = week.offers(1).filter(func(p): return p.id == &"special")[0]
	h.eq("the special one takes its slot's commission", dealt.commission, 0.9)
	h.eq("and its slot's store", dealt.cards_for_sale, 7)
	h.eq("the authored one is untouched", special.commission, 0.1)
	var dealt_boss: ShiftProfile = week.offers(2).filter(func(p): return p.is_boss_day())[0]
	h.eq("a boss keeps its own", dealt_boss.commission, 0.2)

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
