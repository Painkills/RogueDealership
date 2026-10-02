class_name Leaderboard extends Node
## The high scores everyone shares: a finished week's badge name and score,
## posted to a Supabase table, and the top of that table read back for the
## title screen. docs/leaderboard_setup.sql builds the table and its rules:
## anyone may read it or add a row, nobody but its owner may change one.
##
## Personal bests stay where they were, on the device (PlayerProfile). This is
## the board on top of them - and if it is not set up, or the network is down,
## the game carries on without it.
##
## In the view layer for the same reason PlayerProfile is: it reaches outside
## the game, and the model and run layers never do.

## The Supabase project - Settings -> API. The anon key is MEANT to be public:
## what it may do is limited by the table's own rules, not by keeping it secret.
const URL := ""
const KEY := ""

## How many of the best scores the title screen asks for.
const TOP := 20

## Drivers and tests set this so nothing they run ever touches the network.
static var offline := false

## A fetch came back: `rows` best first, each {name, score, banked, fired,
## date}; `ok` false if it could not be reached at all.
signal fetched(rows: Array, ok: bool)

## Words a name tag on a board everyone sees may not carry. Such a name is
## posted as the job title instead - see PlayerProfile.DEFAULT_NAME.
## Kept to words no real name contains ("cock" would catch Hancock).
const BLOCKED := ["fuck", "shit", "cunt", "bitch", "nigg", "faggot", "pussy",
	"whore", "slut", "nazi", "penis", "vagina"]

## Whether there is a board to talk to.
static func available() -> bool:
	return not offline and URL != "" and KEY != ""

func fetch(limit: int = TOP) -> void:
	if not available():
		fetched.emit([], false)
		return
	_send(rows_url(URL, limit), HTTPClient.METHOD_GET, "",
		func(code: int, text: String):
			var ok := code >= 200 and code < 300
			fetched.emit(parse(text) if ok else [], ok))

## Fire and forget: a score that cannot be posted is still on the device.
func submit(player_name: String, score: int, banked: int, fired: bool) -> void:
	if not available():
		return
	_send(insert_url(URL), HTTPClient.METHOD_POST,
		JSON.stringify(body(player_name, score, banked, fired)), func(_c, _t): pass)

func _send(url: String, method: int, data: String, done: Callable) -> void:
	var req := HTTPRequest.new()
	req.timeout = 10.0
	add_child(req)
	req.request_completed.connect(
		func(_result: int, code: int, _headers: PackedStringArray, bytes: PackedByteArray):
			req.queue_free()
			done.call(code, bytes.get_string_from_utf8()))
	if req.request(url, headers(KEY), method, data) != OK:
		req.queue_free()
		done.call(0, "")

# --- the request, as plain data (tested without a network) -----------------

static func rows_url(base: String, limit: int) -> String:
	return "%s/rest/v1/scores?select=name,score,banked,fired,created_at&order=score.desc,created_at.asc&limit=%d" \
		% [base.trim_suffix("/"), limit]

static func insert_url(base: String) -> String:
	return "%s/rest/v1/scores" % base.trim_suffix("/")

static func headers(key: String) -> PackedStringArray:
	return PackedStringArray(["apikey: " + key, "Authorization: Bearer " + key,
		"Content-Type: application/json", "Prefer: return=minimal"])

static func body(player_name: String, score: int, banked: int, fired: bool) -> Dictionary:
	return {"name": clean_name(player_name), "score": score,
		"banked": maxi(0, banked), "fired": fired}

## A name fit for a board everyone sees: trimmed, no longer than a name tag,
## never blank, and never one of BLOCKED.
static func clean_name(n: String) -> String:
	var tag := n.strip_edges().left(PlayerProfile.MAX_NAME).strip_edges()
	var squashed := tag.to_lower().replace(" ", "").replace("_", "").replace(".", "")
	for word in BLOCKED:
		if squashed.contains(word):
			return PlayerProfile.DEFAULT_NAME
	return tag if tag != "" else PlayerProfile.DEFAULT_NAME

## The table's reply, as rows the title screen can list - anything that is not
## a well-formed row is skipped rather than trusted.
static func parse(text: String) -> Array:
	var out: Array = []
	# An instance rather than JSON.parse_string(), which logs an engine error
	# for every reply that is not JSON - a proxy's error page, say.
	var json := JSON.new()
	if json.parse(text) != OK:
		return out
	var data = json.data
	if not (data is Array):
		return out
	for r in data:
		if not (r is Dictionary) or not r.has("name") or not r.has("score"):
			continue
		out.append({"name": str(r["name"]).left(PlayerProfile.MAX_NAME),
			"score": int(r["score"]), "banked": int(r.get("banked", 0)),
			"fired": bool(r.get("fired", false)),
			"date": str(r.get("created_at", "")).left(10)})
	return out
