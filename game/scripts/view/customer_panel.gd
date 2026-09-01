extends PanelContainer

signal offer_pressed
signal close_pressed
signal drop_pressed

const ORDINALS := ["", "1st", "2nd", "3rd", "4th", "5th", "6th", "7th", "8th", "9th"]

@onready var _header: Label = %HeaderLabel
@onready var _line: Label = %LineLabel
@onready var _unsigned_row: HBoxContainer = %UnsignedRow
@onready var _offer_box: PanelContainer = %OfferBox
@onready var _offer_name: Label = %OfferNameLabel
@onready var _offer_category: Label = %OfferCategoryLabel
@onready var _offer_margin: Label = %OfferMarginLabel
@onready var _appeal_bar: Control = %AppealBar
@onready var _gap: Label = %GapLabel
@onready var _known: Label = %KnownLabel
@onready var _offer_btn: Button = %OfferButton
@onready var _drop_btn: Button = %DropButton
@onready var _close_btn: Button = %CloseButton

var _customer

func _ready() -> void:
	_offer_btn.pressed.connect(func(): offer_pressed.emit())
	_drop_btn.pressed.connect(func(): drop_pressed.emit())
	_close_btn.pressed.connect(func(): close_pressed.emit())

func setup(customer, forced_band: String = "") -> void:
	_customer = customer
	_header.text = "[%s] %s - %s" % [customer.key, customer.display_name,
		customer.archetype.display_name]
	_line.text = "wants %d" % customer.line if customer.known_line else "wants ?"

	for child in _unsigned_row.get_children():
		child.queue_free()
	for u in customer.unsigned:
		var lbl := Label.new()
		lbl.text = "%s $%s" % [u["product"].display_name, Format.money(u["margin"])]
		_unsigned_row.add_child(lbl)
	var risk: int = customer.unsigned_margin()
	if risk > 0:
		var total := Label.new()
		total.text = "  (%s at risk)" % Format.money(risk)
		total.add_theme_color_override("font_color", Palette.color(&"alert"))
		_unsigned_row.add_child(total)

	var o = customer.offer
	_offer_box.visible = o != null
	_offer_btn.disabled = o == null
	_drop_btn.disabled = o == null
	if o != null:
		_offer_name.text = o.product.display_name
		_offer_category.text = "%s . %s" % [o.product.interest.category.display_name,
			o.product.interest.display_name]
		_offer_margin.text = "$%s" % Format.money(o.margin)

		if not o.revealed:
			_appeal_bar.set_state(0, customer.line, 40, forced_band)
			_gap.text = forced_band if forced_band != "" else ""
		else:
			var gap: int = customer.line - o.appeal
			_appeal_bar.set_state(o.appeal, customer.line, 40, "")
			if gap <= 0:
				_gap.text = "READY"
				_gap.add_theme_color_override("font_color", Palette.color(&"patience_ok"))
			else:
				_gap.text = "%d SHORT" % gap
				_gap.add_theme_color_override("font_color", Palette.color(&"alert"))

	var known: Array[String] = []
	for iid in customer.known_ranks:
		var rank: int = int(customer.known_ranks[iid])
		known.append("%s %s" % [str(iid).capitalize(), ORDINALS[rank]])
	_known.text = " . ".join(known) if not known.is_empty() \
		else "nothing yet - place something, or read the room"
