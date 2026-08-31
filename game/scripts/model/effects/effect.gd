class_name Effect extends Resource
## One verb.
##
## apply() does it; describe() says what it does, and the UI builds its text
## from describe() so the number on screen cannot drift from the number that
## executes. A new CARD is data - drag effects together. A new VERB is one
## small file like the ones beside this, and the engine never changes.

@export var amount: int = 0

func apply(_ctx: EffectContext) -> void:
	pass

func describe() -> String:
	return ""
