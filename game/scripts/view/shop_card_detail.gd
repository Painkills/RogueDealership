class_name ShopCardDetail extends PanelContainer
## The shop's one confirm-before-you-take-it overlay, for every card the store
## shows: the free card (show_free_card()), the card for sale
## (show_shelf_card()), and one of your own to upgrade or drop (show_card()).
## One card here reads the same way everywhere it appears, which is the whole
## reason this is a single shared scene with three entry points rather than
## more overlays that happen to look similar.
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
var _take_btn: Button
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
	_take_btn = %TakeButton
	_buy_btn = %BuyButton
	_upgrade_btn = %UpgradeButton
	_remove_btn = %RemoveButton
	_close_btn = %CloseButton
	_take_btn.pressed.connect(_on_take_pressed)
	_buy_btn.pressed.connect(_on_buy_pressed)
	_upgrade_btn.pressed.connect(_on_upgrade_pressed)
	_remove_btn.pressed.connect(_on_remove_pressed)
	_close_btn.pressed.connect(func(): visible = false)

## The card on the house. Nothing to pay and nothing to compare it against -
## just the card, and whether you want it.
func show_free_card(shop: Shop, def: CardDef) -> void:
	_show_unowned(shop, def)
	_take_btn.visible = true
	visible = true

## shop: the live Shop, so prices and refusals come from the same source of
## truth the rest of the screen uses. def: the card for SALE - not owned yet,
## so there is nothing to compare it against and nothing to drop.
func show_shelf_card(shop: Shop, def: CardDef) -> void:
	_show_unowned(shop, def)
	_buy_btn.visible = true
	_buy_btn.text = "buy %s" % Format.price(shop.buy_price(def))
	visible = true

func _show_unowned(shop: Shop, def: CardDef) -> void:
	_bind()
	_shop = shop
	_uid = -1
	_shelf_def = def
	_title.text = def.display_name
	# A throwaway instance, never touching the model - the same trick the
	# store's own card faces use for a card that is not owned yet.
	_current.show_card(CardInstance.new(def, -1))
	_upgraded_wrap.visible = false
	_take_btn.visible = false
	_buy_btn.visible = false
	_upgrade_btn.visible = false
	_remove_btn.visible = false

## shop / inst: as above. inst is one of YOUR cards - one of
## shop.upgrade_offers, since that is what put it on the page at all.
func show_card(shop: Shop, inst: CardInstance) -> void:
	_bind()
	_shop = shop
	_uid = inst.uid
	_title.text = inst.card.display_name
	_current.show_card(inst)

	# A throwaway instance, never touching the model - it previews a state the
	# OWNED card does not have yet either.
	var preview := CardInstance.new(inst.card, -1)
	preview.upgraded = true
	_upgraded.show_card(preview)
	_upgraded_wrap.visible = true

	_take_btn.visible = false
	_buy_btn.visible = false
	# Offered, not upgraded yet, and the visit's one upgrade not spent on
	# another card - the button offers exactly what Shop.upgrade() would do.
	var can_upgrade := shop.upgrade_offers.has(inst.uid) and not inst.upgraded \
		and shop.upgrades_left > 0
	_upgrade_btn.visible = can_upgrade
	if can_upgrade:
		_upgrade_btn.text = "upgrade %s" % Format.price(shop.upgrade_price(inst))
	_remove_btn.visible = true
	_remove_btn.text = "remove %s" % Format.money(shop.remove_price())
	visible = true

func _on_take_pressed() -> void:
	_close_on(_shop.take_free())

func _on_buy_pressed() -> void:
	_close_on(_shop.buy(_shelf_def))

func _on_upgrade_pressed() -> void:
	_close_on(_shop.upgrade(_uid))

func _on_remove_pressed() -> void:
	_close_on(_shop.remove(_uid))

## Done if it went through; left open if refused, so the reason is read with
## the card it is about still in front of you.
func _close_on(res: Result) -> void:
	if res.ok:
		visible = false
	action_taken.emit(res)
