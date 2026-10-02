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
@onready var _scores_sub: Label = %ScoresSub
@onready var _tabs: Control = %ScoresTabs
@onready var _everyone_tab: Button = %EveryoneTab
@onready var _yours_tab: Button = %YoursTab

var _page := &""
## Which board the high scores show - &"everyone" or &"yours".
var _board := &""
## Everyone's scores, shared across players - see Leaderboard.
var leaderboard: Leaderboard

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
	leaderboard = Leaderboard.new()
	leaderboard.name = "Leaderboard"
	add_child(leaderboard)
	leaderboard.fetched.connect(_on_board_fetched)
	_everyone_tab.pressed.connect(func(): show_board(&"everyone"))
	_yours_tab.pressed.connect(func(): show_board(&"yours"))
	show_menu()

func show_menu() -> void:
	_show(&"menu")

## Everyone's board when there is one to reach, this device's otherwise.
func show_scores() -> void:
	_tabs.visible = Leaderboard.available()
	show_board(&"everyone" if Leaderboard.available() else &"yours")
	_show(&"scores")

func show_board(which: StringName) -> void:
	_board = which
	_everyone_tab.set_pressed_no_signal(which == &"everyone")
	_yours_tab.set_pressed_no_signal(which == &"yours")
	if which == &"everyone":
		_scores_sub.text = "The best weeks worked by everyone."
		_list([], "Loading the board...")
		leaderboard.fetch()
	else:
		_scores_sub.text = "The best weeks worked on this device."
		_list(PlayerProfile.bests(), "No weeks on the board yet. Go sell something.")

## Which board is up - &"everyone" or &"yours".
func board() -> StringName:
	return _board

## A finished week, onto everyone's board.
func post_score(player_name: String, score: int, banked: int, fired: bool) -> void:
	leaderboard.submit(player_name, score, banked, fired)

func _on_board_fetched(rows: Array, ok: bool) -> void:
	if _board != &"everyone":
		return
	_list(rows, "No scores on the board yet. Be the first." if ok
		else "Couldn't reach the board right now. Try again in a bit.")

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

## `runs` best first, or `empty` when there are none.
func _list(runs: Array, empty: String) -> void:
	for child in _scores_list.get_children():
		_scores_list.remove_child(child)
		child.queue_free()
	_scores_empty.text = empty
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
