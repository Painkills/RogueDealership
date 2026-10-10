extends RefCounted
## The run in progress on disk: written, read back, replaced, and gone once it
## is over. At a path of its own, never the real player's run.
var h: Harness

const PATH := "user://test_run_file.save"

func _save(day: int) -> RunSave:
	var s := RunSave.new()
	s.checkpoint = {"seed": 3, "shift_number": day}
	s.pick = 1
	s.shift_commands = [[&"approach", 2], [&"play_card", 0, -1], [&"offer"]]
	s.fingerprint = 12345
	return s

func _use_a_test_file() -> void:
	RunFile.path = PATH
	RunFile.clear()

func _done() -> void:
	RunFile.clear()
	RunFile.path = "user://run.save"

func test_a_run_written_reads_back_the_same() -> void:
	_use_a_test_file()
	h.check("nothing to continue on a fresh device", RunFile.read() == null
		and not RunFile.exists())
	RunFile.write(_save(4))
	var back := RunFile.read()
	h.check("something to continue once one is written", back != null)
	h.eq("the same day", back.day(), 4)
	h.eq("the same moves", back.shift_commands, _save(4).shift_commands)
	h.eq("the same fingerprint", back.fingerprint, 12345)
	_done()

func test_writing_again_replaces_it() -> void:
	_use_a_test_file()
	RunFile.write(_save(2))
	RunFile.write(_save(3))
	h.eq("the newest one", RunFile.read().day(), 3)
	h.check("and nothing left half-written beside it",
		not FileAccess.file_exists(PATH + ".new"))
	_done()

func test_a_finished_run_leaves_nothing_to_continue() -> void:
	_use_a_test_file()
	RunFile.write(_save(5))
	RunFile.clear()
	h.check("gone", RunFile.read() == null)
	_done()

func test_a_file_that_is_not_a_save_is_not_read() -> void:
	_use_a_test_file()
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string("not a save at all")
	f.close()
	h.check("nothing to continue", RunFile.read() == null)
	_done()
