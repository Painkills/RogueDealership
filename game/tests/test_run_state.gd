extends RefCounted
## A run: five shifts, a shop between them, one deck through all of it.
var h: Harness

func _run(seed_value: int = 7) -> RunState:
	return RunState.new(load("res://data/shift_config.tres"),
		load("res://data/interests/interest_pool.tres"),
		load("res://data/card_pool.tres"),
		load("res://data/archetype_pool.tres"), seed_value)

func test_a_run_starts_on_shift_one_with_a_starter_deck_and_no_money() -> void:
	var r := _run()
	h.eq("first shift", r.shift_number, 1)
	h.eq("nothing banked yet", r.banked_total, 0)
	h.eq("and nothing to spend", r.money, 0)
	h.eq("with the starter deck", r.deck.cards.size(),
		Deck.build_starting(load("res://data/card_pool.tres")).cards.size())
	h.check("which is not over", not r.is_over())

func test_the_quota_climbs_a_fixed_percentage() -> void:
	var r := _run()
	h.eq("shift 1 is the config quota", r.quota_for(1), 3600)
	h.eq("shift 2", r.quota_for(2), 4140)
	h.eq("shift 3", r.quota_for(3), 4761)
	h.eq("shift 4", r.quota_for(4), 5475)
	h.eq("shift 5", r.quota_for(5), 6296)

func test_only_what_you_bank_over_quota_reaches_the_shop() -> void:
	## The quota is the house's cut and comes out first. What survives it is the
	## budget, and then it resets - no wallet to hoard into.
	var r := _run()
	r.finish_shift({"margin_banked": 4200, "quota": 3600, "made_quota": true})
	h.eq("you advance a shift", r.shift_number, 2)
	h.eq("the shop gets the OVERAGE, not the take", r.money, 600)
	h.eq("while the lifetime total counts every dollar", r.banked_total, 4200)

	r.finish_shift({"margin_banked": 5000, "quota": 4140, "made_quota": true})
	h.eq("the budget RESETS rather than accumulating", r.money, 860)
	h.eq("but the lifetime total keeps climbing", r.banked_total, 9200)
	h.eq("and every report is kept", r.reports.size(), 2)

func test_missing_quota_and_scraping_it_both_leave_nothing_to_spend() -> void:
	## The threshold has teeth on both sides, and neither side goes negative.
	var r := _run()
	r.finish_shift({"margin_banked": 1000, "quota": 3600, "made_quota": false})
	h.eq("missing it by a mile buys nothing", r.money, 0)
	r.finish_shift({"margin_banked": 4140, "quota": 4140, "made_quota": true})
	h.eq("and landing on it exactly buys nothing either", r.money, 0)
	r.finish_shift({"margin_banked": 4762, "quota": 4761, "made_quota": true})
	h.eq("one dollar over is one dollar to spend", r.money, 1)

func test_missing_quota_costs_budget_but_never_the_run() -> void:
	var r := _run()
	for i in range(5):
		h.check("shift %d still runs" % (i + 1), not r.is_over())
		r.finish_shift({"margin_banked": 0, "quota": r.quota_for(i + 1),
			"made_quota": false})
	h.check("the run ends after five shifts regardless", r.is_over())

func test_the_shift_it_builds_carries_the_run_state() -> void:
	var r := _run()
	r.shift_number = 3
	var s := r.start_shift()
	h.eq("the shift knows which one it is", s.shift_number, 3)
	h.eq("and runs to that shift's quota", s.quota, r.quota_for(3))
	var uids := {}
	for c in r.deck.cards:
		uids[c.uid] = true
	for c in s.hand:
		h.check("it deals from the run's deck", uids.has(c.uid))

func test_two_runs_from_one_seed_are_identical() -> void:
	## The whole reason the run owns a seeded rng instead of calling randi().
	var a := _run(4242)
	var b := _run(4242)
	var sa := a.start_shift()
	var sb := b.start_shift()
	var ids_a: Array[String] = []
	var ids_b: Array[String] = []
	for c in sa.seated():
		ids_a.append(String(c.archetype.id))
	for c in sb.seated():
		ids_b.append(String(c.archetype.id))
	h.eq("the same floor walks in", ids_a, ids_b)
