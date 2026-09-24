class_name Palette extends RefCounted
## Every color in the game is looked up by ROLE, never written as a literal
## hex in a scene script - so the whole palette can be repainted by editing
## this one file. Static methods, not an autoload: godot --headless --script
## (this project's whole test invocation) never instantiates autoloads, and
## since this class is pure and stateless it needs no instance anyway.
##
## THE F&I OFFICE. Every surface you read is paper - cream card stock, manila
## folders, a clipboard - and everything printed on it is ink: navy for the
## words, a rubber-stamp red for anything urgent, ledger green for money. The
## screen roles below were all repainted from a dark-panel scheme to that one at
## once, which is what "repaint by editing this one file" is for: a role that
## used to be pale text on a dark panel is now dark ink on paper, and every
## screen that asked for it by role followed without being touched.
##
## The one rule that makes it hold: a role that names TEXT must be dark enough
## to read on "panel", and a role that names a SURFACE must be light enough to
## carry "text". The office itself - the walnut, the wall, the carpet - is the
## only dark thing left, and nothing is ever printed directly on it.

const ROLES := {
	# --- surfaces ----------------------------------------------------------
	&"bg": "e6dcc3",          ## a full screen's ground: the manila desk blotter
	&"panel": "f4ecd8",       ## card stock - every card face
	&"panel_hi": "fbf7ec",    ## brighter paper on top of it: insets, sheets, bubbles
	# --- ink ---------------------------------------------------------------
	&"text": "1f2a44",
	&"text_dim": "5b6378",
	&"appeal": "2c5fa8",
	&"margin": "2f6b3f",      ## money is ledger green on paper; gold vanished on cream
	&"patience_ok": "4f8f45",
	&"patience_warn": "c88a12",
	&"patience_bad": "b3261e",
	&"action": "6b3fa0",
	&"alert": "b3261e",
	&"accent": "b0561c",
	# --- rules and edges, drawn on paper -----------------------------------
	&"neutral_1": "1a1410",   ## near-black: numerals on a coloured cell, a meter's frame
	&"neutral_2": "cdbf9c",   ## a hairline rule
	&"neutral_3": "9a8b6a",   ## a card's own edge
	# --- the F&I office: paper, ink and rubber stamps on a walnut desk ------
	# For the things that are ONLY ever one of these - a stamp, a sticky note,
	# the desk itself - rather than a role that happens to be printed that way.
	&"paper": "f4ecd8",
	&"paper_shade": "e3d5b4",
	&"ink": "1f2a44",
	&"ink_dim": "5b6378",
	&"stamp": "b3261e",
	&"money": "2f6b3f",
	&"brass": "b8893a",
	&"brass_dark": "7a5a12",
	&"sticky": "f7d64a",
	&"manila": "d9c49a",
	&"board": "7a5334",       ## a clipboard's hardboard back
	&"walnut": "5a3823",
	&"walnut_dark": "35200f",
	&"wall": "2c3342",
	&"carpet": "221d21",
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
## Preferred is brass - the one metal in the office, and the colour of the
## trim on every desk - so it still reads as "valuable" now that the money
## line it used to borrow from is ledger green.
static func rarity_color(rarity: CardDef.Rarity) -> Color:
	match rarity:
		CardDef.Rarity.BASIC: return color(&"text_dim")
		CardDef.Rarity.ECONOMY: return color(&"text")
		CardDef.Rarity.VALUE: return color(&"appeal")
		CardDef.Rarity.PREFERRED: return color(&"brass_dark")
		_: return color(&"text")
