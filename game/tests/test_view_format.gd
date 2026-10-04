extends RefCounted
var h: Harness

func test_money_formats_with_commas_and_no_decimals() -> void:
	h.eq("sixteen hundred", Format.money(1600), "$1,600")
	h.eq("six hundred", Format.money(600), "$600")
	h.eq("a big number", Format.money(123456), "$123,456")
	h.eq("zero", Format.money(0), "$0")

func test_money_keeps_the_sign_on_a_loss() -> void:
	h.eq("a negative margin", Format.money(-300), "-$300")
