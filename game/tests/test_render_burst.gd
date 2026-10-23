extends RefCounted
## A card's picture is rendered for a few frames when it changes and then left
## alone (RenderBurst) - never every frame, which was most of a phone's frame on
## the floor - and a card the table sets up again unchanged is not re-rendered.
var h: Harness

func _settle(host: Node) -> void:
	var burst := host.get_node_or_null(^"RenderBurst") as RenderBurst
	for _i in range(RenderBurst.FRAMES):
		burst._process(0.0)

func test_a_change_renders_for_a_few_frames_then_stops() -> void:
	var host := Node.new()
	var vp := SubViewport.new()
	host.add_child(vp)
	RenderBurst.kick(host, [vp])
	h.eq("rendering while it settles", vp.render_target_update_mode, SubViewport.UPDATE_ALWAYS)
	h.check("and says so", RenderBurst.busy(host))
	_settle(host)
	h.eq("then it stops", vp.render_target_update_mode, SubViewport.UPDATE_DISABLED)
	h.check("and is done", not RenderBurst.busy(host))
	h.eq("the helper is not one of the host's children",
		host.get_children().size(), 1)
	host.free()

func _any_card() -> CardDef:
	return (load("res://data/card_pool.tres") as CardPool).cards[0]

func test_a_card_on_the_table_is_not_rendered_every_frame() -> void:
	var face := (load("res://scenes/cards/card_face_3d.tscn") as PackedScene).instantiate() as CardFace3D
	var inst := CardInstance.new(_any_card(), 1)
	face.setup(inst)
	_settle(face)
	var front := face.get_node(^"FrontViewport") as SubViewport
	var back := face.get_node(^"BackViewport") as SubViewport
	h.eq("its face, once settled, is left as it is", front.render_target_update_mode,
		SubViewport.UPDATE_DISABLED)
	h.eq("and its back", back.render_target_update_mode, SubViewport.UPDATE_DISABLED)
	face.setup(inst)
	h.check("set up again unchanged, it is not rendered again", not RenderBurst.busy(face))
	inst.upgraded = true
	face.setup(inst)
	h.check("changed, it is", RenderBurst.busy(face)
		and front.render_target_update_mode == SubViewport.UPDATE_ALWAYS)
	face.free()

func test_a_store_card_is_rendered_when_shown_and_then_left() -> void:
	var card := (load("res://scenes/cards/shop_card_button.tscn") as PackedScene).instantiate() as ShopCardButton
	card._bind()
	var vp := card.get_node(^"SubViewport") as SubViewport
	h.eq("nothing drawn before it has a card", vp.render_target_update_mode,
		SubViewport.UPDATE_DISABLED)
	card.show_card(CardInstance.new(_any_card(), 1))
	h.check("shown, it renders", RenderBurst.busy(card))
	_settle(card)
	h.eq("then it is left as it is", vp.render_target_update_mode, SubViewport.UPDATE_DISABLED)
	card.free()
