class_name PlayerProfile extends RefCounted
## Who is playing on this device, and their best runs. Personal bests only:
## kept in a small file under user:// - which a Web build keeps in the
## browser's own storage - and nothing here ever leaves the device.
##
## The name is written on the welcome's name tag (see TutorialCoach) and
## signs every best run it plays, so two people sharing a computer each see
## their own name against their own scores.
##
## In the view layer for the same reason TutorialProgress is: it touches disk,
## and the model and run layers never do (see test_architecture.gd).

## A test points this somewhere of its own so it never reads or clobbers the
## real player's profile.
static var path := "user://profile.cfg"

const MAX_NAME := 18
## How many best runs this device remembers.
const KEPT := 10
## What the boss calls you until you tell them otherwise.
const DEFAULT_NAME := "F&I Manager"

## What was written on the name tag - "" when nothing has been.
static func player_name() -> String:
	return str(_load().get_value("player", "name", ""))

## The name to address you by: yours, or the job's.
static func display_name() -> String:
	var n := player_name()
	return n if n != "" else DEFAULT_NAME

static func set_player_name(n: String) -> void:
	var file := _load()
	file.set_value("player", "name", n.strip_edges().left(MAX_NAME))
	file.save(path)

## The best runs on this device, best first: each {name, score, banked,
## fired, date, seq}.
static func bests() -> Array:
	return (_load().get_value("bests", "runs", []) as Array).duplicate(true)

## Whether a run has finished on this device yet. Asked rather than inferred
## from the score: a week can end below zero, so no number can mean "none".
static func has_best() -> bool:
	return not bests().is_empty()

## The best score on this device - 0 before the first finished run; ask
## has_best() first.
static func best_score() -> int:
	var runs := bests()
	return int(runs[0]["score"]) if not runs.is_empty() else 0

## Files a finished run under whoever is playing, and says where it placed:
## 1 is a new personal best, 0 is off the bottom of the list.
static func record_run(score: int, banked: int, fired: bool) -> int:
	var file := _load()
	var runs: Array = (file.get_value("bests", "runs", []) as Array).duplicate(true)
	# Counts every run ever filed here, so the one just filed can be found
	# again after sorting, and a tie can tell which came first.
	var seq := int(file.get_value("bests", "seq", 0)) + 1
	file.set_value("bests", "seq", seq)
	runs.append({"name": display_name(), "score": score, "banked": banked,
		"fired": fired, "date": Time.get_date_string_from_system(), "seq": seq})
	# Ties go to whoever got there first - a later run has to BEAT a score to
	# take its place, not merely match it.
	runs.sort_custom(func(a, b):
		if int(a["score"]) != int(b["score"]):
			return int(a["score"]) > int(b["score"])
		return int(a["seq"]) < int(b["seq"]))
	var rank := runs.find_custom(func(r): return int(r["seq"]) == seq) + 1
	file.set_value("bests", "runs", runs.slice(0, KEPT))
	file.save(path)
	return rank if rank <= KEPT else 0

## Which filed run was the latest - so a list can point out "this one".
static func last_seq() -> int:
	return int(_load().get_value("bests", "seq", 0))

## "Sep 25" from the ISO date a run was filed on.
static func short_date(iso: String) -> String:
	var parts := iso.split("-")
	if parts.size() < 3:
		return iso
	const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug",
		"Sep", "Oct", "Nov", "Dec"]
	var month := clampi(int(parts[1]), 1, 12)
	return "%s %d" % [MONTHS[month - 1], int(parts[2])]

static func reset() -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

static func _load() -> ConfigFile:
	var file := ConfigFile.new()
	file.load(path)   # a missing file is just an empty profile
	return file
