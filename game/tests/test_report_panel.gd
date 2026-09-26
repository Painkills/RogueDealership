extends RefCounted
## report_panel.gd's own visual completeness: every label actually gets a
## color, not just the ones that happened to already have one. Four of the
## nine used to render in whatever Godot's default Label color is, on a panel
## that had no background style of its own either - low-contrast by accident,
## never by design, and nothing here would have caught it before now.
var h: Harness

const SCENE := "res://scenes/report.tscn"

func _instance():
	return (load(SCENE) as PackedScene).instantiate()

## Every key setup() reads, with harmless defaults - so each test overrides
## only the field it actually cares about rather than repeating this whole
## shape nine times.
func _report(overrides: Dictionary = {}) -> Dictionary:
	var r := {
		"margin_banked": 4000, "quota": 3600, "made_quota": true,
		"customers_seen": 5, "customers_signed": 3, "customers_walked": 1,
		"offers": 4, "sales": 3, "close_rate": 0.75, "failed_offers": 1,
		"margin_conceded": 200, "margin_padded": 100, "margin_bonus": 0,
		"margin_lost_to_walks": 0, "margin_lost_to_closing": 0,
		"standing_delta": 5, "standing_lost_to_walkouts": 0,
		"standing_before": 90, "standing_after": 95, "standing_start": 100,
	}
	for k in overrides:
		r[k] = overrides[k]
	return r

func test_every_label_gets_an_explicit_color_not_the_engine_default() -> void:
	## The exact gap: four of nine labels never called add_theme_color_override
	## at all before this, so they rendered in whatever Label's built-in
	## default happens to be - readable only by accident, on a panel that had
	## no themed background of its own either.
	var p = _instance()
	p.setup(_report())
	for uname in ["_title", "_banked", "_bonus", "_standing", "_walkouts",
			"_customers", "_offers", "_margin", "_lost"]:
		var l: Label = p.get(uname)
		h.check("%s carries an explicit font color" % uname,
			l.has_theme_color_override("font_color"))
	h.check("and so does the button", p._restart.has_theme_color_override("font_color"))
	p.free()

func test_lost_margin_reads_alert_only_when_something_was_actually_lost() -> void:
	var p = _instance()
	p.setup(_report({"margin_lost_to_walks": 500, "margin_lost_to_closing": 0}))
	h.eq("something lost reads as alert", p._lost.get_theme_color("font_color"),
		Palette.color(&"alert"))
	p.free()

	var q = _instance()
	q.setup(_report({"margin_lost_to_walks": 0, "margin_lost_to_closing": 0}))
	h.eq("nothing lost reads as a quiet detail, not a warning",
		q._lost.get_theme_color("font_color"), Palette.color(&"text_dim"))
	q.free()

func test_the_secondary_stats_are_a_quiet_detail_not_a_warning() -> void:
	## Customers/Offers/MarginMoved have no good-or-bad reading of their own
	## the way Lost does - they are context, not a verdict, so they stay
	## text_dim regardless of what happened.
	var p = _instance()
	p.setup(_report())
	for uname in ["_customers", "_offers", "_margin"]:
		var l: Label = p.get(uname)
		h.eq("%s is a quiet supporting detail" % uname,
			l.get_theme_color("font_color"), Palette.color(&"text_dim"))
	p.free()

func test_the_button_matches_the_titles_verdict() -> void:
	var p = _instance()
	p.setup(_report({"standing_after": 0}))   # fired
	h.eq("fired turns the button red, like everything that ends something",
		(p._restart.get_theme_stylebox("normal") as StyleBoxFlat).bg_color,
		Palette.color(&"stamp"))
	p.free()

	var q = _instance()
	q.setup(_report({"standing_after": 50}))   # not fired
	h.eq("an ordinary continue is the house blue",
		(q._restart.get_theme_stylebox("normal") as StyleBoxFlat).bg_color,
		Palette.color(&"primary"))
	h.eq("with white words either way",
		q._restart.get_theme_color("font_color"), Palette.color(&"paper"))
	q.free()

func test_it_is_a_report_on_a_screen_over_the_floor() -> void:
	## "Make all report or UI screens look like some digital thing": the
	## dealership system's end-of-day report, in an app window, over the floor
	## you just worked - dimmed, not hidden.
	var p = _instance()
	var style: StyleBox = p.get_theme_stylebox("panel")
	h.check("carries its own StyleBoxFlat", style is StyleBoxFlat)
	var ground := (style as StyleBoxFlat).bg_color
	h.check("the desktop behind the window (%s)" % ground,
		Color(ground, 1.0).is_equal_approx(Palette.color(&"desktop")))
	h.check("see-through, so the floor still shows (%.2f)" % ground.a,
		ground.a > 0.5 and ground.a < 1.0)
	var window = p.get_node_or_null(^"%ReportWindow")
	h.check("in an app window", window is PanelContainer)
	h.check("with a title bar", window != null
		and window.get_node_or_null(^"WindowColumn/TitleBar") != null)
	p.free()
