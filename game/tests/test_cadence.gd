extends RefCounted
## A customer's every-so-often action comes round about as often as its cadence
## says, never like clockwork (ShiftConfig.action_cadence_jitter_ticks). A
## made-up action that does nothing, so only its timing is under test.
var h: Harness

func test_an_every_action_comes_round_near_its_cadence_but_not_like_clockwork() -> void:
	var cfg: ShiftConfig = (load("res://data/shift_config.tres") as ShiftConfig).duplicate()
	cfg.shift_ticks = 600
	var s := Shift.new(cfg, load("res://data/interests/interest_pool.tres"),
		load("res://data/card_pool.tres"), load("res://data/archetype_pool.tres"), 9)
	var c: Customer = s.chairs[0]
	var cadence := 6
	var act := CustomerAction.new()
	act.id = &"made_up_every"
	act.display_name = "Does a thing on a cadence"
	var every := Every.new()
	every.ticks = cadence
	act.trigger = every
	var nothing: Array[Effect] = [ChangePatience.new()]
	act.effects = nothing
	c.archetype = c.archetype.duplicate()
	var acts: Array[CustomerAction] = [act]
	c.archetype.actions = acts
	c.action_state.clear()
	c.max_patience = 99999
	c.patience = 99999

	var fired_at: Array[int] = []
	var seen := 0
	for _i in range(400):
		s._burn(1, "wait")
		if s.chairs[0] != c:
			break
		for e in s.action_log.slice(seen):
			if e["name"] == act.display_name:
				fired_at.append(c.ticks_on_floor)
		seen = s.action_log.size()

	var gaps: Array[int] = []
	for i in range(1, fired_at.size()):
		gaps.append(fired_at[i] - fired_at[i - 1])
	var j: int = cfg.action_cadence_jitter_ticks
	h.check("it came round plenty of times (%d)" % gaps.size(), gaps.size() >= 20)
	var off := gaps.filter(func(g): return g < maxi(1, cadence - j) or g > cadence + j)
	h.check("every gap within %d of its cadence (off: %s)" % [j, str(off)], off.is_empty())
	var kinds := {}
	for g in gaps:
		kinds[g] = true
	h.check("and not like clockwork (%s)" % str(kinds.keys()), j == 0 or kinds.size() > 1)
