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

func test_the_scene_wires_a_viewport_straight_into_a_texture_rect() -> void:
	var c := _instance()
	c._bind()   # _ready() never fires outside a live tree; bind explicitly
	var vp := c.get_node_or_null(^"SubViewport") as SubViewport
	h.check("there is a viewport", vp != null)
	h.eq("sized to the card's own aspect", vp.size, CardPreview2D.FRONT_SIZE)
	h.check("it does not render 3D it will never contain", vp.disable_3d)
	var tex := c.get_node_or_null(^"TextureRect") as TextureRect
	h.check("there is a texture rect", tex != null)
	h.eq("showing exactly the viewport's own texture",
		tex.texture, vp.get_texture())
	c.free()

func test_it_starts_blank_with_an_invitation_rather_than_editor_placeholder_text() -> void:
	## Without this, a freshly-instanced preview would sit there showing
	## card_front_2d.tscn's raw editor placeholders ("Customer Name", "12
	## SHORT") - a half-populated card that reads as broken, not as "nothing is
	## hovered yet".
	var c := _instance()
	c.clear()   # _ready() never fires outside a live tree; call it explicitly
	var col := _front(c)
	h.eq("no invented product name", (col.get_node(^"Header/NameLabel") as Label).text,
		"hover a card")
	h.eq("no invented cost", (col.get_node(^"Header/CostLabel") as Label).text, "")
	h.eq("no invented margin", (col.get_node(^"MarginLabel") as Label).text, "")
	c.free()

func test_show_card_writes_a_products_words_onto_the_face() -> void:
	var c := _instance()
	var vsc := _pool().by_id(&"vsc") as ProductCardDef
	c.show_card(_card(&"vsc"))
	var col := _front(c)
	h.eq("name", (col.get_node(^"Header/NameLabel") as Label).text, vsc.display_name)
	h.eq("kind", (col.get_node(^"KindRow/KindLabel") as Label).text, "PRODUCT")
	h.eq("what need it answers", (col.get_node(^"BodyRow/BodyLabel") as Label).text,
		vsc.interest.category.display_name + " . " + vsc.interest.display_name)
	h.eq("margin, formatted like every other surface formats money",
		(col.get_node(^"MarginLabel") as Label).text, Format.money(vsc.margin))
	var icon := col.get_node(^"BodyRow/BodyIcon") as CategoryIconControl
	h.check("carries the same category badge every other card uses", icon.visible)
	h.eq("naming the product's own category", icon._category_id,
		vsc.interest.category.id)
	c.free()

func test_a_products_badge_shares_the_products_own_color() -> void:
	## No colored border - the Background stays the same neutral panel color
	## every card uses, and it is the KindRow badge above the name that
	## carries the type's color instead.
	var c := _instance()
	c.show_card(_card(&"vsc"))
	var col := _front(c)
	h.eq("the background stays neutral, not tinted",
		(c.get_node(^"SubViewport/CardFront/Background") as ColorRect).color,
		Palette.color(&"panel"))
	var icon := col.get_node(^"KindRow/KindIcon") as CardTypeIconControl
	h.check("the type badge says product too", icon._is_product)
	c.free()

func test_a_support_cards_badge_shares_the_support_color() -> void:
	var c := _instance()
	c.show_card(_card(&"discount"))
	var col := _front(c)
	h.eq("the background stays neutral, not tinted",
		(c.get_node(^"SubViewport/CardFront/Background") as ColorRect).color,
		Palette.color(&"panel"))
	var icon := col.get_node(^"KindRow/KindIcon") as CardTypeIconControl
	h.check("the type badge says support too", not icon._is_product)
	c.free()

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

func test_an_upgraded_instance_shows_the_upgraded_numbers() -> void:
	var c := _instance()
	var base := _card(&"vsc")
	c.show_card(base)
	var unupgraded: String = (_front(c).get_node(^"MarginLabel") as Label).text

	var inst := _card(&"vsc")
	inst.upgraded = true
	c.show_card(inst)
	var upgraded: String = (_front(c).get_node(^"MarginLabel") as Label).text
	h.check("upgraded margin actually differs from the base one",
		upgraded != unupgraded)
	h.eq("and matches the card's own upgraded margin, correctly formatted",
		upgraded, Format.money(inst.margin()))
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
	c.free()
