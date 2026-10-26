extends SceneTree
## Prints the numbers balance is made of - every card's ticks, margin and
## effects, every archetype's patience and Line, every demand's fuse and cost,
## and the config they play against - in one place, to read or diff.
##
##   godot --headless --path game --script res://tools/dump_balance.gd

func _init() -> void:
	var cfg: ShiftConfig = load("res://data/shift_config.tres")
	print("== config")
	for k in ["shift_ticks", "hand_size", "menu_hand_size", "dig_ticks",
			"patience_per_sale", "patience_jitter", "arrival_patience_min_fraction",
			"appeal_step", "quota", "quota_growth", "leaving_soon_at",
			"standing_cost_per_walkout", "menu_cooldown_ticks"]:
		print("  %s = %s" % [k, str(cfg.get(k))])

	var pool: CardPool = load("res://data/card_pool.tres")
	print("\n== products  (ticks | margin -> upgraded | rarity | interest)")
	for d in pool.cards:
		if d is ProductCardDef:
			var p := d as ProductCardDef
			print("  %-28s t%d%s  $%d -> $%d  r%d  %s%s  %s" % [p.display_name, p.ticks,
				"/%d" % p.upgraded_ticks if p.upgraded_ticks >= 0 else "", p.margin,
				p.upgraded_margin, p.rarity, p.interest.id, "  STARTER" if p.starter else "",
				_fx(p.effects)])
	print("\n== supports  (ticks | rarity | effects => upgraded)")
	for d in pool.cards:
		if d is SupportCardDef:
			var s := d as SupportCardDef
			print("  %-26s t%d%s  r%d%s%s  %s  =>  %s" % [s.display_name, s.ticks,
				"/%d" % s.upgraded_ticks if s.upgraded_ticks >= 0 else "", s.rarity,
				"  STARTER x%d" % s.copies if s.starter else "",
				"  needs offer" if s.needs_offer else "",
				_fx(s.effects), _fx(s.upgraded_effects)])

	var arch: ArchetypePool = load("res://data/archetype_pool.tres")
	print("\n== archetypes  (patience/max | line +per sale | difficulty | hard)")
	for a in arch.archetypes:
		if a == null:
			continue
		print("  %-20s p%d/%d  line %d +%d  d%d%s%s" % [a.id, a.patience, a.max_patience,
			a.line, a.line_per_sale, a.difficulty, "  HARD" if a.hard else "",
			"  BOSS" if a.is_boss() else ""])
		for act in a.actions:
			if act == null:
				continue
			print("      action: %s - %s" % [act.display_name, _fx(act.effects)])
			for e in act.effects:
				var d = e.get("demand") if e != null else null
				if d is Demand:
					print("        asks: %s (%dt) - missed: %s" % [d.id, d.ticks, _fx(d.effects)])
		for m in a.moves:
			if m != null:
				print("      move: %s (%dt) - %s" % [m.id, m.ticks, _fx(m.effects)])
	quit()

func _fx(list: Array) -> String:
	var out: Array[String] = []
	for e in list:
		if e != null:
			var d: String = e.describe()
			out.append(d if d != "" else e.get_script().get_global_name())
	return ", ".join(out) if not out.is_empty() else "-"
