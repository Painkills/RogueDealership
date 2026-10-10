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

## Plain data, for a save: every card as [card id, uid, upgraded], and the uid
## the next card gets.
func snapshot() -> Dictionary:
	var out: Array = []
	for c in cards:
		out.append([c.card.id, c.uid, c.upgraded])
	return {"cards": out, "next_uid": _next_uid}

## The deck snapshot() wrote, its cards looked up in `pool` by id. A card the
## pool no longer has is left out.
static func from_snapshot(data: Dictionary, pool: CardPool) -> Deck:
	var d := Deck.new()
	for entry in data.get("cards", []):
		var def := pool.by_id(StringName(entry[0]))
		if def == null:
			continue
		var inst := CardInstance.new(def, int(entry[1]))
		inst.upgraded = bool(entry[2])
		d.cards.append(inst)
	d._next_uid = int(data.get("next_uid", d._next_uid))
	return d
