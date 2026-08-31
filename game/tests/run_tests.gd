extends SceneTree
## Headless test runner.
##
##     godot --headless --path game --script res://tests/run_tests.gd
##
## Discovers every res://tests/**/test_*.gd, instantiates it, sets `h` to the
## shared Harness, and calls every method named test_*.

func _init() -> void:
	var h := Harness.new()
	var crashed: Array[String] = []
	for path in _test_scripts():
		var script: GDScript = load(path)
		if script == null:
			crashed.append("%s failed to load" % path)
			continue
		var suite = script.new()
		suite.h = h
		for m in suite.get_method_list():
			if m.name.begins_with("test_"):
				suite.call(m.name)
	var r: Dictionary = h.results()
	for c in crashed:
		print("FAIL  %s" % c)
	for f in r.failures:
		print("FAIL  %s" % f)
	var total: int = r.passed + r.failed + crashed.size()
	print("\n%d checks, %d passed, %d failed"
		% [total, r.passed, r.failed + crashed.size()])
	quit(1 if r.failed + crashed.size() > 0 else 0)

func _test_scripts() -> Array[String]:
	var out: Array[String] = []
	_walk("res://tests", out)
	out.sort()
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
		elif entry.begins_with("test_") and entry.ends_with(".gd"):
			out.append(full)
		entry = d.get_next()
	d.list_dir_end()
