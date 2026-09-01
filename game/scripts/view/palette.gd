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
}

static func color(role: StringName) -> Color:
	if not ROLES.has(role):
		push_error("Palette: unknown role %s" % role)
		return Color.MAGENTA
	return Color(ROLES[role])
