extends SceneTree
## Balance probe: what every product is worth by one flat formula - a value
## point per dollar of margin, plus EFFECT_VALUE per effect, divided by the ticks
## it takes to place - and whether the rarity tiers come out in order: Basic
## lowest, Preferred highest. Prints each product, each tier's spread, and every
## pair where a lower tier is worth as much as a higher one.
##
##     godot --headless --path game --script res://tools/product_values.gd
##     ... -- effect=500      (what one effect is worth, in value points)
##     ... -- bands=650-900,900-1000,1000-1100,1100-1300
##
## `bands` is the value each tier should land in, Basic first: it then prints the
## margin each product outside its band would need to land inside it (to the
## nearest $50 toward the inside), where each tier would sit after, and any pair
## of products for one interest that one would beat the other on both ticks and
## margin - which the pool's design rule forbids.

const EFFECT_VALUE := 300

func _init() -> void:
	var effect_value := EFFECT_VALUE
	var bands: Array = []
	for arg in OS.get_cmdline_user_args():
		var parts := arg.split("=")
		if parts.size() != 2:
			continue
		if parts[0] == "effect":
			effect_value = int(parts[1])
		elif parts[0] == "bands":
			for band in parts[1].split(","):
				var ends := band.split("-")
				bands.append([int(ends[0]), int(ends[1])])
	var pool: CardPool = load("res://data/card_pool.tres")
	var names := CardDef.Rarity.keys()
	var rows := []
	for c in pool.cards:
		if not c is ProductCardDef:
			continue
		var p := c as ProductCardDef
		var points := p.margin + effect_value * p.effects.size()
		rows.append({"name": p.display_name, "rarity": p.rarity, "ticks": p.ticks,
			"interest": p.interest.id, "margin": p.margin, "effects": p.effects.size(),
			"value": float(points) / maxi(1, p.ticks)})
	rows.sort_custom(func(a, b): return a["value"] > b["value"])
	print("%d points per effect" % effect_value)
	print("product|rarity|ticks|margin|effects|value")
	for r in rows:
		print("%s|%s|%d|%d|%d|%d" % [r["name"], names[r["rarity"]], r["ticks"], r["margin"],
			r["effects"], roundi(r["value"])])
	print("")
	_tiers(rows, names, "value")
	print("")
	print("a lower tier worth as much as a higher one:")
	var tied := 0
	for a in rows:
		for b in rows:
			if a["rarity"] < b["rarity"] and a["value"] >= b["value"]:
				tied += 1
	print("%d such pairs" % tied)
	if bands.size() == names.size():
		_propose(rows, names, bands, effect_value)
	quit(0)

## Each tier's lowest, mean and highest of `key`.
func _tiers(rows: Array, names: Array, key: String) -> void:
	print("tier|products|lowest|mean|highest")
	for tier in range(names.size()):
		var values := []
		for r in rows:
			if r["rarity"] == tier:
				values.append(r[key])
		if values.is_empty():
			continue
		var total := 0.0
		for v in values:
			total += v
		print("%s|%d|%d|%d|%d" % [names[tier], values.size(), roundi(values.min()),
			roundi(total / values.size()), roundi(values.max())])

func _propose(rows: Array, names: Array, bands: Array, effect_value: int) -> void:
	print("")
	print("to land every product inside its tier's band:")
	print("product|rarity|ticks|margin now|margin then|value now|value then")
	for r in rows:
		var band: Array = bands[r["rarity"]]
		var ticks := maxi(1, int(r["ticks"]))
		var margin: int = r["margin"]
		var v: float = r["value"]
		if v < band[0] or v > band[1]:
			var want: float = clampf(v, band[0], band[1]) * ticks - effect_value * int(r["effects"])
			margin = (ceili(want / 50.0) if v < band[0] else floori(want / 50.0)) * 50
			print("%s|%s|%d|%d|%d|%d|%d" % [r["name"], names[r["rarity"]], r["ticks"],
				r["margin"], margin, roundi(v),
				roundi(float(margin + effect_value * int(r["effects"])) / ticks)])
		r["new_margin"] = margin
		r["new_value"] = float(margin + effect_value * int(r["effects"])) / ticks
	print("")
	print("after:")
	_tiers(rows, names, "new_value")
	var beaten := 0
	for a in rows:
		for b in rows:
			if a != b and a["interest"] == b["interest"] and a["ticks"] <= b["ticks"] \
					and a["new_margin"] >= b["new_margin"] \
					and (a["ticks"] < b["ticks"] or a["new_margin"] > b["new_margin"]):
				beaten += 1
				print("%s beats %s on both ticks and margin" % [a["name"], b["name"]])
	print("%d products beaten on both axes within their interest" % beaten)
