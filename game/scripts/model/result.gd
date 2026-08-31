class_name Result extends RefCounted
## Outcome of one attempted action.
##
## ok == false means the rules refused and NOTHING was spent - not the tick,
## not the card. That convention is what makes a misclick harmless, and it is
## load-bearing.

var ok: bool
var msg: String
var kind: String
var data: Dictionary

func _init(p_ok: bool, p_msg: String, p_kind: String = "invalid",
		p_data: Dictionary = {}) -> void:
	ok = p_ok
	msg = p_msg
	kind = p_kind
	data = p_data
