class_name ShopCardDetail extends PanelContainer
## The deck browser's "click to open": what this card would look like
## upgraded, next to what it is now, with the two things Shop actually lets
## you do to a card already in your deck - upgrade it, or drop it.
##
## A permanent, hidden-by-default overlay (the same shape ReportOverlay
## already uses for the end-of-shift card) rather than something built and
## freed per click - one node whose content changes, never a second thing
## to keep in sync with whether it should exist yet.

signal action_taken(res: Result)

var _title: Label
var _current: CardPreview2D
var _upgraded: CardPreview2D
var _upgrade_btn: Button
var _remove_btn: Button
var _close_btn: Button
var _bound := false

var _shop: Shop
var _uid: int = -1

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
	_upgrade_btn = %UpgradeButton
	_remove_btn = %RemoveButton
	_close_btn = %CloseButton
	_upgrade_btn.pressed.connect(_on_upgrade_pressed)
	_remove_btn.pressed.connect(_on_remove_pressed)
	_close_btn.pressed.connect(func(): visible = false)

## shop: the live Shop, so prices and refusals come from the same source of
## truth the rest of the screen uses. inst: the DECK card that was clicked -
## must already be one of shop.upgrade_offers, since that is what put it in
## the browsable list in the first place.
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

	# Every card in upgrade_offers has a real upgrade to sell and is not
	# upgraded yet - Shop._roll_upgrade_offers() only ever puts a card here
	# on exactly those terms - so this is a sanity check, not a live gate.
	var can_upgrade := shop.upgrade_offers.has(inst.uid) and not inst.upgraded
	_upgrade_btn.visible = can_upgrade
	if can_upgrade:
		_upgrade_btn.text = "upgrade %s" % Format.money(shop.upgrade_price(inst))
	_remove_btn.text = "remove %s" % Format.money(shop.remove_price())
	visible = true

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
