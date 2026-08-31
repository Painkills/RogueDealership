class_name InterestPool extends Resource
## The whole board, plus the constraint new content must obey.

@export_multiline var design_rule: String
@export var categories: Array[Category]
@export var interests: Array[Interest]

func count() -> int:
	return interests.size()

func by_id(wanted: StringName) -> Interest:
	for i in interests:
		if i.id == wanted:
			return i
	return null

func in_category(c: Category) -> Array[Interest]:
	var out: Array[Interest] = []
	for i in interests:
		if i.category == c:
			out.append(i)
	return out
