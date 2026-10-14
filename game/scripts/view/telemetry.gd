class_name Telemetry extends SupabaseClient
## Play metrics: every move a player makes, and how long they took to make it,
## sent anonymously to the game's Supabase project (docs/telemetry_setup.sql) so
## QA sessions show where people stall, get refused, or give up.
##
## Two halves. Recording is static - Telemetry.record() from anywhere in the view,
## no node needed, so a driver or a test can read what was recorded. Sending is
## the one Telemetry node the run keeps (RunController): it posts what is queued
## in batches, and keeps whatever has not gone yet on disk to try again.
##
## Anonymous: a random id per device and per launch, never a name, an email, or
## anything typed. Cards, customers and shifts by their ids. Off with
## PlayerProfile.set_telemetry_off().
##
## In the view layer for the same reason Leaderboard is: it reaches outside the
## game, and the model and run layers never do. What the model knows about a move
## it says in Shift.command_notes and Shop.command_notes.

## Drivers and tests set this: events are still recorded (in `events`), but
## nothing is written to disk or sent.
static var offline := false
## True while a saved run is played back (RunSave) - those moves were recorded the
## first time.
static var muted := false
## Where this device's id lives, and the queue of what has not been sent yet.
static var path := "user://telemetry.cfg"
static var queue_path := "user://telemetry_queue.json"

## The most events a batch carries, and the most text: the browser sends a batch
## with keepalive, which allows 64 KB.
const BATCH := 25
const BATCH_BYTES := 48000
## Seconds between sends while there is something to send.
const EVERY := 30.0
## How many of this session's events are kept in memory for a driver to read.
const KEPT := 4000
## The most a queue holds while it cannot be sent: past it, the oldest go.
const MOST_QUEUED := 3000

## This session's events, oldest first - what a driver checks.
static var events: Array = []
static var _queue: Array = []
static var _install := ""
static var _session := ""
static var _run := ""
static var _seq := 0
static var _started_ms := -1
## When the player last did something - think time is counted from here.
static var _last_input_ms := -1
## When the app went to the background, or -1: time away is not thinking.
static var _away_since := -1
static var _opted_out := -1

# --- recording ------------------------------------------------------------

## Whether events are being recorded at all.
static func enabled() -> bool:
	if muted:
		return false
	if _opted_out == -1:
		_opted_out = 1 if PlayerProfile.telemetry_off() else 0
	return _opted_out == 0

## The player's choice, from the title screen's line.
static func set_off(off: bool) -> void:
	PlayerProfile.set_telemetry_off(off)
	_opted_out = 1 if off else 0
	if off:
		_queue.clear()
		_save_queue()

## A new launch: a fresh session id, and what it is running on.
static func start_session(details: Dictionary = {}) -> void:
	_session = _random_id()
	_seq = 0
	_started_ms = Time.get_ticks_msec()
	_last_input_ms = _started_ms
	_load_queue()
	var data := {"platform": platform(), "screen": [DisplayServer.window_get_size().x,
		DisplayServer.window_get_size().y]}
	data.merge(details)
	record("session_start", data)

## A run begins (or is picked up again) - every event until the next is in it.
static func start_run(kind: String, details: Dictionary = {}) -> void:
	_run = _random_id()
	var data := {"mode": kind}
	data.merge(details)
	record("run_start", data, true)

static func end_run() -> void:
	_run = ""

## Records one event. `input`: something the player did - its think_ms is the
## time since the last thing they did, and it starts the next one's.
static func record(kind: String, data: Dictionary = {}, input: bool = false) -> void:
	if not enabled():
		return
	var now := Time.get_ticks_msec()
	if _started_ms < 0:
		_started_ms = now
		_last_input_ms = now
	var row := row_for(kind, plain(data), now)
	if input:
		row["think_ms"] = maxi(0, now - _last_input_ms)
		_last_input_ms = now
	events.append(row)
	if events.size() > KEPT:
		events = events.slice(events.size() - KEPT)
	if offline:
		return
	_queue.append(row)
	if _queue.size() > MOST_QUEUED:
		_queue = _queue.slice(_queue.size() - MOST_QUEUED)
	_save_queue()

## Something the player did that is not an event of its own - the clock for the
## next think time starts here.
static func mark_input() -> void:
	_last_input_ms = Time.get_ticks_msec()

## The app went to the background, or came back: time away is not thinking.
static func set_away(away: bool) -> void:
	var now := Time.get_ticks_msec()
	if away and _away_since < 0:
		_away_since = now
	elif not away and _away_since >= 0:
		_last_input_ms += now - _away_since
		_away_since = -1

## The events recorded this session with this `kind`.
static func of_kind(kind: String) -> Array:
	return events.filter(func(e): return e["kind"] == kind)

## The row as it goes into the table - see docs/telemetry_setup.sql.
static func row_for(kind: String, data: Dictionary, now_ms: int) -> Dictionary:
	_seq += 1
	return {
		"install": install_id(),
		"session": _session,
		"run": _run if _run != "" else null,
		"build": BuildInfo.LABEL,
		"seq": _seq,
		"t_ms": maxi(0, now_ms - _started_ms),
		"think_ms": null,
		"kind": kind,
		"data": data,
	}

# --- what a move was --------------------------------------------------------

## One move on the floor, as ShiftController._apply() got it back: what it was
## (the model's own note of it), and what came of it.
static func shift_action(shift: Shift, res: Result) -> void:
	if shift == null or shift.commands.is_empty():
		return
	var cmd: Array = shift.commands.back()
	var note: Dictionary = shift.command_notes.back() if \
		shift.command_notes.size() == shift.commands.size() else {}
	var data := {"cmd": String(cmd[0]), "ok": res.ok, "result": res.kind,
		"day": shift.shift_number}
	data.merge(note)
	if not res.ok:
		data["refused"] = res.msg
	if res.ok and res.kind == "sale":
		data["sold_for"] = res.data.get("margin", 0)
		data["multiplier"] = res.data.get("multiplier", 1.0)
		data["signed"] = res.data.get("signed", false)
	record("action", data, true)

## One move in the store, as ShopScreen._apply() got it back.
static func shop_action(shop: Shop, res: Result) -> void:
	if shop == null or shop.commands.is_empty():
		return
	var cmd: Array = shop.commands.back()
	var data := {"cmd": String(cmd[0]), "ok": res.ok, "money_after": shop.run.money,
		"day": shop.run.shift_number}
	if cmd.size() > 1 and not (cmd[1] is int):
		data["id"] = str(cmd[1])
	if shop.command_notes.size() == shop.commands.size():
		data.merge(shop.command_notes.back())
	if not res.ok:
		data["refused"] = res.msg
	record("shop", data, true)

## What the customer side did, one action_log entry: an action, a demand raised,
## answered or missed, a boss's move.
static func customer_entry(shift: Shift, entry: Dictionary) -> void:
	if shift == null or bool(entry.get("yours", false)) or entry.has("chatter"):
		return
	var chair: int = Shift.CHAIR_KEYS.find(str(entry.get("key", "")))
	var c = shift.chairs[chair] if chair >= 0 and chair < shift.chairs.size() else null
	var fx: Dictionary = entry.get("fx", {})
	var moved := {}
	for k in fx:
		if fx[k] is int and int(fx[k]) != 0 and k != "swept" and k != "rejected":
			moved[k] = fx[k]
	if str(entry.get("name", "")) == "" and moved.is_empty():
		return
	record("customer", {"tick": shift.tick, "archetype": String(c.archetype.id) if c else "",
		"chair": chair, "name": str(entry.get("name", "")), "fx": moved,
		"floor_wide": bool(entry.get("floor_wide", false))})

## JSON-safe copy of `v`: resources by their id, objects by name, the rest as is.
static func plain(v):
	if v is Dictionary:
		var out := {}
		for k in v:
			out[str(k)] = plain(v[k])
		return out
	if v is Array:
		return v.map(func(x): return plain(x))
	if v is StringName:
		return String(v)
	if v is Object:
		if v == null:
			return null
		if "id" in v:
			return str(v.id)
		return str(v)
	if v is float and (is_nan(v) or is_inf(v)):
		return 0
	return v

## Whether the web build is running installed, as an app on its own.
static func installed_app() -> bool:
	if not OS.has_feature("web"):
		return false
	return str(JavaScriptBridge.eval(
		"window.matchMedia('(display-mode: standalone)').matches ? 'yes' : 'no'", true)) == "yes"

## "web", "web-mobile", or the desktop OS.
static func platform() -> String:
	if OS.has_feature("web"):
		return "web-mobile" if OS.has_feature("web_android") or OS.has_feature("web_ios") \
			else "web"
	return OS.get_name().to_lower()

## This device's id: random, made once, kept with nothing else about the player.
static func install_id() -> String:
	if _install != "":
		return _install
	var file := ConfigFile.new()
	file.load(path)
	_install = str(file.get_value("telemetry", "install", ""))
	if _install == "":
		_install = _random_id()
		if not offline:
			file.set_value("telemetry", "install", _install)
			file.save(path)
	return _install

static func _random_id() -> String:
	return Crypto.new().generate_random_bytes(16).hex_encode()

# --- the queue on disk --------------------------------------------------------

static func queued() -> Array:
	return _queue

static func _save_queue() -> void:
	if offline:
		return
	var f := FileAccess.open(queue_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_queue))

static func _load_queue() -> void:
	if offline or not FileAccess.file_exists(queue_path):
		return
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(queue_path)) == OK and json.data is Array:
		# What an earlier launch could not send goes first.
		var earlier: Array = json.data
		_queue = earlier + _queue.filter(func(e): return not earlier.has(e))

## Forgets this session's events and queue - a test starting clean.
static func reset_for_testing() -> void:
	events.clear()
	_queue.clear()
	_seq = 0
	_run = ""
	_session = ""
	_started_ms = -1
	_last_input_ms = -1
	_away_since = -1
	_opted_out = -1
	_install = ""

# --- sending ------------------------------------------------------------------

## The next batch to send from `queue`: at most BATCH events, and no more text
## than BATCH_BYTES - but always at least one.
static func next_batch(queue: Array) -> Array:
	var out: Array = []
	var size := 2
	for e in queue:
		var n := JSON.stringify(e).length() + 1
		if not out.is_empty() and (out.size() >= BATCH or size + n > BATCH_BYTES):
			break
		out.append(e)
		size += n
	return out

## What a reply's status means for the batch it answered: &"sent"; &"refused" (a
## batch the table will never take - drop it); &"give_up" (no table, or no right
## to it - stop for this launch, keep the queue); or &"retry" (no network, the
## server busy - try again later).
static func after_reply(code: int) -> StringName:
	if code >= 200 and code < 300:
		return &"sent"
	if code == 401 or code == 403 or code == 404:
		return &"give_up"
	if code == 400 or code == 409 or code == 413 or code == 422:
		return &"refused"
	return &"retry"

static func insert_url(base: String) -> String:
	return "%s/rest/v1/events" % base.trim_suffix("/")

var _sending := false
var _clock := 0.0
## The server said there is no table, or no right to it: no more tries this launch.
var _given_up := false

func _ready() -> void:
	set_process(true)

func _process(delta: float) -> void:
	super(delta)
	_clock += delta
	if _clock >= EVERY or Telemetry._queue.size() >= BATCH:
		_clock = 0.0
		flush()
	# The base switches processing off once nothing is in flight; this keeps the clock.
	set_process(true)

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED:
			Telemetry.set_away(true)
			flush()
		NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED:
			Telemetry.set_away(false)

## Sends the next batch, if there is one and none is on its way.
func flush() -> void:
	if Telemetry.offline or _sending or _given_up or Telemetry._queue.is_empty() \
			or not Telemetry.enabled():
		return
	var batch := Telemetry.next_batch(Telemetry._queue)
	_sending = true
	_send(insert_url(PROJECT_URL), HTTPClient.METHOD_POST, JSON.stringify(batch),
		func(code: int, _text: String): _answered(code, batch))

func _answered(code: int, batch: Array) -> void:
	_sending = false
	var what := Telemetry.after_reply(code)
	if what == &"give_up":
		_given_up = true
	elif what == &"sent" or what == &"refused":
		# Sent - or a batch the table will never take: either way it goes.
		Telemetry._queue = Telemetry._queue.filter(func(e): return not batch.has(e))
		Telemetry._save_queue()
		if Telemetry._queue.size() >= BATCH:
			flush()
