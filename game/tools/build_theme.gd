extends SceneTree
## Builds res://theme/fi_theme.tres - the project-wide theme (project.godot's
## gui/theme/custom), so every Button and Label in the game dresses for the F&I
## office without each screen's builder restyling its own.
##
##     godot --headless --path game --script res://tools/build_theme.gd
##
## Built by script for the same reason every scene here is: a theme edited by
## hand in the inspector drifts away from Palette, and one built from it cannot.
##
## Deliberately NOT here: a default PanelContainer style. This project uses
## PanelContainer as a layout wrapper as often as a visible panel (the tap
## targets over the tick and standing counters, every hairline rule), so a
## default sheet of paper would appear wherever a wrapper forgot to opt out.
## Every visible panel sets its own style instead.

const OUT := "res://theme/fi_theme.tres"

func _init() -> void:
	var t := Theme.new()

	# --- words: ink on paper --------------------------------------------
	t.set_color("font_color", "Label", Palette.color(&"text"))
	t.set_color("default_color", "RichTextLabel", Palette.color(&"text"))

	# --- buttons: rubber stamps (see StampStyle) ---------------------------
	var ink := Palette.color(&"ink")
	t.set_stylebox("normal", "Button", StampStyle.box(Palette.color(&"paper"), ink, 3))
	t.set_stylebox("hover", "Button", StampStyle.box(Palette.color(&"panel_hi"), ink, 4))
	t.set_stylebox("pressed", "Button", StampStyle.box(ink, ink, 3))
	t.set_stylebox("hover_pressed", "Button", StampStyle.box(ink, ink, 4))
	t.set_stylebox("disabled", "Button", StampStyle.box(Palette.color(&"paper_shade"),
		Palette.color(&"neutral_3"), 2))
	# No focus ring. The invisible tap targets over the tick, standing and quota
	# counters are Buttons, and a ring drawn around an invisible button after a
	# tap is a rectangle floating over nothing.
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", Palette.color(&"ink"))
	t.set_color("font_hover_color", "Button", Palette.color(&"ink"))
	t.set_color("font_focus_color", "Button", Palette.color(&"ink"))
	t.set_color("font_pressed_color", "Button", Palette.color(&"paper"))
	t.set_color("font_hover_pressed_color", "Button", Palette.color(&"paper"))
	t.set_color("font_disabled_color", "Button", Palette.color(&"ink_dim"))

	# --- meters: a filled bar ruled onto the page -------------------------
	var trough := StyleBoxFlat.new()
	trough.bg_color = Palette.color(&"paper_shade")
	trough.border_color = Palette.color(&"neutral_3")
	trough.set_border_width_all(2)
	trough.set_corner_radius_all(3)
	t.set_stylebox("background", "ProgressBar", trough)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Palette.color(&"money")
	fill.set_corner_radius_all(3)
	t.set_stylebox("fill", "ProgressBar", fill)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT.get_base_dir()))
	var err := ResourceSaver.save(t, OUT)
	if err != OK:
		push_error("failed to save %s: %d" % [OUT, err])
		quit(1)
		return
	print("saved %s" % OUT)
	quit(0)
