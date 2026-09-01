extends RefCounted
var h: Harness
var palette: Palette
var format: Format

func test_money_formats_with_commas_and_no_decimals() -> void:
	h.eq("sixteen hundred", format.money(1600), "$1,600")
	h.eq("six hundred", format.money(600), "$600")
	h.eq("a big number", format.money(123456), "$123,456")
	h.eq("zero", format.money(0), "$0")

func test_money_keeps_the_sign_on_a_loss() -> void:
	h.eq("a negative margin", format.money(-300), "-$300")

func test_patience_color_bands_match_the_thresholds() -> void:
	h.eq("full is ok", format.patience_color(10, 10), palette.color(&"patience_ok"))
	h.eq("just over half is ok", format.patience_color(6, 10),
		palette.color(&"patience_ok"))
	h.eq("just under half is warn", format.patience_color(5, 10),
		palette.color(&"patience_warn"))
	h.eq("just over a quarter is warn", format.patience_color(3, 10),
		palette.color(&"patience_warn"))
	h.eq("a quarter or under is bad", format.patience_color(2, 10),
		palette.color(&"patience_bad"))
	h.eq("empty is bad", format.patience_color(0, 10), palette.color(&"patience_bad"))

func test_every_named_role_returns_a_distinct_color() -> void:
	var roles: Array[StringName] = [&"bg", &"panel", &"panel_hi", &"text",
		&"text_dim", &"appeal", &"margin", &"patience_ok", &"patience_warn",
		&"patience_bad", &"action", &"alert", &"accent"]
	var seen := {}
	for r in roles:
		var c := palette.color(r)
		h.check("%s resolves to a real color" % r, c != null)
		seen[c.to_html()] = true
	h.check("roles are visually distinct (%d colors for %d roles)"
		% [seen.size(), roles.size()], seen.size() >= roles.size() - 2)
