extends Control
## The front door: the game opens here, and a finished week comes back here.
##
## Three pages over the same drawn dealership (DealershipArt): the menu - NEW
## GAME, TUTORIAL, HIGH SCORES - the high scores themselves, and the first-day
## welcome a new game opens on before its calendar. Only one page shows at a
## time; RunController decides what happens after them.

## The first day's welcome is done with - start the run's calendar.
signal new_game_started
## The practice shift - see TutorialCoach.
signal tutorial_requested

## What the banner under the showroom's sign says on each page.
const BANNERS := {
	&"menu": "NOW HIRING: F&I MANAGER",
	&"scores": "EMPLOYEES OF THE MONTH",
	&"intro": "WELCOME ABOARD!",
}

@onready var _art: DealershipArt = %Art
@onready var _pages := {
	&"menu": %MenuCard as Control,
	&"scores": %ScoresCard as Control,
	&"intro": %IntroCard as Control,
}
@onready var _scores_list: VBoxContainer = %ScoresList
@onready var _scores_empty: Label = %ScoresEmpty
@onready var _name_field: LineEdit = %IntroName

var _page := &""

func _ready() -> void:
	(%NewGameButton as Button).pressed.connect(show_intro)
	(%TutorialButton as Button).pressed.connect(func(): tutorial_requested.emit())
	(%HighScoresButton as Button).pressed.connect(show_scores)
	(%ScoresBackButton as Button).pressed.connect(show_menu)
	(%IntroBackButton as Button).pressed.connect(show_menu)
	(%StartDayButton as Button).pressed.connect(func():
		_name_field.release_focus()
		new_game_started.emit())
	# Kept as you type, the way the tutorial's name tag keeps it.
	_name_field.max_length = PlayerProfile.MAX_NAME
	_name_field.text_changed.connect(PlayerProfile.set_player_name)
	_name_field.text_submitted.connect(func(_t): _name_field.release_focus())
	show_menu()

func show_menu() -> void:
	_show(&"menu")

func show_scores() -> void:
	_fill_scores()
	_show(&"scores")

## "It's your first day": the welcome a new game opens on, with your name tag.
func show_intro() -> void:
	_name_field.text = PlayerProfile.player_name()
	_show(&"intro")

## Which page is up - &"menu", &"scores" or &"intro".
func page() -> StringName:
	return _page

func _show(which: StringName) -> void:
	_page = which
	for id in _pages:
		(_pages[id] as Control).visible = id == which
	_art.banner = BANNERS.get(which, "")

## Every best run this device remembers, best first, or a line saying there
## are none yet.
func _fill_scores() -> void:
	for child in _scores_list.get_children():
		_scores_list.remove_child(child)
		child.queue_free()
	var runs := PlayerProfile.bests()
	_scores_empty.visible = runs.is_empty()
	for k in range(runs.size()):
		_scores_list.add_child(_row(k + 1, runs[k]))

func _row(place: int, run: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var fired := bool(run.get("fired", false))
	for spec in [["%d." % place, 44, HORIZONTAL_ALIGNMENT_RIGHT, &"text_dim"],
			[str(run["name"]), 0, HORIZONTAL_ALIGNMENT_LEFT, &"text"],
			["FIRED" if fired else "", 70, HORIZONTAL_ALIGNMENT_CENTER, &"alert"],
			[PlayerProfile.short_date(str(run["date"])), 76, HORIZONTAL_ALIGNMENT_RIGHT, &"text_dim"],
			[Format.money(int(run.get("banked", 0))), 120, HORIZONTAL_ALIGNMENT_RIGHT, &"money"],
			[Format.number(int(run["score"])), 110, HORIZONTAL_ALIGNMENT_RIGHT, &"primary"]]:
		var l := Label.new()
		l.text = spec[0]
		l.custom_minimum_size = Vector2(spec[1], 0)
		l.horizontal_alignment = spec[2]
		if spec[1] == 0:
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			l.clip_text = true
		l.add_theme_font_size_override("font_size", 22)
		l.add_theme_color_override("font_color", Palette.color(spec[3]))
		row.add_child(l)
	return row
