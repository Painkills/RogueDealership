extends RefCounted
## The front door's one rule that needs no scene: when an installed copy of the game
## moves on to a newer build.
var h: Harness

const TitleScreen := preload("res://scripts/view/title_screen.gd")

func test_a_waiting_build_is_switched_to_from_the_menu() -> void:
	h.check("nothing waiting, nothing to do",
		not TitleScreen.switches_to_a_new_build(&"menu", false, false))
	h.check("waiting, on the menu, with nobody typing: switch",
		TitleScreen.switches_to_a_new_build(&"menu", false, true))

func test_it_never_switches_under_somebody() -> void:
	h.check("not with the name popup open",
		not TitleScreen.switches_to_a_new_build(&"menu", true, true))
	h.check("not on the high scores",
		not TitleScreen.switches_to_a_new_build(&"scores", false, true))
	h.check("not on the first-day welcome",
		not TitleScreen.switches_to_a_new_build(&"intro", false, true))
