extends RefCounted
var h: Harness

const POOL := "res://data/interests/interest_pool.tres"

func test_every_interest_has_an_id_a_name_and_a_category() -> void:
	var pool: InterestPool = load(POOL)
	var seen := {}
	for i in pool.interests:
		h.check("interest has an id", i.id != &"")
		h.check("%s has a display name" % i.id, i.display_name != "")
		h.check("%s has a category" % i.id, i.category != null)
		h.check("%s id is unique" % i.id, not seen.has(i.id))
		seen[i.id] = true

func test_lookup_by_id_finds_every_interest() -> void:
	var pool: InterestPool = load(POOL)
	for i in pool.interests:
		h.eq("by_id round-trips %s" % i.id, pool.by_id(i.id), i)
	h.eq("and returns null for a stranger", pool.by_id(&"nonsense"), null)
