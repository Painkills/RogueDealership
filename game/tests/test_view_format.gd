extends RefCounted
var h: Harness

func test_money_formats_with_commas_and_no_decimals() -> void:
	h.eq("sixteen hundred", Format.money(1600), "$1,600")
	h.eq("six hundred", Format.money(600), "$600")
	h.eq("a big number", Format.money(123456), "$123,456")
	h.eq("zero", Format.money(0), "$0")

func test_a_multiplier_rounds_the_way_its_percent_does() -> void:
	## A +12.5% step reads "+13%", so its multiplier must read x1.13, not x1.12.
	h.eq("half rounds up", Format.multiplier(1.125), "×1.13")
	h.eq("and agrees with the step's own percent", Format.multiplier(1.0 + 0.125),
		"×1.%d" % roundi(0.125 * 100))
	h.eq("a plain one", Format.multiplier(1.5), "×1.50")

func test_money_keeps_the_sign_on_a_loss() -> void:
	h.eq("a negative margin", Format.money(-300), "-$300")
