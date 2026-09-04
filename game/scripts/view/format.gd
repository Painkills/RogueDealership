class_name Format extends RefCounted
## Pure display formatting - no model knowledge, no state. Static methods,
## not an autoload, for the same reason as Palette (see palette.gd).

static func money(n: int) -> String:
	var minus := "-" if n < 0 else ""
	return "%s$%s" % [minus, _grouped(abs(n))]

static func patience_color(cur: int, max_val: int) -> Color:
	var top: int = max(1, max_val)
	var frac: float = float(cur) / float(top)
	if frac > 0.5:
		return Palette.color(&"patience_ok")
	if frac > 0.25:
		return Palette.color(&"patience_warn")
	return Palette.color(&"patience_bad")

static func _grouped(n: int) -> String:
	var s := str(n)
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i != 0:
			out = "," + out
	return out
