extends RefCounted
## The clocks on a customer's folder: one per card still working on them, with the
## ticks it has left.
var h: Harness

func _badges() -> LingerBadges:
	var b := LingerBadges.new()
	b.size = Vector2(170, 56)
	return b

func test_nothing_working_on_them_shows_nothing() -> void:
	var b := _badges()
	b.show_turns([] as Array[int])
	h.eq("hidden", b.visible, false)
	h.eq("no text", b.shown_text(), "")
	b.free()

func test_each_card_working_on_them_gets_its_ticks() -> void:
	var b := _badges()
	b.show_turns([4] as Array[int])
	h.eq("one clock", b.shown_text(), "4")
	h.eq("shown", b.visible, true)
	b.show_turns([4, 2] as Array[int])
	h.eq("soonest to end first", b.shown_text(), "2 4")
	b.free()

func test_more_than_fit_are_folded_into_a_count() -> void:
	var b := _badges()
	b.show_turns([4, 2, 3, 1] as Array[int])
	h.eq("two shown, the rest counted", b.shown_text(), "1 2 +2")
	b.free()
