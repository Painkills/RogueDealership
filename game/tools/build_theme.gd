extends SceneTree
## Builds res://theme/fi_theme.tres - the project-wide theme (project.godot's
## gui/theme/custom), so every Button and Label in the game dresses for the
## showroom without each screen's builder restyling its own.
##
##     godot --headless --path game --script res://tools/build_theme.gd
##
## Built by script for the same reason every scene here is: a theme edited by
## hand in the inspector drifts away from Palette, and one built from it cannot.
##
## Two typefaces: the engine's own default for reading, and Oswald - condensed,
## the dashboard-and-signage face - for anything you glance at rather than
## read: buttons, headings, the HUD's numbers. Any Label opts into Oswald with
## theme_type_variation = &"Heading"; see heading_font() for builders that need
## the face itself.
##
## Deliberately NOT here: a default PanelContainer style. This project uses
## PanelContainer as a layout wrapper as often as a visible panel (the tap
## targets over the tick and standing counters, every hairline rule), so a
## default card would appear wherever a wrapper forgot to opt out. Every
## visible panel sets its own style instead.

const OUT := "res://theme/fi_theme.tres"
const OSWALD := "res://theme/fonts/Oswald-Variable.ttf"
## Oswald's weight axis runs 200-700. Semibold reads as a heading without
## shouting; the buttons use the same.
const HEADING_WEIGHT := 600

func _init() -> void:
	var t := Theme.new()
	var heading := heading_font()

	# --- words -----------------------------------------------------------
	t.set_color("font_color", "Label", Palette.color(&"text"))
	t.set_color("default_color", "RichTextLabel", Palette.color(&"text"))
	# A Label that is a heading, not a sentence: set theme_type_variation.
	t.set_type_variation("Heading", "Label")
	t.set_font("font", "Heading", heading)

	# --- buttons: outlined by default, see ButtonStyle ---------------------
	var ink := Palette.color(&"ink")
	var edge := Palette.color(&"neutral_3")
	var white := Palette.color(&"paper")
	t.set_font("font", "Button", heading)
	t.set_stylebox("normal", "Button", ButtonStyle.box(white, edge, 2))
	t.set_stylebox("hover", "Button", ButtonStyle.box(Palette.color(&"panel_hi"),
		Palette.color(&"primary"), 2))
	t.set_stylebox("pressed", "Button", ButtonStyle.box(Palette.color(&"primary"),
		Palette.color(&"primary"), 2))
	t.set_stylebox("hover_pressed", "Button", ButtonStyle.box(
		Palette.color(&"primary").lightened(0.08), Palette.color(&"primary"), 2))
	t.set_stylebox("disabled", "Button", ButtonStyle.box(Palette.color(&"paper_shade"),
		Palette.color(&"neutral_2"), 2))
	# No focus ring. The invisible tap targets over the tick, standing and quota
	# counters are Buttons, and a ring drawn around an invisible button after a
	# tap is a rectangle floating over nothing.
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", ink)
	t.set_color("font_hover_color", "Button", Palette.color(&"primary"))
	t.set_color("font_focus_color", "Button", ink)
	t.set_color("font_pressed_color", "Button", white)
	t.set_color("font_hover_pressed_color", "Button", white)
	t.set_color("font_disabled_color", "Button", Palette.color(&"ink_dim"))

	# --- meters: a rounded bar in a pale trough ----------------------------
	var trough := StyleBoxFlat.new()
	trough.bg_color = Palette.color(&"paper_shade")
	trough.set_corner_radius_all(8)
	t.set_stylebox("background", "ProgressBar", trough)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Palette.color(&"money")
	fill.set_corner_radius_all(8)
	t.set_stylebox("fill", "ProgressBar", fill)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT.get_base_dir()))
	var err := ResourceSaver.save(t, OUT)
	if err != OK:
		push_error("failed to save %s: %d" % [OUT, err])
		quit(1)
		return
	print("saved %s" % OUT)
	quit(0)

## Oswald at HEADING_WEIGHT - a variation on the one variable font file, so
## every weight the game ever wants costs no second download.
static func heading_font() -> FontVariation:
	var face := load(OSWALD) as FontFile
	var v := FontVariation.new()
	v.base_font = face
	var ts := TextServerManager.get_primary_interface()
	v.variation_opentype = {ts.name_to_tag("wght"): HEADING_WEIGHT}
	return v
