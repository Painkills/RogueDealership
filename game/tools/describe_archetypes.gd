extends SceneTree
## Prints one archetype's whole chain - action, trigger, effects, and (for a
## RaiseDemand effect) the demand it raises: fuse, resolve, cost, relief,
## dialogue tags - flattened into one readable block instead of the 2-3 files
## you currently have to open in the Inspector to piece the same picture
## together (the archetype's own .tres, then data/demands/<id>.tres, then
## whichever DemandResolve subclass file to know what "resolve" means).
##
## Read-only: this never writes anything, and changing nothing here changes
## how the game runs. It exists purely so "what does Karen do" is one command
## instead of three files.
##
##     godot --headless --path game --script res://tools/describe_archetypes.gd
##     godot --headless --path game --script res://tools/describe_archetypes.gd -- karen
##
## With no argument, every archetype prints. With one, only the archetype
## whose id matches (case-insensitive) does.

func _init() -> void:
	var pool: ArchetypePool = load("res://data/archetype_pool.tres")
	var args := OS.get_cmdline_user_args()
	var wanted := args[0].to_lower() if not args.is_empty() else ""

	var shown := 0
	for a in pool.archetypes:
		if not wanted.is_empty() and String(a.id).to_lower() != wanted:
			continue
		_print_archetype(a)
		shown += 1

	if shown == 0:
		var ids: Array[String] = []
		for a in pool.archetypes:
			ids.append(String(a.id))
		printerr("no archetype matches '%s' - known ids: %s" % [wanted, ", ".join(ids)])
		quit(1)
		return

	quit(0)

func _print_archetype(a: CustomerArchetype) -> void:
	print("\n==== %s (%s) ====" % [a.display_name, a.id])
	print("pattern: %s" % a.pattern)
	print("tell: %s" % a.tell)
	print("line=%d patience=%d line_per_sale=%d combo_step=%s demands_category=%s min_shift=%d"
		% [a.line, a.patience, a.line_per_sale, a.combo_step, a.demands_category, a.min_shift])
	print("top interests: %s" % _interest_names(a.top_interests))
	print("bottom interests: %s" % _interest_names(a.bottom_interests))

	if a.actions.is_empty():
		print("actions: (none)")
		return

	print("actions:")
	for act in a.actions:
		_print_action(act)

func _interest_names(interests: Array[Interest]) -> String:
	if interests.is_empty():
		return "(none)"
	var names: Array[String] = []
	for i in interests:
		names.append(i.display_name)
	return ", ".join(names)

func _print_action(act: CustomerAction) -> void:
	print("  [%s] %s (cooldown %d)" % [act.id, act.display_name, act.cooldown])
	print("    tell: %s" % act.tell)
	print("    dialogue_tags: %s" % _tag_list(act.dialogue_tags))
	print("    trigger: %s" % (act.trigger.describe() if act.trigger else "(none)"))

	if act.effects.is_empty():
		print("    effects: (none)")
		return

	print("    effects:")
	for e in act.effects:
		print("      - %s" % e.describe())
		if e is RaiseDemand and e.demand != null:
			_print_demand(e.demand)

func _print_demand(d: Demand) -> void:
	print("        demand '%s' (%s): fuse %d ticks, resolve=%s"
		% [d.id, d.display_name, d.ticks,
			d.resolve.describe() if d.resolve else "(none)"])
	print("          cost if ignored: %s" % _effect_list(d.effects))
	print("          relief if met:   %s" % _effect_list(d.relief))
	print("          dialogue: met=%s missed=%s"
		% [_tag_list(d.dialogue_tags_met), _tag_list(d.dialogue_tags_missed)])

func _effect_list(effects: Array[Effect]) -> String:
	if effects.is_empty():
		return "(none)"
	var parts: Array[String] = []
	for e in effects:
		parts.append(e.describe())
	return ", ".join(parts)

func _tag_list(tags: Array[StringName]) -> String:
	if tags.is_empty():
		return "(none)"
	var parts: Array[String] = []
	for t in tags:
		parts.append(String(t))
	return ", ".join(parts)
