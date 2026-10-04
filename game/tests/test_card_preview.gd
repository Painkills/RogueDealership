extends RefCounted
## The shop's card preview. What it DRAWS is out of headless reach - same
## limit test_card_face.gd's own header states - but everything here is plain
## Label/Control data set by show_card()/clear(), readable without _draw().
var h: Harness

const SCENE := "res://scenes/cards/card_preview_2d.tscn"

func _instance() -> CardPreview2D:
	return (load(SCENE) as PackedScene).instantiate() as CardPreview2D

func _pool() -> CardPool:
	return load("res://data/card_pool.tres")

func _card(id: StringName, uid: int = 1) -> CardInstance:
	return CardInstance.new(_pool().by_id(id), uid)

func _front(c: CardPreview2D) -> Node:
	return c.get_node(^"SubViewport/CardFront/Margin/Column")

func test_show_card_works_on_a_card_that_was_never_added_to_any_deck() -> void:
	## Offer rows have no CardInstance yet - only a CardDef on the shelf - so
	## the preview has to accept a throwaway instance built just to look at,
	## uid -1 and all, without that uid ever meaning anything to the model.
	var c := _instance()
	var gap := _pool().by_id(&"gap")
	var throwaway := CardInstance.new(gap, -1)
	c.show_card(throwaway)
	h.eq("shows the card anyway",
		(_front(c).get_node(^"Header/NameLabel") as Label).text, gap.display_name)
	c.free()

func test_clear_erases_whatever_was_shown_before() -> void:
	var c := _instance()
	c.show_card(_card(&"vsc"))
	c.clear()
	var col := _front(c)
	h.eq("back to the invitation", (col.get_node(^"Header/NameLabel") as Label).text,
		"hover a card")
	h.eq("and nothing left over from the last card",
		(col.get_node(^"MarginLabel") as Label).text, "")
	h.eq("flavor text cleared too", (col.get_node(^"FlavorLabel") as Label).text, "")
	c.free()
