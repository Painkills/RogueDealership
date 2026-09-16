extends SceneTree
## Writes the real build identity into build_info.gd's LABEL constant, run
## by CI right before the Web export - see .github/workflows/deploy.yml.
##
## Godot itself does the writing rather than a shell sed call: the very
## first version of that CI step used bash-only ${VAR:0:7} substring syntax
## and failed outright on the container's actual shell, and the FIXED
## version (POSIX `cut`, otherwise identical) still shipped an unstamped
## "dev build" placeholder anyway - sed silently did nothing and a weak
## grep check let the step report success regardless. Two failures from the
## same root cause: this step's correctness depended on which shell the
## container happened to default to, which nothing in this project
## controls or can inspect (log downloads need admin rights this repo does
## not have). Godot is the one binary already guaranteed identical wherever
## this workflow runs it - so it does the string work, and args passed
## through -- carry GitHub's own values verbatim, no shell manipulation of
## them at all.

const PATH := "res://scripts/view/build_info.gd"
const PLACEHOLDER := 'const LABEL := "dev build"'

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("usage: stamp_build_info.gd -- <run_number> <full_sha>")
		quit(1)
		return
	var run_number: String = args[0]
	var short_sha: String = args[1].substr(0, 7)
	var label := "#%s - %s" % [run_number, short_sha]

	var content := FileAccess.get_file_as_string(PATH)
	if not content.contains(PLACEHOLDER):
		push_error('LABEL placeholder not found - expected exactly: %s' % PLACEHOLDER)
		quit(1)
		return
	var stamped := content.replace(PLACEHOLDER, 'const LABEL := "%s"' % label)

	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		push_error("could not open %s for writing: %s" % [PATH, FileAccess.get_open_error()])
		quit(1)
		return
	f.store_string(stamped)
	f.close()

	# Read it back rather than trust the write - the exact class of bug this
	# script exists to rule out.
	var verify := FileAccess.get_file_as_string(PATH)
	if not verify.contains('const LABEL := "%s"' % label):
		push_error("wrote %s but the file does not read it back" % PATH)
		quit(1)
		return
	print("stamped build_info.gd: %s" % label)
	quit(0)
