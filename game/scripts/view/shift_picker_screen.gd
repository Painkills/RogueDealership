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
## CLOSE, on the view from the floor - see setup()'s `working`.
signal closed

const DAY_NAMES := ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
const GUTTER_W := 84.0

@onready var _week: HBoxContainer = %Week
@onready var _sub: Label = %SubLabel
@onready var _close: Button = %CloseButton

func _ready() -> void:
	_close.pressed.connect(func(): closed.emit())

## Today's own quota, before any shift's quota_scale - what an event compares
## its shift's quota against.
var _day_quota: int = 0
## This week's base salary, before any shift's pay_scale - 0 to leave pay off
## the events.
var _week_pay: int = 0
## The week's product quotas, by day (1-based) - RunState.category_quota()'s
## {"category", "count"} for each day that has one. Not on a boss day.
var _product_quotas: Dictionary = {}

## `offers` is what today has to pick from - the regular tiers, or a premade
## shift in one's place, or a boss day's one shift (see Week). `day` is the
## run's shift number (1-based), `days` how many the run has. `history` is one
## {"profile", "report"} per shift already worked, in order. `week_length` is
## how many days the calendar shows at once: the week `day` falls in.
func setup(offers: Array[ShiftProfile], day: int = 1, days: int = 5, quota: int = 0,
		history: Array = [], week_length: int = 7, pay: int = 0,
		product_quotas: Dictionary = {}, working: ShiftProfile = null) -> void:
	_day_quota = quota
	_week_pay = pay
	_product_quotas = product_quotas
	# `working`: looked at from the floor, mid-shift - today is the shift you
	# are on, nothing can be picked, and CLOSE takes you back.
	var view_only := working != null
	_close.visible = view_only
	var per_week: int = maxi(1, mini(week_length, days))
	var week_index: int = (day - 1) / per_week
	var weeks: int = (days + per_week - 1) / per_week
	var first: int = week_index * per_week
	# Each shift shows its own quota now, so the header only says where you are.
	_sub.text = "%sShift %d of %d - %s" % [
		"Week %d of %d  |  " % [week_index + 1, weeks] if weeks > 1 else "", day, days,
		"you're on the %s" % working.display_name if view_only else "pick today's"]
	# The week to beat, once there is one - see PlayerProfile.
	if PlayerProfile.has_best():
		_sub.text += "  |  your best week: %s" % Format.number(PlayerProfile.best_score())
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

	# The week today falls in - `d` is still the run's own day, from 0.
	for d in range(first, mini(first + per_week, days)):
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 0)
		_week.add_child(col)
		col.add_child(_day_header(d, d % per_week, d + 1 == day))
		var body := CalendarDay.new()
		body.today = d + 1 == day
		col.add_child(body)
		if d + 1 < day and d < history.size():
			_worked(body, history[d])
		elif d + 1 == day and view_only:
			_offer(body, working, false)
		elif d + 1 == day:
			for profile in offers:
				_offer(body, profile)

## `d` is the run's own day from 0 - the date in the circle - and `weekday`
## which day of the week it falls on.
func _day_header(d: int, weekday: int, is_today: bool) -> Control:
	var head := VBoxContainer.new()
	head.custom_minimum_size = Vector2(0, 88)
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", 4)
	var name_label := Label.new()
	name_label.text = DAY_NAMES[weekday % DAY_NAMES.size()]
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
	# The boss's product quota for the day, under its date - the day's, not
	# any one shift's, and known for the whole week ahead. The line is there
	# on every day of a week that has any, blank where a day has none (a boss
	# day), so every column's header stays the same height and the hours line
	# up across the week.
	var q: Dictionary = _product_quotas.get(d + 1, {})
	if not _product_quotas.is_empty():
		var orders := Label.new()
		orders.theme_type_variation = &"Heading"
		orders.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		orders.add_theme_font_size_override("font_size", 15)
		orders.add_theme_color_override("font_color", Palette.color(&"accent"))
		if not q.is_empty():
			orders.name = "ProductQuota"
			orders.text = "Sell %d %s" % [int(q["count"]), (q["category"] as Category).display_name]
		else:
			orders.name = "NoProductQuota"
			orders.text = " "
		head.add_child(orders)
	return head

## Today's choice: an event you click to work that shift.
## `pickable` false: shown, not offered - the view from the floor.
func _offer(body: CalendarDay, profile: ShiftProfile, pickable: bool = true) -> void:
	var hue := _hue(profile)
	var hours: Array = ShiftHours.of(profile.worked_at())
	var event := Button.new()
	event.name = "Event_%s" % profile.id
	event.tooltip_text = profile.blurb
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		var mix: float = {"normal": 0.16, "hover": 0.26, "pressed": 0.38,
			"hover_pressed": 0.34}[state]
		event.add_theme_stylebox_override(state, _event_style(hue, mix))
	# Focus is drawn OVER the state's own box - a second tint would double it.
	event.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	# Words that outgrow their hours stop at the event's edge rather than
	# spilling over the next shift down the day.
	event.clip_contents = true
	body.place(event, hours[0], hours[1])
	var col := _event_text(event)
	# A premade shift says so before anything else: this is not the usual day.
	# What it does differently - a smaller hand, a tougher crowd - rides on the
	# same line, because you are about to play under it and an event's hours
	# leave no room for a line of its own.
	var rules := profile.rules_preview()
	if profile.is_premade():
		var tag_row := HBoxContainer.new()
		tag_row.name = "TagRow"
		tag_row.add_theme_constant_override("separation", 8)
		tag_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(tag_row)
		var tag := _line(tag_row, "BOSS SHIFT" if profile.is_boss_day()
			else "SPECIAL SHIFT", 14, hue, true)
		tag.name = "PremadeTag"
		tag.autowrap_mode = TextServer.AUTOWRAP_OFF
		tag.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		if rules != "":
			var rules_line := _line(tag_row, rules, 14, Palette.color(&"accent"), true)
			rules_line.name = "Rules"
			rules_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			rules_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# The title row: the shift's name, and its hours at the far right.
	var title_row := HBoxContainer.new()
	title_row.name = "TitleRow"
	title_row.add_theme_constant_override("separation", 8)
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(title_row)
	var title := _line(title_row, profile.display_name, 22, Palette.color(&"text"), true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var when := _line(title_row, "%s - %s" % [CalendarDay.hour_label(int(hours[0])),
		CalendarDay.hour_label(int(hours[1]))], 15, Palette.color(&"text_dim"))
	when.name = "Hours"
	when.autowrap_mode = TextServer.AUTOWRAP_OFF
	when.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	when.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Every shift's quota and commission, under its name, whether or not they
	# differ from anyone else's - what the shift is worth is half of choosing it.
	var quota := profile.quota_on(_day_quota)
	var pay := ("%s pay + " % Format.money(roundi(_week_pay * profile.pay_scale))) \
		if _week_pay > 0 else ""
	var terms := _line(col, "quota %s  |  %s%d%% commission" % [
		Format.money(quota) if quota > 0 else "-", pay, roundi(profile.commission * 100.0)],
		15, Palette.color(&"text"), true)
	terms.name = "Terms"
	_line(col, profile.blurb, 16, Palette.color(&"text"))
	_line(col, profile.reward_preview(), 15, hue.darkened(0.35))
	if pickable:
		event.pressed.connect(func(): chosen.emit(profile))
	else:
		event.mouse_filter = Control.MOUSE_FILTER_IGNORE
		event.focus_mode = Control.FOCUS_NONE

## A day already worked: the shift you took, and how it went. Not a button -
## the past is not something to pick again.
func _worked(body: CalendarDay, entry: Dictionary) -> void:
	var profile: ShiftProfile = entry.get("profile")
	var report: Dictionary = entry.get("report", {})
	var hours: Array = ShiftHours.of(profile.worked_at() if profile != null else &"")
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

func _line(col: Container, text: String, size: int, color: Color,
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

## Each tier in its own colour; a premade shift in the accent, and a boss day
## in the colour the game keeps for danger.
func _hue(profile: ShiftProfile) -> Color:
	if profile.is_boss_day():
		return Palette.color(&"stamp")
	if profile.is_premade():
		return Palette.color(&"accent")
	var role := StringName("shift_%s" % profile.id)
	return Palette.color(role) if Palette.ROLES.has(role) else Palette.color(&"primary")
