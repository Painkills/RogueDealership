extends PanelContainer
## Between weeks: how the one just worked went, day by day, and what the next
## one holds - "before that week starts, give the player a 'this week so far'
## report". Built by tools/build_week_report_scene.gd; RunController shows it
## once the last store of a week closes (see RunState.week_starts_today()).

signal continue_pressed

const DAY_NAMES := ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]

var _title: Label
var _headline: Label
var _days: GridContainer
var _totals: Label
var _next: Label
var _start: Button
var _bound := false

func _ready() -> void:
	_bind()

## The same lazy binding report_panel.gd uses, so a bare instantiate() in a
## test can call setup() before the node has ever been in a tree.
func _bind() -> void:
	if _bound:
		return
	_bound = true
	_title = %WeekTitle
	_headline = %WeekHeadline
	_days = %DaysGrid
	_totals = %TotalsLabel
	_next = %NextLabel
	_start = %StartButton
	_start.pressed.connect(func(): continue_pressed.emit())

## `run`: already moved on to the first day of the next week. `history`: every
## {"profile", "report"} worked so far, from day 1.
func setup(run: RunState, history: Array) -> void:
	_bind()
	var per_week: int = maxi(1, run.cfg.days_per_week)
	var week: int = run.week_of(run.shift_number) - 1      # the week just worked
	var first: int = (week - 1) * per_week
	var entries: Array = history.slice(first, first + per_week)

	_title.text = "WEEK %d IN REVIEW" % week
	for child in _days.get_children():
		_days.remove_child(child)
		child.queue_free()
	for heading in ["DAY", "SHIFT", "BANKED", "QUOTA", "RESULT", "STANDING"]:
		_cell(heading, 16, &"text_dim", true)

	var banked := 0
	var quota := 0
	var made := 0
	var bonus := 0
	var standing := 0
	var signed := 0
	var walked := 0
	for i in range(entries.size()):
		var profile: ShiftProfile = entries[i].get("profile")
		var r: Dictionary = entries[i].get("report", {})
		var ok := bool(r.get("made_quota", false))
		var delta := int(r.get("standing_delta", 0))
		_cell(DAY_NAMES[(first + i) % per_week % DAY_NAMES.size()], 20, &"text", true)
		_cell(profile.display_name if profile != null else "Shift", 20, &"text")
		_cell(Format.money(int(r.get("margin_banked", 0))), 20, &"text")
		_cell(Format.money(int(r.get("quota", 0))), 20, &"text_dim")
		_cell("MADE" if ok else "MISSED", 20, &"money" if ok else &"alert", true)
		_cell("%s%d" % ["+" if delta >= 0 else "", delta], 20,
			&"patience_ok" if delta > 0 else (&"alert" if delta < 0 else &"text_dim"))
		banked += int(r.get("margin_banked", 0))
		quota += int(r.get("quota", 0))
		made += 1 if ok else 0
		bonus += RunState.bonus_from(r) if not r.is_empty() else 0
		standing += delta
		signed += int(r.get("customers_signed", 0))
		walked += int(r.get("customers_walked", 0))

	_headline.text = "%s banked against %s of quota - %d of %d quotas made." \
		% [Format.money(banked), Format.money(quota), made, entries.size()]
	_totals.text = "Bonus earned: %s   |   Standing: %d/%d (%s%d this week)   |   %d signed, %d walked out" \
		% [Format.money(bonus), run.standing, run.cfg.standing_start,
			"+" if standing >= 0 else "", standing, signed, walked]

	# What the next week holds, from the run's own calendar - its first quota,
	# and whoever is waiting at the end of it.
	var next_first: int = run.shift_number
	var next_last: int = mini(next_first + per_week - 1, run.cfg.shifts_in_run)
	_next.text = "Monday's quota is %s, and it climbs every day." \
		% Format.money(run.quota_for(next_first))
	if run.week != null:
		var finale := run.week.offers(next_last)
		if finale.size() == 1 and finale[0].is_boss_day():
			_next.text += " %s: %s - boss day." % [
				_day_name(next_last - 1, per_week).capitalize(), finale[0].display_name]
	_start.text = "START WEEK %d" % (week + 1)

func _day_name(d: int, per_week: int) -> String:
	return ["MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY",
		"SUNDAY"][d % per_week % 7]

func _cell(text: String, size: int, role: StringName, heading: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Palette.color(role))
	if heading:
		l.theme_type_variation = &"Heading"
	_days.add_child(l)
	return l
