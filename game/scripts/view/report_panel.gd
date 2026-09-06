extends PanelContainer

signal continue_pressed

@onready var _banked: Label = %BankedLabel
@onready var _bonus: Label = %BonusLabel
@onready var _customers: Label = %CustomersLabel
@onready var _offers: Label = %OffersLabel
@onready var _margin: Label = %MarginMovedLabel
@onready var _lost: Label = %LostLabel
@onready var _restart: Button = %RestartButton

func _ready() -> void:
	_restart.pressed.connect(func(): continue_pressed.emit())

func set_button_text(t: String) -> void:
	_restart.text = t

func setup(r: Dictionary) -> void:
	var verdict := "QUOTA MADE" if r["made_quota"] else "MISSED QUOTA"
	_banked.text = "%s of %s - %s" % [Format.money(r["margin_banked"]),
		Format.money(r["quota"]), verdict]
	_banked.add_theme_color_override("font_color",
		Palette.color(&"patience_ok" if r["made_quota"] else &"alert"))

	# The bonus is derived here rather than passed in, because this panel is up
	# while the run has not advanced yet - finish_shift() does not run until the
	# button below is pressed. RunState owns the arithmetic either way.
	var bonus := RunState.bonus_from(r)
	if bonus > 0:
		_bonus.text = "You exceeded your quota. You got a %s bonus!" \
			% Format.money(bonus)
		_bonus.add_theme_color_override("font_color", Palette.color(&"patience_ok"))
	elif r["made_quota"]:
		_bonus.text = "You hit quota on the nose - nothing over, nothing banked."
		_bonus.add_theme_color_override("font_color", Palette.color(&"text_dim"))
	else:
		_bonus.text = "No bonus - you finished %s short of quota." \
			% Format.money(int(r["quota"]) - int(r["margin_banked"]))
		_bonus.add_theme_color_override("font_color", Palette.color(&"text_dim"))

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
