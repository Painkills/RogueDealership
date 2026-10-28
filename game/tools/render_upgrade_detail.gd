extends SceneTree
## Renders what upgrading looks like, to look at rather than only check: the
## store with its upgrade row (user://upgrade_store.png) and the detail opened
## on one card (user://upgrade_detail.png). And a menu run's floor
## (user://menu_floor.png), for the cards' clocks and the menu's badges; then
## seated at a desk (user://seated.png) and with a hand card lifted over its
## tablet (user://seated_hover.png).
##
##   godot --path game --script res://tools/render_upgrade_detail.gd -- <card id>

func _init() -> void:
	_go.call_deferred()

func _shot(path: String) -> void:
	root.get_texture().get_image().save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))

func _go() -> void:
	var args := OS.get_cmdline_user_args()
	var id := StringName(args[0]) if not args.is_empty() else &"readroom"
	Telemetry.offline = true
	var run := RunState.new(load("res://data/shift_config.tres"),
		load("res://data/interests/interest_pool.tres"), load("res://data/card_pool.tres"),
		load("res://data/archetype_pool.tres"), 1)
	run.money = 5000
	var profile := ShiftProfile.new()
	profile.upgrades = 3
	var shop := Shop.new(run, profile)
	var inst := run.deck.add(run.card_pool.by_id(id))
	shop.upgrade_offers.push_front(inst.uid)
	shop.pass_on_free()                 # straight to the store
	var store = (load("res://scenes/shop.tscn") as PackedScene).instantiate()
	root.add_child(store)
	for _i in range(3):
		await process_frame
	store.setup(shop)
	for _i in range(10):
		await process_frame
	_shot("user://upgrade_store.png")
	(store.get_node(^"%Detail") as ShopCardDetail).show_card(shop, inst)
	for _i in range(10):
		await process_frame
	_shot("user://upgrade_detail.png")
	store.queue_free()

	var cfg := (load("res://data/shift_config.tres") as ShiftConfig).duplicate() as ShiftConfig
	cfg.products_on_board = true
	cfg.hand_min_products = 0
	var floor = (load("res://scenes/shift.tscn") as PackedScene).instantiate()
	root.add_child(floor)
	for _i in range(3):
		await process_frame
	var s := Shift.new(cfg, load("res://data/interests/interest_pool.tres"),
		load("res://data/card_pool.tres"), load("res://data/archetype_pool.tres"), 5)
	floor.setup(s, cfg.standing_start)
	for _i in range(30):
		await process_frame
	_shot("user://menu_floor.png")

	# Seated at the first desk, its tablet's empty well and the note on it - and
	# a hand card lifted over it, as hovering does.
	var key := InputEventKey.new()
	key.keycode = KEY_A
	key.pressed = true
	Input.parse_input_event(key)
	for _i in range(60):
		await process_frame
	_shot("user://seated.png")
	# And a request one tick from running out on whoever you are with, so the
	# lifted card's forecast has something to warn about.
	if s.at != null and s.chairs[s.at] != null:
		var d := Demand.new()
		d.display_name = "Wants an offer"
		d.telegraph = "OFFER ME"
		d.resolve = MakeAnOffer.new()
		s.chairs[s.at].demand = d
		s.chairs[s.at].demand_due_tick = s.tick + 1
		floor._render()
	var hand = floor.get(&"_hand_zone")
	if hand != null and not hand.cards.is_empty():
		var lifted = hand.cards[hand.cards.size() / 2]
		lifted.set_hovered()
		hand._hovered_card = lifted
		for _i in range(30):
			await process_frame
		_shot("user://seated_hover.png")
	quit()
