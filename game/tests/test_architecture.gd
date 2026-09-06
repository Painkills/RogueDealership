extends RefCounted
var h: Harness
## The guards that keep the model drivable by a headless suite. These are not
## style checks: each one protects a property the whole project rests on.

func test_the_model_never_reaches_into_the_view() -> void:
	## The one line that keeps the headless suite able to drive the real game.
	## Covers scripts/run too: a new sibling directory is otherwise silently
	## outside the rules this project treats as non-negotiable.
	for path in _scripts_under("res://scripts/model") + _scripts_under("res://scripts/run"):
		var src := FileAccess.get_file_as_string(path)
		h.check("%s does not import the view" % path.get_file(),
			not src.contains("scripts/view"))
		h.check("%s does not extend Node" % path.get_file(),
			not src.contains("extends Node"))

func test_nothing_in_the_model_calls_the_global_rng() -> void:
	## Bare randi()/randf()/shuffle() use Godot's GLOBAL rng and would silently
	## destroy reproducibility. Every call must go through the seeded instance,
	## which reads as "rng." immediately before the call.
	##
	## Not hypothetical in scripts/run: the shop rolls which cards it offers, and
	## that is exactly where a bare randi() gets written.
	for path in _scripts_under("res://scripts/model") + _scripts_under("res://scripts/run"):
		var src := _code_only(FileAccess.get_file_as_string(path))
		for banned in ["shuffle()", "randi()", "randf()", "randi_range(",
				"randf_range("]:
			var idx := src.find(banned)
			while idx != -1:
				var prefix := src.substr(max(0, idx - 4), 4)
				h.check("%s calls %s only through the seeded rng"
					% [path.get_file(), banned], prefix.ends_with("rng."))
				idx = src.find(banned, idx + 1)

func _code_only(src: String) -> String:
	## Strip comments before scanning: the guard is about CODE, and the model
	## deliberately explains in prose why Array.shuffle() is banned.
	var out := ""
	for line in src.split("\n"):
		var hash_at := line.find("#")
		out += (line if hash_at == -1 else line.substr(0, hash_at)) + "\n"
	return out

func test_runtime_state_classes_are_refcounted_not_resource() -> void:
	## Resources are cached and shared project-wide, so mutable state on one
	## leaks between customers and between runs. The guard above only rejects
	## `extends Node`, which `extends Resource` sails straight past - so without
	## naming scripts/run/'s own files here, "scripts/run/ is pure RefCounted"
	## is a claim this suite never actually checks.
	for entry in [["scripts/model", "shift.gd"], ["scripts/model", "customer.gd"],
			["scripts/model", "offer.gd"], ["scripts/model", "card_instance.gd"],
			["scripts/model", "deck.gd"], ["scripts/model", "result.gd"],
			["scripts/model", "effect_context.gd"],
			["scripts/run", "run_state.gd"], ["scripts/run", "shop.gd"]]:
		var path := "res://%s/%s" % [entry[0], entry[1]]
		var src := FileAccess.get_file_as_string(path)
		h.check("%s exists" % entry[1], src != "")
		h.check("%s extends RefCounted" % entry[1],
			src.contains("extends RefCounted"))

func test_two_shifts_built_back_to_back_share_no_state() -> void:
	## The behavioural version of the rule above: if any runtime state had been
	## put on a Resource, the second shift would inherit the first one's.
	var cfg: ShiftConfig = (load("res://data/shift_config.tres") as ShiftConfig).duplicate()
	cfg.patience_jitter = 0
	cfg.prior_slip = 0.0
	var interests := load("res://data/interests/interest_pool.tres")
	var cards := load("res://data/card_pool.tres")
	var arch := load("res://data/archetype_pool.tres")
	var a := Shift.new(cfg, interests, cards, arch, 5, [&"easygoing"])
	a.chairs[0].line += 100
	a.chairs[0].patience -= 3
	a.chairs[0].known_line = true
	var b := Shift.new(cfg, interests, cards, arch, 5, [&"easygoing"])
	h.eq("the second customer starts at the archetype Line",
		b.chairs[0].line, b.chairs[0].archetype.line)
	h.check("and did not inherit what the first one had learned",
		not b.chairs[0].known_line)

func test_upgrading_a_card_in_one_deck_does_not_touch_another() -> void:
	var pool: CardPool = load("res://data/card_pool.tres")
	var a := Deck.build_starting(pool)
	var b := Deck.build_starting(pool)
	a.upgrade(a.cards[0].uid)
	h.check("the first deck's card is upgraded", a.cards[0].upgraded)
	h.check("the second deck's is not", not b.cards[0].upgraded)

func _scripts_under(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	_walk(dir_path, out)
	return out

func _walk(dir_path: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var entry := d.get_next()
	while entry != "":
		var full := dir_path.path_join(entry)
		if d.current_is_dir():
			_walk(full, out)
		elif entry.ends_with(".gd"):
			out.append(full)
		entry = d.get_next()
	d.list_dir_end()
