class_name DiscardCards extends DemandResolve
## "Throw some away." Answered by setting `count` cards aside from your hand - dug,
## dragged to the discard pile - before the fuse runs out. Each costs a tick, as a
## dig always does, so the whole fuse can be spent on nothing else.

@export var count: int = 3

func satisfied(kind: StringName, data: Dictionary) -> bool:
	return kind == DISCARD and int(data.get("discards", 0)) >= count

func describe() -> String:
	return "discard %d cards" % count

func how_to_answer() -> String:
	return "Discard %d cards: drag them to the discard pile, or Shift + their number. Each one costs a tick." % count
