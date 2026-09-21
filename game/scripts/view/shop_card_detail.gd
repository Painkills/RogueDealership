class_name ShopCardDetail extends PanelContainer
## The shop's one confirm-before-you-spend overlay, for both halves of the
## shop: buying from the shelf (show_shelf_card()) and editing something
## already in the deck - upgrade or drop (show_card()). One card here reads
## the same way everywhere it appears, which is the whole reason this is a
## single shared scene with two entry points rather than a second overlay
## that happens to look similar.
##
## A permanent, hidden-by-default overlay (the same shape ReportOverlay
## already uses for the end-of-shift card) rather than something built and
## freed per click - one node whose content changes, never a second thing
## to keep in sync with whether it should exist yet.

signal action_taken(res: Result)

var _title: Label
var _current: CardPreview2D
var _upgraded: CardPreview2D
var _upgraded_wrap: Control
var _buy_btn: Button
var _upgrade_btn: Button
var _remove_btn: Button
var _close_btn: Button
var _bound := false

var _shop: Shop
var _uid: int = -1
var _shelf_def: CardDef

func _ready() -> void:
	_bind()
	visible = false

func _bind() -> void:
	if _bound:
		return
	_bound = true
	_title = %DetailTitle
	_current = %CurrentPreview
	_upgraded = %UpgradedPreview
	_upgraded_wrap = %UpgradedWrap
	_buy_btn = %BuyButton
	_upgrade_btn = %UpgradeButton
	_remove_btn = %RemoveButton
	_close_btn = %CloseButton
	_buy_btn.pressed.connect(_on_buy_pressed)
	_upgrade_btn.pressed.connect(_on_upgrade_pressed)
	_remove_btn.pressed.connect(_on_remove_pressed)
	_close_btn.pressed.connect(func(): visible = false)

## shop: the live Shop, so prices and refusals come from the same source of
## truth the rest of the screen uses. def: a card on the SHELF - not owned
## yet, so there is nothing to compare it against and nothing to drop.
func show_shelf_card(shop: Shop, def: CardDef) -> void:
	_bind()
	_shop = shop
	_uid = -1
	_shelf_def = def
	_title.text = def.display_name
	# A throwaway instance, never touching the model - the same trick the
	# shelf row's own card face already uses for a card that is not owned yet.
	_current.show_card(CardInstance.new(def, -1))

	_upgraded_wrap.visible = false
	_buy_btn.visible = true
	_buy_btn.text = "buy %s" % Format.price(shop.buy_price(def))
	_upgrade_btn.visible = false
	_remove_btn.visible = false
	visible = true

## shop / inst: as above. inst is the DECK card that was clicked - must
## already be one of shop.upgrade_offers, since that is what put it in the
## browsable list in the first place.
func show_card(shop: Shop, inst: CardInstance) -> void:
	_bind()
	_shop = shop
	_uid = inst.uid
	_title.text = inst.card.display_name
	_current.show_card(inst)

	# A throwaway instance, never touching the model - the same trick the
	# shop's old offer-row preview already used for a card that is not owned
	# yet. Here it previews a state the OWNED card doesn't have yet either.
	var preview := CardInstance.new(inst.card, -1)
	preview.upgraded = true
	_upgraded.show_card(preview)
	_upgraded_wrap.visible = true

	_buy_btn.visible = false
	# Every card in upgrade_offers has a real upgrade to sell and is not
	# upgraded yet - Shop._roll_upgrade_offers() only ever puts a card here
	# on exactly those terms - so this is a sanity check, not a live gate.
	var can_upgrade := shop.upgrade_offers.has(inst.uid) and not inst.upgraded
	_upgrade_btn.visible = can_upgrade
	if can_upgrade:
		_upgrade_btn.text = "upgrade %s" % Format.price(shop.upgrade_price(inst))
	_remove_btn.visible = true
	_remove_btn.text = "remove %s" % Format.money(shop.remove_price())
	visible = true

func _on_buy_pressed() -> void:
	var res := _shop.buy(_shelf_def)
	if res.ok:
		visible = false
	action_taken.emit(res)

func _on_upgrade_pressed() -> void:
	var res := _shop.upgrade(_uid)
	if res.ok:
		visible = false
	action_taken.emit(res)

func _on_remove_pressed() -> void:
	var res := _shop.remove(_uid)
	if res.ok:
		visible = false
	action_taken.emit(res)
