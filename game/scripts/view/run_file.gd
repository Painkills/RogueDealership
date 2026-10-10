class_name RunFile extends RefCounted
## The run in progress on this device: a RunSave, written after every move, so a
## phone that throws the game away while you look at something else costs you
## nothing - CONTINUE on the title screen puts you back where you were.
##
## Kept under user://, which a Web build keeps in the browser's own storage and
## copies there a frame after the file is closed - and every move is made with
## the game in front of you, so that frame always comes. In the view layer for
## the same reason PlayerProfile is: it touches disk, and the model and run
## layers never do (see test_architecture.gd).

## A test points this somewhere of its own so it never reads or clobbers the
## real player's run.
static var path := "user://run.save"

## Written whole to a file beside it first, then moved over it - a write cut
## short leaves the last good save, never half of one.
static func write(save: RunSave) -> void:
	var temp := path + ".new"
	var f := FileAccess.open(temp, FileAccess.WRITE)
	if f == null:
		push_warning("could not write the run to %s" % temp)
		return
	f.store_string(var_to_str(save.to_dict()))
	f.close()
	DirAccess.rename_absolute(_absolute(temp), _absolute(path))

## The run on this device, or null when there is none to pick up - or none this
## build can read.
static func read() -> RunSave:
	if not FileAccess.file_exists(path):
		return null
	return RunSave.from_dict(str_to_var(FileAccess.get_file_as_string(path)))

static func exists() -> bool:
	return read() != null

## The run is over, or given up for a new one.
static func clear() -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(_absolute(path))

static func _absolute(p: String) -> String:
	return ProjectSettings.globalize_path(p)
