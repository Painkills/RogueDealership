extends PanelContainer
## The whole deck, browsable - not just ShelfRow/DeckRow's own random daily
## subset. Read-only: nothing here is clickable beyond the card face itself,
## the same "one permanent overlay, toggled visible" shape ShopCardDetail
## already uses, so there is never a second node to keep hidden and synced
## with whether it should exist yet.

@onready var _title: Label = %DeckViewerTitle
@onready var _grid: GridContainer = %DeckGrid
@onready var _close: Button = %DeckCloseButton

func _ready() -> void:
	_close.pressed.connect(func(): visible = false)

func show_deck(run: RunState) -> void:
	_title.text = "YOUR DECK (%d cards)" % run.deck.cards.size()

	# remove_child() first, same reason shop_screen.gd's own _render() does:
	# queue_free() alone leaves a node in get_children() until the next idle
	# frame, and this can be reopened within the same frame it was last built.
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()

	var cards := run.deck.cards.duplicate()
	# Products first, then support - each group alphabetical - so a deck of
	# fifteen-plus cards reads as something you can actually scan rather than
	# whatever order they happened to enter the deck in.
	cards.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
		if a.is_product() != b.is_product():
			return a.is_product()
		return a.card.display_name < b.card.display_name)

	for inst in cards:
		var card: ShopCardButton = (load("res://scenes/cards/shop_card_button.tscn") \
			as PackedScene).instantiate()
		_grid.add_child(card)
		card.show_card(inst)

	visible = true
