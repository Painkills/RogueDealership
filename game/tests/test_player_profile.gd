extends RefCounted
## PlayerProfile: the name on this device and its personal bests. Every test
## points it at a file of its own and clears it, so no test ever sees another's
## runs - or a real player's.
var h: Harness

const PATH := "user://test_player_profile.cfg"

func _fresh() -> void:
	PlayerProfile.path = PATH
	PlayerProfile.reset()

func _done() -> void:
	PlayerProfile.reset()
	PlayerProfile.path = "user://profile.cfg"

func test_until_you_write_a_name_you_are_the_job() -> void:
	_fresh()
	h.eq("nothing written yet", PlayerProfile.player_name(), "")
	h.eq("so the boss calls you by the job", PlayerProfile.display_name(),
		PlayerProfile.DEFAULT_NAME)
	PlayerProfile.set_player_name("  Dana  ")
	h.eq("a name is kept, without the stray spaces", PlayerProfile.player_name(), "Dana")
	h.eq("and is what you are called from then on", PlayerProfile.display_name(), "Dana")
	PlayerProfile.set_player_name("A Name Far Too Long For Any Name Tag")
	h.eq("a name tag only holds so much", PlayerProfile.player_name().length(),
		PlayerProfile.MAX_NAME)
	_done()

func test_the_first_run_is_a_personal_best() -> void:
	_fresh()
	h.check("no runs, no best", not PlayerProfile.has_best())
	h.eq("the first run ever is the best so far",
		PlayerProfile.record_run(12000, 9000, false), 1)
	h.eq("and it is the best score now", PlayerProfile.best_score(), 12000)
	_done()

func test_a_week_below_zero_still_counts() -> void:
	## Getting fired with walkouts on the books scores below zero, and that
	## week is still a week on the board - "none" cannot be a number.
	_fresh()
	PlayerProfile.record_run(-5640, 0, true)
	h.check("a run on the board", PlayerProfile.has_best())
	h.eq("at its real score", PlayerProfile.best_score(), -5640)
	_done()

func test_runs_are_ranked_best_first_and_signed_by_whoever_played() -> void:
	_fresh()
	PlayerProfile.set_player_name("Dana")
	PlayerProfile.record_run(12000, 9000, false)
	PlayerProfile.set_player_name("Sam")
	h.eq("a better run by someone else takes the top", PlayerProfile.record_run(15000, 11000, false), 1)
	h.eq("a worse one lands under both", PlayerProfile.record_run(8000, 5000, true), 3)
	var runs := PlayerProfile.bests()
	h.eq("best first", runs.map(func(r): return int(r["score"])), [15000, 12000, 8000])
	h.eq("each signed by whoever played it", runs.map(func(r): return r["name"]),
		["Sam", "Dana", "Sam"])
	h.check("a run that ended in a firing says so", bool(runs[2]["fired"]))
	h.check("and each remembers when (%s)" % runs[0]["date"],
		str(runs[0]["date"]).length() == 10)
	_done()

func test_a_tie_has_to_be_beaten_not_matched() -> void:
	_fresh()
	PlayerProfile.record_run(10000, 8000, false)
	h.eq("matching your best is not beating it", PlayerProfile.record_run(10000, 8000, false), 2)
	_done()

func test_only_the_best_few_are_kept() -> void:
	_fresh()
	for k in range(PlayerProfile.KEPT):
		PlayerProfile.record_run(1000 * (k + 1), 0, false)
	h.eq("a full list", PlayerProfile.bests().size(), PlayerProfile.KEPT)
	h.eq("a run worse than all of them does not make it", PlayerProfile.record_run(10, 0, false), 0)
	h.eq("and the list stays the same length", PlayerProfile.bests().size(), PlayerProfile.KEPT)
	h.eq("a run better than all of them goes straight to the top",
		PlayerProfile.record_run(999999, 0, false), 1)
	h.eq("pushing the worst off the bottom (%d)" % int(PlayerProfile.bests().back()["score"]),
		int(PlayerProfile.bests().back()["score"]), 2000)
	_done()

func test_a_date_reads_like_a_date() -> void:
	h.eq("month and day", PlayerProfile.short_date("2026-09-25"), "Sep 25")
	h.eq("anything else is left alone", PlayerProfile.short_date("soon"), "soon")
