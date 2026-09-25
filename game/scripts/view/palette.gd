class_name Palette extends RefCounted
## Every color in the game is looked up by ROLE, never written as a literal
## hex in a scene script - so the whole palette can be repainted by editing
## this one file. Static methods, not an autoload: godot --headless --script
## (this project's whole test invocation) never instantiates autoloads, and
## since this class is pure and stateless it needs no instance anyway.
##
## A MODERN F&I OFFICE. White cards on cool greys, near-black navy for the
## words, one house blue for whatever you are meant to press, and the usual
## signals on top: green for money, red for danger, amber for "not yet". It
## has been repainted twice from here - dark panels, then cream paper and
## rubber stamps, now this - which is what "repaint by editing this one file"
## is for: every screen that asks for a colour by role follows without being
## touched.
##
## The one rule that makes it hold: a role that names TEXT must be dark enough
## to read on "panel", and a role that names a SURFACE must be light enough to
## carry "text". The office itself - the wall, the floor, the desks' frames -
## is the only dark thing left, and nothing is ever printed directly on it.

const ROLES := {
	# --- surfaces ----------------------------------------------------------
	&"bg": "eef1f5",          ## a full screen's ground
	&"panel": "ffffff",       ## a card's face
	&"panel_hi": "f6f8fb",    ## an inset on a card: a sheet, a bubble, a lit row
	# --- ink ---------------------------------------------------------------
	&"text": "1b2330",
	&"text_dim": "5f6b7a",
	&"appeal": "2563eb",
	&"margin": "15803d",
	&"patience_ok": "2f9e5b",
	&"patience_warn": "d08b00",
	&"patience_bad": "dc2626",
	&"action": "7c3aed",
	&"alert": "dc2626",
	&"accent": "ea580c",
	# --- rules and edges ----------------------------------------------------
	&"neutral_1": "111827",   ## near-black: numerals on a coloured cell, a meter's frame
	&"neutral_2": "e2e6ec",   ## a hairline rule
	&"neutral_3": "b8c0cc",   ## a card's own edge
	# --- the showroom's own materials ----------------------------------------
	# For the things that are ONLY ever one of these - a button, a folder, the
	# desk itself - rather than a role that happens to be printed that way.
	&"paper": "ffffff",
	&"paper_shade": "e7ebf1",
	&"ink": "1b2330",
	&"ink_dim": "5f6b7a",
	&"primary": "2563eb",     ## the house blue: filled buttons, OFFER, today
	&"stamp": "dc2626",       ## danger: CLOSE, DROP PRODUCT, CLOSE SOON
	&"money": "15803d",
	&"brass": "e2b33c",       ## the one warm metal: the card backs' monogram
	&"brass_dark": "a16207",
	&"sticky": "facc15",      ## a highlighter - the tutorial's frame
	&"manila": "bfd0e8",      ## a file folder's front, in the showroom's blue
	&"manila_back": "93a9c9", ## its back flap, seen over the front
	# The interest grid, printed on the customer's white sheet. Every one of
	# these has to survive the table's light and a flanker's downscale - the
	# first pale-on-white pass washed out to a blank sheet.
	&"grid_cell": "dde4ee",   ## a box you have not filled in yet
	&"grid_lit": "cfe0fa",    ## a row Read the Room has pointed at
	&"grid_edge": "97a3b4",
	&"card_back_mark": "9db8f5",  ## the car on every card back, pale blue on navy
	&"photo_bg": "dde3ea",    ## the square a portrait will go in
	&"photo_figure": "9aa6b6",
	&"clip": "9aa3ad",
	&"desk_top": "e3e7ec",    ## a light laminate desk top
	&"desk_frame": "20242a",  ## its black steel frame and edge
	&"tablet": "0f141b",      ## the tablet's black glass edge
	&"chair": "2a2e35",       ## a black mesh office chair
	&"chair_base": "3b4048",
	&"wall": "243044",
	&"carpet": "3a4151",
	# The shift picker's calendar - one colour per kind of shift, the way a
	# calendar colours its events by what they are.
	&"shift_morning": "0ea5e9",
	&"shift_midday": "f59e0b",
	&"shift_night": "6366f1",
}

static func color(role: StringName) -> Color:
	if not ROLES.has(role):
		push_error("Palette: unknown role %s" % role)
		return Color.MAGENTA
	return Color(ROLES[role])

## The same, as the hex a RichTextLabel's [color=] tag takes - so the log's
## coloured lines come from the palette like everything else, rather than from
## bbcode's own named colours, which were chosen for a dark screen.
static func hex(role: StringName) -> String:
	return "#" + color(role).to_html(false)

## Reuses existing roles rather than adding four rarity-specific ones.
## Preferred is gold - the one warm metal in the showroom - so it reads as
## "valuable" at a glance.
static func rarity_color(rarity: CardDef.Rarity) -> Color:
	match rarity:
		CardDef.Rarity.BASIC: return color(&"text_dim")
		CardDef.Rarity.ECONOMY: return color(&"text")
		CardDef.Rarity.VALUE: return color(&"appeal")
		CardDef.Rarity.PREFERRED: return color(&"brass_dark")
		_: return color(&"text")
