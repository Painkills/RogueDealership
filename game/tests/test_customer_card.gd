extends RefCounted
## CustomerCard3D: a customer's folder, as the thing you read across the floor
## to decide who needs you next. What is on it is plain data on its nodes, so
## it is checkable without ever rendering it; whether it READS is for eyes.
var h: Harness

const SCENE := "res://scenes/cards/customer_card_3d.tscn"
const CFG := {"appeal_step": 5, "line_per_sale": 3, "leaving_soon_at": 4}

func _card() -> CustomerCard3D:
	return (load(SCENE) as PackedScene).instantiate() as CustomerCard3D

func _customer(patience: int, max_patience: int) -> Customer:
	var interests: InterestPool = load("res://data/interests/interest_pool.tres")
	var a := (load("res://data/archetype_pool.tres") as ArchetypePool).by_id(&"easygoing")
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	return Customer.new("A", "Test Person", a, Customer.make_ranks(a, interests, rng, 0.0),
		patience, max_patience, CFG, interests)

func test_the_patience_meter_is_a_box_the_bar_fills() -> void:
	## "Patience meter needs to have a border or container so you can visually
	## see how much patience the customer has lost." The bar fills a frame as
	## long as their patience can ever be, so what is gone is an empty stretch
	## inside an edge, not a bar that simply got shorter.
	var card := _card()
	card.setup(_customer(6, 16))
	var frame := card._patience_frame as PanelContainer
	h.check("the bar sits inside a frame", card._patience_bar.get_parent() == frame)
	var style := frame.get_theme_stylebox("panel") as StyleBoxFlat
	h.check("with an edge you can see (%d px, %s)" % [style.border_width_top, style.border_color],
		style.border_width_top >= 3 and style.border_width_left >= 3
			and style.border_color == Palette.color(&"neutral_1"))
	h.check("around a trough the colour of neither the folder nor the fill (%s)" % style.bg_color,
		style.bg_color == Palette.color(&"paper_shade")
			and style.bg_color != Palette.color(&"manila"))
	h.check("and the fill sits inside the edge, not on it (%d px in)"
		% int(style.get_margin(SIDE_LEFT)), style.get_margin(SIDE_LEFT) > style.border_width_left)
	h.check("the bar draws no trough of its own over the frame's",
		card._patience_bar.get_theme_stylebox("background") is StyleBoxEmpty)
	h.eq("the frame is as long as their patience can ever be", card._patience_bar.max_value, 16.0)
	h.eq("and filled to what is left of it", card._patience_bar.value, 6.0)
	h.check("so both are showing", frame.visible and card._patience_bar.visible)
	card.setup(null)
	h.check("an empty chair shows no meter at all, not an empty one", not frame.visible)
	card.free()
