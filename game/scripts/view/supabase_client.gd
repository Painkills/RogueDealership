class_name SupabaseClient extends Node
## A request to the game's Supabase project, and its reply - shared by the high
## scores (Leaderboard) and the play metrics (Telemetry).
##
## In a web build Godot's own HTTPRequest never completes against the project's
## tables, though the browser's fetch() with the same headers does - so on the web
## the browser sends it, files the reply under an id, and _process() collects it.

## The Supabase project - Settings -> API. The anon key is MEANT to be public:
## what it may do is limited by each table's own rules, not by keeping it secret.
const PROJECT_URL := "https://tmiauedyfphaytwfbsde.supabase.co"
const PUBLIC_KEY := "sb_publishable_mv8R90Sh_xDHPxLmIVoH8Q_JQi3ibf-"

## Requests sent through the browser, waiting on their reply: id -> {done,
## waited}.
var _in_flight := {}
var _next_id := 0

## The headers every request carries.
static func headers(key: String) -> PackedStringArray:
	return PackedStringArray(["apikey: " + key, "Authorization: Bearer " + key,
		"Content-Type: application/json", "Prefer: return=minimal"])

## Sends `data` to `url` and calls `done` with the status code and the reply's
## text - 0 and "" if it never got there.
func _send(url: String, method: int, data: String, done: Callable) -> void:
	if OS.has_feature("web"):
		_send_in_browser(url, method, data, done)
		return
	var req := HTTPRequest.new()
	req.timeout = 10.0
	add_child(req)
	req.request_completed.connect(
		func(_result: int, code: int, _headers: PackedStringArray, bytes: PackedByteArray):
			req.queue_free()
			done.call(code, bytes.get_string_from_utf8()))
	if req.request(url, headers(PUBLIC_KEY), method, data) != OK:
		req.queue_free()
		done.call(0, "")

func _send_in_browser(url: String, method: int, data: String, done: Callable) -> void:
	var id := _next_id
	_next_id += 1
	var head := {}
	for line in headers(PUBLIC_KEY):
		var at := line.find(": ")
		head[line.left(at)] = line.substr(at + 2)
	var options := {"method": "POST" if method == HTTPClient.METHOD_POST else "GET",
		"headers": head, "keepalive": true}
	if data != "":
		options["body"] = data
	# Each client files its replies under its own name, so two never take each
	# other's.
	var box := "__rd_" + str(get_instance_id())
	JavaScriptBridge.eval("""(function () {
		window.%s = window.%s || {};
		fetch(%s, %s)
			.then(function (r) { return r.text().then(function (t) { window.%s[%d] = [r.status, t]; }); })
			.catch(function () { window.%s[%d] = [0, ""]; });
	})();""" % [box, box, JSON.stringify(url), JSON.stringify(options), box, id, box, id], true)
	_in_flight[id] = {"done": done, "waited": 0.0}
	set_process(true)

func _process(delta: float) -> void:
	if _in_flight.is_empty():
		set_process(false)
		return
	var box := "__rd_" + str(get_instance_id())
	for id in _in_flight.keys():
		var entry: Dictionary = _in_flight[id]
		entry["waited"] += delta
		var got = JavaScriptBridge.eval(
			"(function () { var b = window.%s || {}; var r = b[%d]; delete b[%d]; return r ? JSON.stringify(r) : ''; })()"
				% [box, id, id], true)
		if got is String and got != "":
			_in_flight.erase(id)
			var reply = JSON.parse_string(got)
			(entry["done"] as Callable).call(int(reply[0]), str(reply[1]))
		elif entry["waited"] > 10.0:
			_in_flight.erase(id)
			(entry["done"] as Callable).call(0, "")
