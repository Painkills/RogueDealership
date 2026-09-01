extends PanelContainer

signal restart_pressed

@onready var _banked: Label = %BankedLabel
@onready var _customers: Label = %CustomersLabel
@onready var _offers: Label = %OffersLabel
@onready var _margin: Label = %MarginMovedLabel
@onready var _lost: Label = %LostLabel
@onready var _restart: Button = %RestartButton

func _ready() -> void:
	_restart.pressed.connect(func(): restart_pressed.emit())

func setup(r: Dictionary) -> void:
	var verdict := "QUOTA MADE" if r["made_quota"] else "MISSED QUOTA"
	_banked.text = "%s of %s - %s" % [Format.money(r["margin_banked"]),
		Format.money(r["quota"]), verdict]
	_banked.add_theme_color_override("font_color",
		Palette.color(&"patience_ok" if r["made_quota"] else &"alert"))

	_customers.text = "%d seen, %d signed, %d walked" \
		% [r["customers_seen"], r["customers_signed"], r["customers_walked"]]

	_offers.text = "%d offers, %d closed (%.0f%%), %d fell short" \
		% [r["offers"], r["sales"], 100.0 * r["close_rate"], r["failed_offers"]]

	_margin.text = "conceded %s, padded %s, bonuses %s" \
		% [Format.money(r["margin_conceded"]), Format.money(r["margin_padded"]),
			Format.money(r["margin_bonus"])]

	var lost: int = r["margin_lost_to_walks"] + r["margin_lost_to_closing"]
	_lost.text = "%s lost (%s walked, %s unsigned at the bell)" \
		% [Format.money(lost), Format.money(r["margin_lost_to_walks"]),
			Format.money(r["margin_lost_to_closing"])]
