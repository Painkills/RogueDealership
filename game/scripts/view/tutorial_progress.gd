class_name TutorialProgress extends RefCounted
## Whether this player has already been through (or skipped) the practice
## shift. It opens the game every time either way; what this changes is its
## welcome, which points someone who has done it straight at the week (see
## TutorialCoach._dress_the_splash()). Kept in a small file under user://,
## which a Web build keeps in the browser's own storage.
##
## In the view layer, not scripts/run: it touches disk, and the model and run
## layers never do (see test_architecture.gd). The shift picker's own "HOW TO
## PLAY" button replays the tutorial whatever this says.

## A test points this somewhere of its own so it never reads or clobbers the
## real player's progress.
static var path := "user://progress.cfg"

const SECTION := "tutorial"
const KEY := "done"

static func is_done() -> bool:
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return false
	return bool(file.get_value(SECTION, KEY, false))

static func mark_done() -> void:
	var file := ConfigFile.new()
	file.load(path)   # keep whatever else is in there; a missing file is fine
	file.set_value(SECTION, KEY, true)
	file.save(path)

static func reset() -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
