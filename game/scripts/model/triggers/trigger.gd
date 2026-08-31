class_name Trigger extends Resource
## When a customer action fires. Filters are what let one vocabulary serve
## both the Budget Hawk (any short offer) and Family First (any offer below
## their top five, short or not).

func matches(_ctx: EffectContext) -> bool:
	return false

func describe() -> String:
	return ""
