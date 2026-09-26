extends PanelContainer
## The end of a run, as an email from the boss: the six Score categories, the
## score they add up to, and where the week lands among the best ones played on
## this device. Shown once the run is over - either all five shifts played, or
## standing hit 0 first - covering the last shift's own end-of-day report the
## same way that report already covers the floor.

signal continue_pressed

## Who the email is from - the GM, the only boss the game has.
const BOSS := "Dale"
## How many of the device's best weeks the email lists.
const LISTED := 5

var _title: Label
var _to: Label
var _when: Label
var _greeting: Label
var _opening: Label
var _sign_off: Label
var _rows := {}
var _total: Label
var _best_headline: Label
var _bests_list: VBoxContainer
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
	_to = %ToLabel
	_when = %WhenLabel
	_greeting = %GreetingLabel
	_opening = %OpeningLabel
	_sign_off = %SignOffLabel
	for key in ["MarginRow", "StandingRow", "StandingLostRow", "WalkoutsRow",
			"StreakRow", "ComboRow"]:
		_rows[key] = get_node("%" + key)
	_total = %TotalLabel
	_best_headline = %BestHeadline
	_bests_list = %BestsList
	_restart = %RestartButton
	_restart.pressed.connect(func(): continue_pressed.emit())

## `rank` is where this week placed among the device's best - PlayerProfile's
## record_run(): 1 is a new personal best, 0 missed the list.
func setup(score: Dictionary, fired: bool, rank: int = 0) -> void:
	_bind()
	var who := PlayerProfile.display_name()
	# A fired run and a finished one must not read alike - the whole point of a
	# standing meter is that failure is visibly different from success.
	_title.text = "You're fired." if fired else "Your week, by the numbers"
	_title.add_theme_color_override("font_color",
		Palette.color(&"alert" if fired else &"text"))
	_to.text = "to %s" % who
	_when.text = "Fri, 6:02 PM"
	_greeting.text = "%s," % who if fired else "Hi %s," % who
	# A first week is the best on the board by default; a personal best means
	# beating one that was already there.
	var new_best := rank == 1 and PlayerProfile.bests().size() > 1
	if fired:
		_opening.text = "I'll keep this short. Your standing hit zero, so today was your last day. Final numbers are below."
		_sign_off.text = "Leave your badge at the front desk.\n- %s, General Manager" % BOSS
	elif new_best:
		_opening.text = "Best week I've seen from that desk. Here's how it added up - every line counts toward the number at the bottom."
		_sign_off.text = "Drinks are on me Friday.\n- %s, General Manager" % BOSS
	else:
		_opening.text = "That's the week. Here's where you landed - every line counts toward the number at the bottom."
		_sign_off.text = "See you Monday.\n- %s, General Manager" % BOSS

	_set_row(_rows["MarginRow"], "Margin banked", Format.money(score["margin_banked"]),
		int(score["margin_points"]))
	_set_row(_rows["StandingRow"], "Standing at the bell",
		"%d/%d" % [score["standing"], score["standing_start"]],
		int(score["standing_points"]))
	_set_row(_rows["StandingLostRow"], "Standing lost", str(score["standing_lost"]),
		int(score["standing_lost_points"]))
	_set_row(_rows["WalkoutsRow"], "Customers who walked", str(score["walkouts"]),
		int(score["walkout_points"]))
	_set_row(_rows["StreakRow"], "Best streak with no walkout",
		"%d in a row" % score["best_streak"], int(score["streak_points"]))
	_set_row(_rows["ComboRow"], "Best combo multiplier",
		"×%.2f" % score["best_combo_multiplier"], int(score["combo_multiplier_points"]))
	_total.text = Format.number(int(score["total"]))
	_total.add_theme_color_override("font_color",
		Palette.color(&"margin" if int(score["total"]) >= 0 else &"alert"))

	_show_bests(rank, new_best)

## One line of the scorecard: what it measured, and what it was worth.
## Positive lines read green, penalties red, and a line that scored exactly
## zero stays quiet - it happened, but it moved nothing.
func _set_row(row: Control, what: String, measured: String, pts: int) -> void:
	(row.get_node(^"What") as Label).text = what
	(row.get_node(^"Measured") as Label).text = measured
	var points := row.get_node(^"Points") as Label
	points.text = "%s%s" % ["+" if pts > 0 else "", Format.number(pts)]
	var role := &"text_dim"
	if pts > 0:
		role = &"patience_ok"
	elif pts < 0:
		role = &"alert"
	points.add_theme_color_override("font_color", Palette.color(role))

## The best weeks on this device, this one picked out if it made the list.
func _show_bests(rank: int, new_best: bool) -> void:
	var best := PlayerProfile.best_score()
	if new_best:
		_best_headline.text = "NEW PERSONAL BEST!"
		_best_headline.add_theme_color_override("font_color", Palette.color(&"money"))
	elif rank == 1:
		_best_headline.text = "Your first week on the board"
		_best_headline.add_theme_color_override("font_color", Palette.color(&"text"))
	elif PlayerProfile.has_best():
		_best_headline.text = "Best so far: %s" % Format.number(best)
		_best_headline.add_theme_color_override("font_color", Palette.color(&"text"))
	else:
		_best_headline.text = "No weeks on the board yet"
		_best_headline.add_theme_color_override("font_color", Palette.color(&"text_dim"))

	for child in _bests_list.get_children():
		_bests_list.remove_child(child)
		child.queue_free()
	var runs := PlayerProfile.bests()
	var this_one := PlayerProfile.last_seq() if rank > 0 else -1
	for k in range(mini(LISTED, runs.size())):
		var run: Dictionary = runs[k]
		_bests_list.add_child(_best_row(k + 1, run, int(run["seq"]) == this_one))

func _best_row(place: int, run: Dictionary, mine: bool) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var role := &"primary" if mine else &"text"
	for spec in [["%d." % place, 34, HORIZONTAL_ALIGNMENT_RIGHT],
			[str(run["name"]), 0, HORIZONTAL_ALIGNMENT_LEFT],
			[PlayerProfile.short_date(str(run["date"])), 66, HORIZONTAL_ALIGNMENT_RIGHT],
			[Format.number(int(run["score"])), 92, HORIZONTAL_ALIGNMENT_RIGHT]]:
		var l := Label.new()
		l.text = spec[0]
		l.custom_minimum_size = Vector2(spec[1], 0)
		l.horizontal_alignment = spec[2]
		if spec[1] == 0:
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			l.clip_text = true
		l.add_theme_font_size_override("font_size", 20)
		l.add_theme_color_override("font_color", Palette.color(role))
		if mine:
			l.theme_type_variation = &"Heading"
		row.add_child(l)
	return row
