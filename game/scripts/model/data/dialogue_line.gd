class_name DialogueLine extends Resource
## One thing a customer can say, plus the circumstances it fits.
##
## `tags` is which library it belongs to and is the only REQUIRED match - a
## line with no tags can never be drawn. The other three are FILTERS, and an
## empty one means "any": a line with no archetype_ids fits every archetype,
## while a line naming karen fits only her and is excluded outright for
## anybody else. Narrowing is therefore additive and a line can never widen
## itself by accident.
##
## Every extra filter a line carries makes it more SPECIFIC, and DialoguePool
## weights the draw by that - see specificity() below.

@export_multiline var text: String
## Which pool(s) this belongs to. Must be declared in DialoguePool.known_tags;
## a typo here is otherwise a line that silently never appears again.
@export var tags: Array[StringName] = []
@export var archetype_ids: Array[StringName] = []
@export var product_ids: Array[StringName] = []
## One of whatever Shift.band_for() returns - ALMOST / WARM / COOL / COLD.
@export var appeal_bands: Array[StringName] = []


func carries(wanted: Array[StringName]) -> bool:
	## True if this line belongs to ANY of the pools the card draws from.
	for t in tags:
		if wanted.has(t):
			return true
	return false


func fits(archetype_id: StringName, product_id: StringName,
		band: StringName) -> bool:
	## Hard exclusion, not a preference: a line that names a product is not
	## merely less likely with nothing on the table, it is unavailable. That
	## is what makes an empty table (product_id and band both &"") fall back
	## to the unfiltered lines rather than saying something about a car that
	## is not there.
	if not archetype_ids.is_empty() and not archetype_ids.has(archetype_id):
		return false
	if not product_ids.is_empty() and not product_ids.has(product_id):
		return false
	if not appeal_bands.is_empty() and not appeal_bands.has(band):
		return false
	return true


func specificity() -> int:
	## How many of the three optional filters this line actually uses. 0 is a
	## generic fallback, 3 is a line written for one archetype looking at one
	## product at one distance from their line.
	var n := 0
	if not archetype_ids.is_empty():
		n += 1
	if not product_ids.is_empty():
		n += 1
	if not appeal_bands.is_empty():
		n += 1
	return n
