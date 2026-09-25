extends PanelContainer
## Before every shift: pick a ShiftProfile - on a calendar.
##
## The run is a working week, one shift a day, so this is laid out like a
## calendar app's week view: a column per day, the hours down the side, and
## each kind of shift an event at the hours it runs. Days already worked show
## the shift you took and whether you made quota; today holds the three you can
## pick from; the days ahead are still empty.
##
## Rebuilt fresh each setup() the same way shop_screen.gd rebuilds its rows -
## a week is cheap enough that patching it is not worth the risk of it
## disagreeing with the run.

signal chosen(profile: ShiftProfile)
## HOW TO PLAY - the practice shift, replayed on demand. It also opens the
## game by itself (see RunController.tutorial_at_boot).
signal tutorial_requested

const DAY_NAMES := ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
## When each kind of shift runs, in hours - where its event sits on the day. A
## profile this does not name runs through the middle of the day.
const HOURS := {&"morning": [8.0, 12.0], &"midday": [12.0, 16.0], &"night": [18.0, 22.0]}
const DEFAULT_HOURS := [12.0, 16.0]
const GUTTER_W := 84.0

@onready var _week: HBoxContainer = %Week
@onready var _sub: Label = %SubLabel

func _ready() -> void:
	(%TutorialButton as Button).pressed.connect(func(): tutorial_requested.emit())

## `day` is the run's shift number (1-based), `days` how many the run has.
## `history` is one {"profile", "report"} per shift already worked, in order.
func setup(pool: ShiftProfilePool, day: int = 1, days: int = 5, quota: int = 0,
		history: Array = []) -> void:
	_sub.text = "Shift %d of %d - pick today's%s" % [day, days,
		"  |  quota %s" % Format.money(quota) if quota > 0 else ""]
	for child in _week.get_children():
		_week.remove_child(child)
		child.queue_free()

	var gutter_col := VBoxContainer.new()
	gutter_col.custom_minimum_size = Vector2(GUTTER_W, 0)
	gutter_col.add_theme_constant_override("separation", 0)
	_week.add_child(gutter_col)
	var gutter_head := Control.new()
	gutter_head.custom_minimum_size = Vector2(0, 88)
	gutter_col.add_child(gutter_head)
	var gutter := CalendarDay.new()
	gutter.gutter = true
	gutter_col.add_child(gutter)

	for d in range(days):
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 0)
		_week.add_child(col)
		col.add_child(_day_header(d, d + 1 == day))
		var body := CalendarDay.new()
		body.today = d + 1 == day
		col.add_child(body)
		if d + 1 < day and d < history.size():
			_worked(body, history[d])
		elif d + 1 == day:
			for profile in pool.profiles:
				_offer(body, profile)

func _day_header(d: int, is_today: bool) -> Control:
	var head := VBoxContainer.new()
	head.custom_minimum_size = Vector2(0, 88)
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", 4)
	var name_label := Label.new()
	name_label.text = DAY_NAMES[d % DAY_NAMES.size()]
	name_label.theme_type_variation = &"Heading"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color",
		Palette.color(&"primary") if is_today else Palette.color(&"text_dim"))
	head.add_child(name_label)
	# The date in a circle - filled in the house blue for today, the way a
	# calendar marks it.
	var wrap := CenterContainer.new()
	head.add_child(wrap)
	var disc := PanelContainer.new()
	disc.custom_minimum_size = Vector2(46, 46)
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.color(&"primary") if is_today else Color(0, 0, 0, 0)
	style.set_corner_radius_all(23)
	disc.add_theme_stylebox_override("panel", style)
	wrap.add_child(disc)
	var number := Label.new()
	number.text = str(d + 1)
	number.theme_type_variation = &"Heading"
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	number.add_theme_font_size_override("font_size", 26)
	number.add_theme_color_override("font_color",
		Palette.color(&"paper") if is_today else Palette.color(&"text"))
	disc.add_child(number)
	return head

## Today's choice: an event you click to work that shift.
func _offer(body: CalendarDay, profile: ShiftProfile) -> void:
	var hue := _hue(profile.id)
	var hours: Array = HOURS.get(profile.id, DEFAULT_HOURS)
	var event := Button.new()
	event.name = "Event_%s" % profile.id
	event.tooltip_text = profile.blurb
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		var mix: float = {"normal": 0.16, "hover": 0.26, "pressed": 0.38,
			"hover_pressed": 0.34}[state]
		event.add_theme_stylebox_override(state, _event_style(hue, mix))
	# Focus is drawn OVER the state's own box - a second tint would double it.
	event.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	body.place(event, hours[0], hours[1])
	var col := _event_text(event)
	_line(col, profile.display_name, 24, Palette.color(&"text"), true)
	_line(col, "%s - %s" % [CalendarDay.hour_label(int(hours[0])),
		CalendarDay.hour_label(int(hours[1]))], 15, Palette.color(&"text_dim"))
	_line(col, profile.blurb, 16, Palette.color(&"text"))
	_line(col, profile.reward_preview(), 15, hue.darkened(0.35))
	event.pressed.connect(func(): chosen.emit(profile))

## A day already worked: the shift you took, and how it went. Not a button -
## the past is not something to pick again.
func _worked(body: CalendarDay, entry: Dictionary) -> void:
	var profile: ShiftProfile = entry.get("profile")
	var report: Dictionary = entry.get("report", {})
	var id: StringName = profile.id if profile != null else &""
	var hours: Array = HOURS.get(id, DEFAULT_HOURS)
	var card := PanelContainer.new()
	card.name = "Worked"
	card.add_theme_stylebox_override("panel",
		_event_style(Palette.color(&"neutral_3"), 0.22))
	body.place(card, hours[0], hours[1])
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(col)
	var made: bool = bool(report.get("made_quota", false))
	_line(col, profile.display_name if profile != null else "Shift", 22,
		Palette.color(&"text_dim"), true)
	_line(col, "MADE QUOTA" if made else "MISSED QUOTA", 16,
		Palette.color(&"money") if made else Palette.color(&"alert"), true)
	_line(col, "%s of %s" % [Format.money(int(report.get("margin_banked", 0))),
		Format.money(int(report.get("quota", 0)))], 16, Palette.color(&"text_dim"))

## The event's words, laid over the whole button so a click anywhere on the
## event is a click on the event.
func _event_text(event: Button) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 16
	col.offset_top = 10
	col.offset_right = -10
	col.offset_bottom = -8
	col.add_theme_constant_override("separation", 4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	event.add_child(col)
	return col

func _line(col: VBoxContainer, text: String, size: int, color: Color,
		heading: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if heading:
		l.theme_type_variation = &"Heading"
	col.add_child(l)
	return l

## A calendar event: the shift's colour washed over white, with a solid bar of
## it down the leading edge.
func _event_style(hue: Color, mix: float) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Palette.color(&"paper").lerp(hue, mix)
	s.border_color = hue
	s.border_width_left = 6
	s.set_corner_radius_all(8)
	s.shadow_color = Color(0, 0, 0, 0.08)
	s.shadow_size = 3
	s.shadow_offset = Vector2(0, 1)
	return s

func _hue(id: StringName) -> Color:
	var role := StringName("shift_%s" % id)
	return Palette.color(role) if Palette.ROLES.has(role) else Palette.color(&"primary")
