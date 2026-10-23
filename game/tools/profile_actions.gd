extends SceneTree
## Times what the floor does on the moves a shift is made of - a card played, a
## product placed, an offer, a signing - in a real window: how long the move
## itself takes to apply and render, and the slowest frames after it while the
## table animates. Classic and menu runs both. A diagnostic, not a check.
##
##   godot --path game --script res://tools/profile_actions.gd

var _controller

func _init() -> void:
	_go.call_deferred()

func _go() -> void:
	seed(4242)
	Telemetry.offline = true
	_controller = (load("res://scenes/shift.tscn") as PackedScene).instantiate()
	root.add_child(_controller)
	for _i in range(5):
		await process_frame
	for menu in [false, true]:
		print("\n== %s" % ("menu" if menu else "classic"))
		await _profile(menu)
	quit()

func _shift(menu: bool) -> Shift:
	var cfg := (load("res://data/shift_config.tres") as ShiftConfig).duplicate() as ShiftConfig
	if menu:
		cfg.products_on_board = true
		cfg.hand_min_products = 0
	return Shift.new(cfg, load("res://data/interests/interest_pool.tres"),
		load("res://data/card_pool.tres"), load("res://data/archetype_pool.tres"), 77)

func _profile(menu: bool) -> void:
	var s := _shift(menu)
	var t := Time.get_ticks_usec()
	_controller.setup(s, s.cfg.standing_start)
	print("setup               %6.1f ms" % ((Time.get_ticks_usec() - t) / 1000.0))
	await _frames("after setup")
	var c: Customer = s.chairs[0]
	for round in range(2):
		# A product on the table.
		var product: CardInstance = null
		for inst in (s.board if menu else s.hand):
			if inst.is_product() and not c.owns(inst.card.id) and c.accepts(inst.card as ProductCardDef) \
					and (not menu or s.board_available(inst)):
				product = inst
				break
		if product == null:
			print("no product to place")
			return
		await _time("place", func():
			_controller._apply(s.place_board(product.card.id) if menu \
				else s.play_card(s.hand.find(product))))
		# A support card on it.
		var support := -1
		for i in range(s.hand.size()):
			if not s.hand[i].is_product():
				support = i
				break
		if support >= 0:
			await _time("support card", func(): _controller._apply(s.play_card(support)))
		if c.offer != null:
			c.line = mini(c.line, c.offer.appeal)
			await _time("offer (sale)", func(): _controller._on_offer())
	await _time("close (signing)", func(): _controller._on_close())
	# What re-renders every frame whether or not anything changed.
	var always := {}
	var pixels := 0
	for vp in root.find_children("*", "SubViewport", true, false):
		var v := vp as SubViewport
		if v.render_target_update_mode == SubViewport.UPDATE_ALWAYS:
			var key := "%s (%dx%d)" % [v.get_parent().get_class() if v.get_parent() else "?", v.size.x, v.size.y]
			always[key] = int(always.get(key, 0)) + 1
			pixels += v.size.x * v.size.y
	print("SubViewports re-rendering every frame: %s  (%.1f Mpx a frame)" % [always, pixels / 1e6])

func _time(what: String, act: Callable) -> void:
	var t := Time.get_ticks_usec()
	act.call()
	print("%-20s%6.1f ms" % [what, (Time.get_ticks_usec() - t) / 1000.0])
	await _frames(what)

## The next second of frames: the slowest, and the average.
func _frames(what: String) -> void:
	var worst := 0.0
	var total := 0.0
	var n := 60
	var last := Time.get_ticks_usec()
	for _i in range(n):
		await process_frame
		var now := Time.get_ticks_usec()
		var ms := (now - last) / 1000.0
		last = now
		worst = maxf(worst, ms)
		total += ms
	print("   frames after %-16s worst %5.1f ms  mean %5.1f ms" % [what, worst, total / n])
