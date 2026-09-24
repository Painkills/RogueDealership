class_name Palette extends RefCounted
## Every color in the game is looked up by ROLE, never written as a literal
## hex in a scene script - so the whole palette can be repainted by editing
## this one file. Static methods, not an autoload: godot --headless --script
## (this project's whole test invocation) never instantiates autoloads, and
## since this class is pure and stateless it needs no instance anyway.

const ROLES := {
	&"bg": "1a1a2e",
	&"panel": "22223b",
	&"panel_hi": "2e2e4a",
	&"text": "f2f2f2",
	&"text_dim": "9a9ab0",
	&"appeal": "5da8f2",
	&"margin": "e8c15a",
	&"patience_ok": "6fcf6f",
	&"patience_warn": "e8c15a",
	&"patience_bad": "e05a5a",
	&"action": "c86fe0",
	&"alert": "e05a5a",
	&"accent": "f2925a",
	&"neutral_1": "0f0f1a",
	&"neutral_2": "3a3a5a",
	&"neutral_3": "555577",
	# --- the F&I office: paper, ink and rubber stamps on a walnut desk ------
	# Everything printed on paper uses these, never the screen roles above:
	# gold "margin" and pale "text" were chosen for dark panels, and on cream
	# they all but disappear.
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
	&"walnut": "6b4429",
	&"walnut_dark": "3d2616",
	&"wall": "262b37",
}

static func color(role: StringName) -> Color:
	if not ROLES.has(role):
		push_error("Palette: unknown role %s" % role)
		return Color.MAGENTA
	return Color(ROLES[role])

## Reuses existing roles rather than adding four rarity-specific ones -
## Preferred borrowing "margin" (the same gold every card's money line
## already uses) is deliberate: gold already reads as "valuable" here.
static func rarity_color(rarity: CardDef.Rarity) -> Color:
	match rarity:
		CardDef.Rarity.BASIC: return color(&"text_dim")
		CardDef.Rarity.ECONOMY: return color(&"text")
		CardDef.Rarity.VALUE: return color(&"appeal")
		CardDef.Rarity.PREFERRED: return color(&"margin")
		_: return color(&"text")
