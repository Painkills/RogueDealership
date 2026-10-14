extends RefCounted
## The play metrics (Telemetry): what a move is recorded as, that it is anonymous,
## that turning it off records nothing, and the queue and batches it is sent in.
## Offline throughout - nothing here reaches the network - and on a profile and a
## queue of its own, never the player's.
var h: Harness

func _begin() -> Array:
	var was := [PlayerProfile.path, Telemetry.path, Telemetry.queue_path, Telemetry.offline]
	PlayerProfile.path = "user://test_telemetry_profile.cfg"
	Telemetry.path = "user://test_telemetry.cfg"
	Telemetry.queue_path = "user://test_telemetry_queue.json"
	PlayerProfile.reset()
	Telemetry.offline = true
	Telemetry.reset_for_testing()
	return was

func _end(was: Array) -> void:
	PlayerProfile.reset()
	for p in [Telemetry.path, Telemetry.queue_path]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	PlayerProfile.path = was[0]
	Telemetry.path = was[1]
	Telemetry.queue_path = was[2]
	Telemetry.offline = was[3]
	Telemetry.reset_for_testing()

func _shift() -> Shift:
	var cfg: ShiftConfig = (load("res://data/shift_config.tres") as ShiftConfig).duplicate()
	cfg.patience_jitter = 0
	cfg.action_cadence_jitter_ticks = 0
	cfg.arrival_patience_min_fraction = 1.0
	return Shift.new(cfg, load("res://data/interests/interest_pool.tres"),
		load("res://data/card_pool.tres"), load("res://data/archetype_pool.tres"), 5)

func test_a_move_is_recorded_by_the_card_it_was_not_where_it_sat() -> void:
	var was := _begin()
	var s := _shift()
	s.approach(0)
	var card := String(s.hand[0].card.id)
	var res := s.play_card(0)
	Telemetry.shift_action(s, res)
	var e: Dictionary = Telemetry.of_kind("action").back()
	h.eq("the move", e["data"]["cmd"], "play_card")
	h.eq("the card, by id", e["data"]["card"], card)
	h.check("who it was aimed at", e["data"].has("archetype") and e["data"].has("patience"))
	h.check("and how long it took to decide", e["think_ms"] != null)
	_end(was)

func test_a_refusal_says_why() -> void:
	var was := _begin()
	var s := _shift()
	var res := s.offer()
	Telemetry.shift_action(s, res)
	var e: Dictionary = Telemetry.of_kind("action").back()
	h.check("refused, with the words the player saw",
		e["data"]["ok"] == false and e["data"]["refused"] == res.msg)
	_end(was)

func test_every_command_has_its_note() -> void:
	var s := _shift()
	s.approach(0)
	s.place(0)
	s.offer()
	s.leave()
	h.eq("one note per command", s.command_notes.size(), s.commands.size())

func test_nothing_carries_the_name_on_the_badge() -> void:
	var was := _begin()
	PlayerProfile.set_player_name("Zebulon Q")
	Telemetry.start_session({})
	Telemetry.start_run("new", {"seed": 1})
	Telemetry.record("shift_end", {"x": 1})
	h.check("no event holds the name",
		not JSON.stringify(Telemetry.events).contains("Zebulon"))
	_end(was)

func test_turned_off_it_records_nothing() -> void:
	var was := _begin()
	Telemetry.set_off(true)
	Telemetry.record("action", {"cmd": "offer"}, true)
	h.eq("nothing recorded", Telemetry.events.size(), 0)
	Telemetry.set_off(false)
	Telemetry.record("action", {"cmd": "offer"}, true)
	h.eq("and back on, it records again", Telemetry.events.size(), 1)
	_end(was)

func test_a_played_back_run_records_nothing() -> void:
	var was := _begin()
	Telemetry.muted = true
	Telemetry.record("action", {}, true)
	Telemetry.muted = false
	h.eq("muted while CONTINUE plays the run back", Telemetry.events.size(), 0)
	_end(was)

func test_think_time_does_not_count_time_away() -> void:
	var was := _begin()
	Telemetry.record("session_start", {})
	Telemetry._last_input_ms = Time.get_ticks_msec() - 500
	Telemetry._away_since = Time.get_ticks_msec() - 400
	Telemetry.set_away(false)
	Telemetry.record("action", {}, true)
	var think: int = Telemetry.of_kind("action").back()["think_ms"]
	h.check("the 400 ms away come off the 500 (%d)" % think, think < 200)
	_end(was)

func test_the_queue_outlives_a_restart() -> void:
	var was := _begin()
	Telemetry.offline = false
	Telemetry.record("action", {"n": 1}, true)
	Telemetry.record("action", {"n": 2}, true)
	h.eq("queued", Telemetry.queued().size(), 2)
	Telemetry.reset_for_testing()
	h.eq("gone from memory", Telemetry.queued().size(), 0)
	Telemetry.start_session({})
	h.check("read back from disk on the next launch, ahead of the new session's own",
		Telemetry.queued().size() == 3 and Telemetry.queued()[0]["data"]["n"] == 1)
	Telemetry.offline = true
	_end(was)

func test_a_batch_stays_small_enough_to_send() -> void:
	var queue := []
	for i in range(Telemetry.BATCH + 10):
		queue.append({"kind": "action", "data": {"i": i}})
	h.eq("no more than a batch", Telemetry.next_batch(queue).size(), Telemetry.BATCH)
	var big := []
	for i in range(5):
		big.append({"kind": "x", "data": {"pad": "x".repeat(Telemetry.BATCH_BYTES / 3)}})
	var batch := Telemetry.next_batch(big)
	h.check("nor more text than fits (%d)" % batch.size(),
		batch.size() >= 1 and JSON.stringify(batch).length() <= Telemetry.BATCH_BYTES + 10)
	var huge := [{"kind": "x", "data": {"pad": "x".repeat(Telemetry.BATCH_BYTES * 2)}}]
	h.eq("but always at least one", Telemetry.next_batch(huge).size(), 1)

func test_a_row_is_what_the_table_takes() -> void:
	var was := _begin()
	Telemetry.start_session({})
	Telemetry.record("action", {"cmd": "offer"}, true)
	var row: Dictionary = Telemetry.events.back()
	for key in ["install", "session", "run", "build", "seq", "t_ms", "think_ms", "kind", "data"]:
		h.check("has %s" % key, row.has(key))
	h.eq("and nothing else", row.keys().size(), 9)
	h.eq("the url", Telemetry.insert_url("https://x.supabase.co/"),
		"https://x.supabase.co/rest/v1/events")
	_end(was)

func test_plain_turns_resources_into_ids() -> void:
	var a := CustomerArchetype.new()
	a.id = &"made_up"
	h.eq("by id", Telemetry.plain({"who": a, "n": 1, "list": [a]}),
		{"who": "made_up", "n": 1, "list": ["made_up"]})

func test_what_a_reply_means_for_its_batch() -> void:
	h.eq("accepted", Telemetry.after_reply(201), &"sent")
	h.eq("no table yet - stop trying this launch, keep the queue", Telemetry.after_reply(404), &"give_up")
	h.eq("a batch the table will never take is dropped", Telemetry.after_reply(400), &"refused")
	h.eq("no network: try again", Telemetry.after_reply(0), &"retry")
	h.eq("server busy: try again", Telemetry.after_reply(503), &"retry")

func test_a_queue_that_cannot_be_sent_does_not_grow_forever() -> void:
	var was := _begin()
	Telemetry.offline = false
	for i in range(Telemetry.MOST_QUEUED + 5):
		Telemetry._queue.append({"n": i})
	Telemetry.record("action", {}, true)
	h.eq("the oldest go", Telemetry.queued().size(), Telemetry.MOST_QUEUED)
	Telemetry.offline = true
	_end(was)
