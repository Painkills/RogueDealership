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

## A phone takes the GPU away from an app left in the background, and the
## engine cannot get it back. The page then reloads itself (the Web preset's
## head_include, in export_presets.cfg) and leaves this in its sessionStorage,
## so the game boots straight back into the run instead of onto the title.
const RESUME_FLAG := "rd_resume"
## What a driver sets to boot as though the page had just done that.
static var resume_on_boot_for_testing := false

## Whether this boot is the page coming back after losing its GPU - asked once:
## the answer is forgotten as it is given.
static func reloaded_to_pick_up() -> bool:
	if resume_on_boot_for_testing:
		resume_on_boot_for_testing = false
		return true
	if not OS.has_feature("web"):
		return false
	# Answered as a string: a JS boolean comes back across the bridge as a number.
	var asked = JavaScriptBridge.eval(("(function(){try{var v=sessionStorage.getItem('%s');"
		+ "sessionStorage.removeItem('%s');return v==='1'?'yes':'no';}catch(e){return 'no';}})()")
		% [RESUME_FLAG, RESUME_FLAG], true)
	return str(asked) == "yes"

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
