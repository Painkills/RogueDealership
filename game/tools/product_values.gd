extends SceneTree
## Balance probe: what every product is worth by one flat formula - a value
## point per dollar of margin, plus what its effects are worth (PATIENCE_VALUE a
## point of patience, APPEAL_VALUE a point of appeal, LINE_VALUE a point the Line
## drops), over the ticks it takes to place - and whether the rarity tiers come
## out in order: Basic lowest, Preferred highest. Prints each product, each tier's
## spread, and how many pairs have a lower tier worth as much as a higher one.
##
##     godot --headless --path game --script res://tools/product_values.gd
##     ... -- patience=100 appeal=200 line=200      (what a point is worth)
##     ... -- bands=650-950,1000-1100,1150-1250,1300-1500
##
## `bands` is the value each tier should land in, Basic first, ends included - so a
## band that stops at 950 and the next that starts at 1000 leave nothing between
## them to overlap in. A 3-tick product is a big commitment, so it has to land in
## the upper half of its band. With bands it prints the margin each product
## outside its band would need to land inside it (to the nearest $50 toward the
## inside, as MARGIN|id|margin lines), where each tier would sit after, and any pair
## of products for one interest where one would beat the other on both ticks and
## margin - which the pool's design rule forbids.

const PATIENCE_VALUE := 100
const APPEAL_VALUE := 200
const LINE_VALUE := 200
## From this many ticks a product is a big commitment: see above.
const BIG_COMMITMENT := 3

var _patience := PATIENCE_VALUE
var _appeal := APPEAL_VALUE
var _line := LINE_VALUE

func _init() -> void:
	var bands: Array = []
	for arg in OS.get_cmdline_user_args():
		var parts := arg.split("=")
		if parts.size() != 2:
			continue
		match parts[0]:
			"patience": _patience = int(parts[1])
			"appeal": _appeal = int(parts[1])
			"line": _line = int(parts[1])
			"bands":
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
		var worth := _worth(p)
		rows.append({"id": p.id, "name": p.display_name, "rarity": p.rarity, "ticks": p.ticks,
			"interest": p.interest.id, "margin": p.margin, "worth": worth,
			"value": float(p.margin + worth) / maxi(1, p.ticks)})
	rows.sort_custom(func(a, b): return a["value"] > b["value"])
	print("a point of patience %d, of appeal %d, of Line dropped %d" % [_patience, _appeal, _line])
	print("product|rarity|ticks|margin|effects worth|value")
	for r in rows:
		print("%s|%s|%d|%d|%d|%d" % [r["name"], names[r["rarity"]], r["ticks"], r["margin"],
			r["worth"], roundi(r["value"])])
	print("")
	_tiers(rows, names, "value")
	var tied := 0
	for a in rows:
		for b in rows:
			if a["rarity"] < b["rarity"] and a["value"] >= b["value"]:
				tied += 1
	print("%d pairs where a lower tier is worth as much as a higher one" % tied)
	if bands.size() == names.size():
		_propose(rows, names, bands)
	quit(0)

## What a product's effects are worth in all, by the price of a point of each kind.
## An effect of a kind nobody has priced is worth nothing, and says so.
func _worth(p: ProductCardDef) -> int:
	var total := 0
	for e in p.effects:
		if e is ChangePatience:
			total += _patience * e.amount
		elif e is ChangeAppeal:
			total += _appeal * e.amount
		elif e is ChangeLine:
			total += _line * -e.amount
		else:
			print("UNPRICED effect on %s: %s" % [p.display_name, e.describe()])
	return total

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

func _propose(rows: Array, names: Array, bands: Array) -> void:
	print("")
	print("to land every product inside its tier's band:")
	print("product|rarity|ticks|margin now|margin then|value now|value then")
	for r in rows:
		var band: Array = bands[r["rarity"]]
		var ticks := maxi(1, int(r["ticks"]))
		var margin: int = r["margin"]
		var v: float = r["value"]
		var low: float = band[0]
		if ticks >= BIG_COMMITMENT:
			low = (band[0] + band[1]) / 2.0
		if v < low or v > band[1]:
			var want: float = clampf(v, low, band[1]) * ticks - int(r["worth"])
			margin = (ceili(want / 50.0) if v < low else floori(want / 50.0)) * 50
			print("%s|%s|%d|%d|%d|%d|%d" % [r["name"], names[r["rarity"]], r["ticks"],
				r["margin"], margin, roundi(v), roundi(float(margin + int(r["worth"])) / ticks)])
			print("MARGIN|%s|%d" % [r["id"], margin])
		r["new_margin"] = margin
		r["new_value"] = float(margin + int(r["worth"])) / ticks
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
