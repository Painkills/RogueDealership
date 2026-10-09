extends PanelContainer

signal continue_pressed

var _title: Label
var _banked: Label
var _bonus: Label
var _standing: Label
var _walkouts: Label
var _product_quota: Label
var _customers: Label
var _offers: Label
var _margin: Label
var _lost: Label
var _restart: Button
var _bound := false

func _ready() -> void:
	_bind()

## Plain @onready fields only resolve once _ready() has actually fired, which
## requires being in a live SceneTree - true for the real report (a permanent
## child of the shift HUD from the moment the floor scene is built) but not
## for a bare .instantiate() in a test, the same gap CardFace3D/DetailCard3D/
## CardPreview2D already hit and fixed the same way.
func _bind() -> void:
	if _bound:
		return
	_bound = true
	_title = %TitleLabel
	_banked = %BankedLabel
	_bonus = %BonusLabel
	_standing = %StandingLabel
	_walkouts = %WalkoutsLabel
	_product_quota = %ProductQuotaLabel
	_customers = %CustomersLabel
	_offers = %OffersLabel
	_margin = %MarginMovedLabel
	_lost = %LostLabel
	_restart = %RestartButton
	_restart.pressed.connect(func(): continue_pressed.emit())

func set_button_text(t: String) -> void:
	_bind()
	_restart.text = t

func setup(r: Dictionary) -> void:
	_bind()
	var fired: bool = int(r["standing_after"]) <= 0
	# Without this, a fired run and a completed run look IDENTICAL on screen -
	# same title, same button underneath silently rolling a fresh run. The whole
	# point of a standing meter is that failure has to be visibly different from
	# success.
	_title.text = "YOU'RE FIRED" if fired else "CLOSING TIME"
	_title.add_theme_color_override("font_color",
		Palette.color(&"alert" if fired else &"text"))

	var verdict := "QUOTA MADE" if r["made_quota"] else "MISSED QUOTA"
	_banked.text = "%s of %s - %s" % [Format.money(r["margin_banked"]),
		Format.money(r["quota"]), verdict]
	_banked.add_theme_color_override("font_color",
		Palette.color(&"patience_ok" if r["made_quota"] else &"alert"))

	# The bonus is derived here rather than passed in, because this panel is up
	# while the run has not advanced yet - finish_shift() does not run until the
	# button below is pressed. RunState owns the arithmetic either way.
	var pay := RunState.bonus_from(r)
	var base := int(r.get("paycheck", 0))
	if pay > base:
		# Beating quota adds commission on top of the base salary: say both.
		_bonus.text = "You beat quota - paycheck %s: %s base + %s commission (%d%% of what you banked over)!" \
			% [Format.money(pay), Format.money(base), Format.money(pay - base),
				roundi(float(r.get("commission", 0.0)) * 100.0)]
		_bonus.add_theme_color_override("font_color", Palette.color(&"patience_ok"))
	elif r["made_quota"]:
		_bonus.text = "Paycheck: %s. Quota hit on the nose." % Format.money(pay)
		_bonus.add_theme_color_override("font_color", Palette.color(&"text_dim"))
	else:
		_bonus.text = "Paycheck: %s. You finished %s short of quota." % [Format.money(pay),
			Format.money(int(r["quota"]) - int(r["margin_banked"]))]
		_bonus.add_theme_color_override("font_color", Palette.color(&"text_dim"))

	var delta: int = int(r["standing_delta"])
	# A shift that heals (a boss fight's reward) says how much of that was the
	# heal - see Shift.healed().
	var healed: int = int(r.get("standing_healed", 0))
	_standing.text = "Standing: %d/%d (%s%d)%s" % [r["standing_after"], r["standing_start"],
		"+" if delta >= 0 else "", delta, "  |  healed +%d" % healed if healed > 0 else ""]
	_standing.add_theme_color_override("font_color",
		Palette.color(&"alert" if fired else (&"patience_ok" if delta > 0 else &"text_dim")))

	# A SEPARATE line from the combined standing delta above, on purpose - the
	# whole point of costing standing on its own is to be legible as its own
	# cause, not disappear into one number a player has to reverse-engineer.
	var walked: int = int(r["customers_walked"])
	var walkout_cost: int = int(r["standing_lost_to_walkouts"])
	if walked > 0:
		_walkouts.text = "%d customer%s walked out - cost you %d standing." \
			% [walked, "" if walked == 1 else "s", walkout_cost]
		_walkouts.add_theme_color_override("font_color", Palette.color(&"alert"))
	else:
		_walkouts.text = "Nobody walked out this shift."
		_walkouts.add_theme_color_override("font_color", Palette.color(&"text_dim"))

	# The boss's product quota - its own line, like walkouts, so what it cost
	# is legible as its own cause.
	var need := int(r.get("category_quota_count", 0))
	_product_quota.visible = need > 0
	if need > 0:
		var sold := int(r.get("category_sold", 0))
		var what := "%d %s product%s" % [need, str(r.get("category_quota_name", "")),
			"" if need == 1 else "s"]
		if sold >= need:
			_product_quota.text = "Product quota met: %d of %s sold." % [sold, what]
			_product_quota.add_theme_color_override("font_color", Palette.color(&"patience_ok"))
		else:
			_product_quota.text = "Product quota missed: %d of %s sold - cost you %d standing." \
				% [sold, what, int(r.get("category_quota_cost", 0))]
			_product_quota.add_theme_color_override("font_color", Palette.color(&"alert"))
	# A budget fight's own measure, in the same line - no shift has both: how
	# much of what they came in with you got.
	var seen := int(r.get("budget_seen", 0))
	if seen > 0 and need <= 0:
		var got := int(r.get("budget_spent", 0))
		_product_quota.visible = true
		_product_quota.text = "Budget drained: %s of the %s they came in with." \
			% [Format.money(got), Format.money(seen)]
		_product_quota.add_theme_color_override("font_color",
			Palette.color(&"patience_ok") if got >= seen else Palette.color(&"alert"))

	# These four never got a Palette color at all before this - plain default
	# Label text sitting on the engine's own default panel style, which is
	# roughly the same hue by luck rather than by design. All four are
	# supporting detail, so text_dim throughout, EXCEPT the one number that
	# genuinely reads as bad news wherever it lands.
	_customers.text = "%d seen, %d signed, %d walked" \
		% [r["customers_seen"], r["customers_signed"], r["customers_walked"]]
	_customers.add_theme_color_override("font_color", Palette.color(&"text_dim"))

	_offers.text = "%d offers, %d closed (%.0f%%), %d asked too soon" \
		% [r["offers"], r["sales"], 100.0 * r["close_rate"], r["failed_offers"]]
	_offers.add_theme_color_override("font_color", Palette.color(&"text_dim"))

	_margin.text = "conceded %s, padded %s, bonuses %s" \
		% [Format.money(r["margin_conceded"]), Format.money(r["margin_padded"]),
			Format.money(r["margin_bonus"])]
	_margin.add_theme_color_override("font_color", Palette.color(&"text_dim"))

	var lost: int = r["margin_lost_to_walks"] + r["margin_lost_to_closing"]
	_lost.text = "%s lost (%s walked, %s unsigned at the bell)" \
		% [Format.money(lost), Format.money(r["margin_lost_to_walks"]),
			Format.money(r["margin_lost_to_closing"])]
	_lost.add_theme_color_override("font_color",
		Palette.color(&"alert" if lost > 0 else &"text_dim"))

	# The button is the last thing your eye lands on. On a fatal shift it
	# should not read as the same friendly "Continue" every other shift ends
	# on - set_button_text() already changes its WORDS; this is the button
	# noticing the same fact its text does, in the colour of every other
	# button in the game that ends something.
	ButtonStyle.filled(_restart, Palette.color(&"stamp" if fired else &"primary"))
