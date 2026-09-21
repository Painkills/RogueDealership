extends PanelContainer
## The end-of-run screen: the six Score categories and the high score they
## add up to. Shown once the run is over - either all five shifts played, or
## standing hit 0 first - covering the last shift's own CLOSING TIME report
## the same way that report already covers the floor.

signal continue_pressed

var _title: Label
var _margin: Label
var _standing: Label
var _standing_lost: Label
var _walkouts: Label
var _streak: Label
var _combo_multiplier: Label
var _total: Label
var _restart: Button
var _bound := false

func _ready() -> void:
	_bind()

## Same gap this project's other overlay panels hit: plain @onready fields
## only resolve once _ready() has fired inside a live SceneTree, which a bare
## .instantiate() in a test does not give them for free.
func _bind() -> void:
	if _bound:
		return
	_bound = true
	_title = %TitleLabel
	_margin = %MarginLabel
	_standing = %StandingLabel
	_standing_lost = %StandingLostLabel
	_walkouts = %WalkoutsLabel
	_streak = %StreakLabel
	_combo_multiplier = %ComboMultiplierLabel
	_total = %TotalLabel
	_restart = %RestartButton
	_restart.pressed.connect(func(): continue_pressed.emit())

func setup(score: Dictionary, fired: bool) -> void:
	_bind()
	_title.text = "YOU'RE FIRED" if fired else "RUN COMPLETE"
	_title.add_theme_color_override("font_color",
		Palette.color(&"alert" if fired else &"text"))

	_set_line(_margin, "Margin banked", Format.money(score["margin_banked"]),
		int(score["margin_points"]))
	_set_line(_standing, "Standing at the bell",
		"%d/%d" % [score["standing"], score["standing_start"]],
		int(score["standing_points"]))
	_set_line(_standing_lost, "Standing lost", str(score["standing_lost"]),
		int(score["standing_lost_points"]))
	_set_line(_walkouts, "Customers walked", str(score["walkouts"]),
		int(score["walkout_points"]))
	_set_line(_streak, "Best streak closed with no walkout",
		"%d in a row" % score["best_streak"], int(score["streak_points"]))
	_set_line(_combo_multiplier, "Best combo multiplier this run",
		"×%.2f" % score["best_combo_multiplier"], int(score["combo_multiplier_points"]))

	_total.text = "HIGH SCORE: %d" % int(score["total"])

## One category row: what it measured, and what it was worth. Positive
## contributions read patience_ok (the same green a good shift's numbers use
## elsewhere), penalties read alert, and a category that scored exactly zero
## stays text_dim - it happened, but it moved nothing.
func _set_line(label: Label, title: String, measured: String, pts: int) -> void:
	label.text = "%s: %s -> %+d pts" % [title, measured, pts]
	var color := &"text_dim"
	if pts > 0:
		color = &"patience_ok"
	elif pts < 0:
		color = &"alert"
	label.add_theme_color_override("font_color", Palette.color(color))
