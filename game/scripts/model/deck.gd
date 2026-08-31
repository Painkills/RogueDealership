class_name Deck extends RefCounted
## The run-level deck. Array of CardInstance, never of shared CardDef refs.

var cards: Array[CardInstance] = []
var _next_uid: int = 1

static func build_starting(pool: CardPool) -> Deck:
	var d := Deck.new()
	for def in pool.starter_cards():
		for _i in range(def.copies):
			d.add(def)
	return d

func add(def: CardDef) -> CardInstance:
	var inst := CardInstance.new(def, _next_uid)
	_next_uid += 1
	cards.append(inst)
	return inst

func remove(uid: int) -> bool:
	for i in range(cards.size()):
		if cards[i].uid == uid:
			cards.remove_at(i)
			return true
	return false

func upgrade(uid: int) -> bool:
	for c in cards:
		if c.uid == uid:
			c.upgraded = true
			return true
	return false
