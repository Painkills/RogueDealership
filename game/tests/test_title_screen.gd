extends RefCounted
## The front door's one rule that needs no scene: when an installed copy of the game
## moves on to a newer build.
var h: Harness

const TitleScreen := preload("res://scripts/view/title_screen.gd")

func test_a_waiting_build_is_switched_to_from_the_menu() -> void:
	h.check("nothing waiting, nothing to do",
		not TitleScreen.switches_to_a_new_build(&"menu", false, false, true))
	h.check("waiting, on the menu, with nobody typing: switch",
		TitleScreen.switches_to_a_new_build(&"menu", false, true, true))

func test_check_for_updates_says_how_far_it_has_got() -> void:
	h.check("while the browser asks",
		TitleScreen.update_message("checking", false).begins_with("Checking"))
	h.check("while a new build downloads",
		TitleScreen.update_message("installing", false).contains("Downloading"))
	h.check("once it is ready, from the engine's word or the browser's",
		TitleScreen.update_message("installing", true).contains("switching")
			and TitleScreen.update_message("waiting", false).contains("switching"))
	h.check("nothing newer", TitleScreen.update_message("none", false).contains("latest"))
	h.check("and no connection", TitleScreen.update_message("error", false).contains("Couldn't"))

func test_it_never_switches_under_somebody() -> void:
	h.check("not with the name popup open",
		not TitleScreen.switches_to_a_new_build(&"menu", true, true, true))
	h.check("not on the high scores",
		not TitleScreen.switches_to_a_new_build(&"scores", false, true, true))
	h.check("not on the first-day welcome",
		not TitleScreen.switches_to_a_new_build(&"intro", false, true, true))
	# CONTINUE leaves the title on its menu page, put away behind the run - a
	# reload then would throw the shift you are working out from under you.
	h.check("not with the title put away behind a run",
		not TitleScreen.switches_to_a_new_build(&"menu", false, true, false))
