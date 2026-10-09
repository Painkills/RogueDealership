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

## How often, in seconds, an installed copy of the game looks to see whether a
## newer build has been fetched - see _watch_for_a_new_build().
const NEW_BUILD_POLL_SECONDS := 4.0

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
@onready var _popup: Control = %NamePopup
@onready var _name_field: LineEdit = %NameField
@onready var _intro_title: Label = %IntroTitle
@onready var _scores_sub: Label = %ScoresSub
@onready var _tabs: Control = %ScoresTabs
@onready var _everyone_tab: Button = %EveryoneTab
@onready var _yours_tab: Button = %YoursTab

var _page := &""
## What the name popup goes on to once it is answered - &"new_game" or
## &"tutorial".
var _after_name := &""
## Which board the high scores show - &"everyone" or &"yours".
var _board := &""
## Everyone's scores, shared across players - see Leaderboard.
var leaderboard: Leaderboard

func _ready() -> void:
	(%NewGameButton as Button).pressed.connect(ask_name.bind(&"new_game"))
	(%TutorialButton as Button).pressed.connect(ask_name.bind(&"tutorial"))
	(%HighScoresButton as Button).pressed.connect(show_scores)
	(%ScoresBackButton as Button).pressed.connect(show_menu)
	(%IntroBackButton as Button).pressed.connect(show_menu)
	(%StartDayButton as Button).pressed.connect(func(): new_game_started.emit())
	(%NameOkButton as Button).pressed.connect(confirm_name)
	(%NameCancelButton as Button).pressed.connect(_close_popup)
	_name_field.text_submitted.connect(func(_t): confirm_name())
	if uses_native_prompt():
		# A phone's keyboard does not reliably reach a Godot text box in a
		# browser - it suggests words and nothing lands. The browser's own
		# prompt always works, so a tap on the sticker asks through that.
		#
		# Never focusable here, and asked on a RELEASE: the prompt blocks the
		# page, and the touch that opened it is delivered again once it closes
		# - asking on focus or on press re-opened it forever. A short quiet
		# spell after it closes swallows that echo too.
		_name_field.virtual_keyboard_enabled = false
		_name_field.editable = false
		_name_field.focus_mode = Control.FOCUS_NONE
		_name_field.add_theme_color_override("font_uneditable_color", Palette.color(&"ink"))
		_name_field.gui_input.connect(_on_name_tapped)
	leaderboard = Leaderboard.new()
	leaderboard.name = "Leaderboard"
	add_child(leaderboard)
	leaderboard.fetched.connect(_on_board_fetched)
	_everyone_tab.pressed.connect(func(): show_board(&"everyone"))
	_yours_tab.pressed.connect(func(): show_board(&"yours"))
	show_menu()
	if OS.has_feature("web"):
		_watch_for_a_new_build()

## An installed copy of the game runs the build it downloaded the time before, and
## fetches any newer one in the background (the service worker the web export
## ships). Without this it would stay one deploy behind until the app had been
## closed and opened twice. Once a newer build is waiting, the front door is where
## to switch to it: nothing is in progress here.
func _watch_for_a_new_build() -> void:
	var timer := Timer.new()
	timer.wait_time = NEW_BUILD_POLL_SECONDS
	timer.timeout.connect(func():
		if switches_to_a_new_build(_page, _popup.visible, JavaScriptBridge.pwa_needs_update()):
			JavaScriptBridge.pwa_update())
	add_child(timer)
	timer.start()

## Whether to switch to a newer build that is `waiting`: on the menu, with nobody
## in the middle of typing a name.
static func switches_to_a_new_build(page: StringName, popup_open: bool, waiting: bool) -> bool:
	return waiting and page == &"menu" and not popup_open

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

## "It's your first day": the welcome a new game opens on, addressed to you.
func show_intro() -> void:
	var who := PlayerProfile.player_name()
	_intro_title.text = "You got the job, %s!" % who if who != "" else "You got the job!"
	_show(&"intro")

## "What's your name?" - before a new game or the tutorial, filled in with the
## name already on this device. `then` is where it goes once answered.
func ask_name(then: StringName) -> void:
	_after_name = then
	_name_field.text = PlayerProfile.player_name()
	_popup.visible = true
	# Ready to type on a computer. On a phone, focus would open the prompt
	# before anyone asked for it - a tap on the sticker does that.
	if not uses_native_prompt():
		_name_field.grab_focus()
		_name_field.caret_column = _name_field.text.length()

func name_popup_showing() -> bool:
	return _popup.visible

## Keeps the name and goes on to whatever asked for it.
func confirm_name() -> void:
	if not _popup.visible:
		return
	PlayerProfile.set_player_name(_name_field.text)
	_close_popup()
	match _after_name:
		&"new_game":
			show_intro()
		&"tutorial":
			tutorial_requested.emit()

func _close_popup() -> void:
	_name_field.release_focus()
	_popup.visible = false

## A browser on a touch screen - where typing goes through window.prompt().
static func uses_native_prompt() -> bool:
	return OS.has_feature("web") and DisplayServer.is_touchscreen_available()

## When the browser's prompt last closed, in msec - see _on_name_tapped().
var _prompt_closed_at := -100000
const PROMPT_QUIET_MS := 700

func _on_name_tapped(event: InputEvent) -> void:
	var released: bool = (event is InputEventMouseButton and not event.pressed
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventScreenTouch and not event.pressed)
	if not released or not _popup.visible:
		return
	# A phone sends a touch AND the mouse click it emulates - one prompt for both.
	if _prompt_queued or Time.get_ticks_msec() - _prompt_closed_at < PROMPT_QUIET_MS:
		return
	_name_field.accept_event()
	_prompt_queued = true
	_prompt_for_name.call_deferred()

var _prompt_queued := false

func _prompt_for_name() -> void:
	var asked = JavaScriptBridge.eval("window.prompt('Name on your badge', %s)"
		% JSON.stringify(_name_field.text), true)
	_prompt_closed_at = Time.get_ticks_msec()
	_prompt_queued = false
	if asked is String:
		_name_field.text = (asked as String).strip_edges().left(PlayerProfile.MAX_NAME)

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
