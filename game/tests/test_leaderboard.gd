extends RefCounted
## Leaderboard: what the game sends to the shared board and how it reads the
## reply - as plain data, so none of it needs a network.
var h: Harness

func test_a_name_on_the_board_is_a_name_tag() -> void:
	h.eq("trimmed", Leaderboard.clean_name("  Dana  "), "Dana")
	h.eq("never longer than a badge holds",
		Leaderboard.clean_name("A Name Far Too Long For Any Name Tag").length(),
		PlayerProfile.MAX_NAME)
	h.eq("never blank", Leaderboard.clean_name("   "), PlayerProfile.DEFAULT_NAME)

func test_a_blocked_word_posts_the_job_title_instead() -> void:
	for word: String in Leaderboard.BLOCKED:
		var spaced := "x"
		for ch in word.to_upper():
			spaced += " " + ch
		h.eq("%s, however it is spaced or cased" % word,
			Leaderboard.clean_name(spaced), PlayerProfile.DEFAULT_NAME)

func test_a_score_posts_only_what_the_table_accepts() -> void:
	var b := Leaderboard.body("  Dana ", 1234, -5, true)
	h.eq("four fields, nothing the database should set itself",
		b.keys().size(), 4)
	h.eq("the cleaned name", b["name"], "Dana")
	h.eq("the score", b["score"], 1234)
	h.eq("banked never below zero", b["banked"], 0)
	h.eq("and whether they were fired", b["fired"], true)

func test_the_board_is_asked_for_best_first() -> void:
	var url := Leaderboard.rows_url("https://x.supabase.co/", 7)
	h.check("from the scores table, without a doubled slash (%s)" % url,
		url.begins_with("https://x.supabase.co/rest/v1/scores?"))
	h.check("best score first", url.contains("order=score.desc"))
	h.check("as many as asked for", url.ends_with("limit=7"))
	var hs := Leaderboard.headers("k")
	h.check("signed with the key", hs.has("apikey: k") and hs.has("Authorization: Bearer k"))

func test_the_reply_is_read_defensively() -> void:
	var rows := Leaderboard.parse(JSON.stringify([
		{"name": "Dana", "score": 900, "banked": 50, "fired": false,
			"created_at": "2026-10-01T12:00:00+00:00"},
		{"score": 5},
		"junk",
		{"name": "A Name Far Too Long For Any Name Tag", "score": 1}]))
	h.eq("malformed rows are skipped", rows.size(), 2)
	h.eq("a row keeps its name and score", [rows[0]["name"], rows[0]["score"]], ["Dana", 900])
	h.eq("and its day", rows[0]["date"], "2026-10-01")
	h.eq("a name is cut to a badge", rows[1]["name"].length(), PlayerProfile.MAX_NAME)
	h.eq("anything that is not a list is nothing", Leaderboard.parse("{\"x\": 1}"), [])
	h.eq("nor is garbage", Leaderboard.parse("<html>"), [])

func test_offline_there_is_no_board() -> void:
	var was := Leaderboard.offline
	Leaderboard.offline = true
	h.check("offline means no board, whatever is configured", not Leaderboard.available())
	Leaderboard.offline = was
