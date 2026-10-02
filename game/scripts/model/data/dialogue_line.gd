class_name DialogueLine extends Resource
## One thing a customer can say, plus the circumstances it fits.
##
## `tags` is which library it belongs to and is the only REQUIRED match - a
## line with no tags can never be drawn. The other four are FILTERS, and an
## empty one means "any": a line with no archetype_ids fits every archetype,
## while a line naming karen fits only her and is excluded outright for
## anybody else. Narrowing is therefore additive and a line can never widen
## itself by accident.
##
## Every extra filter a line carries makes it more SPECIFIC, and DialoguePool
## weights the draw by that - see specificity() below. objection_ids is the
## exception that goes further: see DialoguePool.candidates().

@export_multiline var text: String
## Which pool(s) this belongs to. Must be declared in DialoguePool.known_tags;
## a typo here is otherwise a line that silently never appears again.
@export var tags: Array[StringName] = []
@export var archetype_ids: Array[StringName] = []
@export var product_ids: Array[StringName] = []
## One of whatever Shift.band_for() returns - INTERESTED / ALMOST / WARM /
## COOL / COLD.
@export var appeal_bands: Array[StringName] = []
## The customer's open objection(s) this line answers - "It's too expensive"
## answered with the word track written for it. With no objection open, a line
## naming one is unavailable, the same way a line naming a product is with an
## empty table. Must be declared in DialoguePool.known_objections.
@export var objection_ids: Array[StringName] = []
## Saying this line opens (or changes) the customer's objection: how raising
## "It's too expensive" opens it, and how the answer to "is it the payment, or
## the coverage?" turns a "No thanks" into the real objection. &"" changes
## nothing. Also declared in DialoguePool.known_objections.
@export var becomes: StringName = &""
## Pairs a line of YOURS with the replies written for it. "Love the jacket"
## must not be answered with "the parking lot was a maze": a line with a key
## is answered only by lines whose replies_to names it - and by nothing at
## all, rather than by something that makes no sense, where none fits.
@export var key: StringName = &""
## The keys of the lines this one answers. Empty: it answers any line that
## has no key (a generic "Thanks. I appreciate that.").
@export var replies_to: Array[StringName] = []


func carries(wanted: Array[StringName]) -> bool:
	## True if this line belongs to ANY of the pools the card draws from.
	for t in tags:
		if wanted.has(t):
			return true
	return false


func fits(archetype_id: StringName, product_id: StringName,
		band: StringName, objection: StringName = &"",
		answering: StringName = &"") -> bool:
	## Hard exclusion, not a preference: a line that names a product is not
	## merely less likely with nothing on the table, it is unavailable. That
	## is what makes an empty table (product_id and band both &"") fall back
	## to the unfiltered lines rather than saying something about a car that
	## is not there - and no objection open fall back to the lines that answer
	## none.
	if not archetype_ids.is_empty() and not archetype_ids.has(archetype_id):
		return false
	if not product_ids.is_empty() and not product_ids.has(product_id):
		return false
	if not appeal_bands.is_empty() and not appeal_bands.has(band):
		return false
	if not objection_ids.is_empty() and not objection_ids.has(objection):
		return false
	# Answering a keyed line: only what was written for it. Answering anything
	# else: only what was written for no line in particular.
	if answering != &"":
		return replies_to.has(answering)
	return replies_to.is_empty()


func answers_an_objection() -> bool:
	return not objection_ids.is_empty()


func specificity() -> int:
	## How many of the optional filters this line actually uses. 0 is a
	## generic fallback; a line written for one archetype looking at one
	## product at one distance from their line is 3, and answering one
	## objection makes it 4.
	var n := 0
	if not archetype_ids.is_empty():
		n += 1
	if not product_ids.is_empty():
		n += 1
	if not appeal_bands.is_empty():
		n += 1
	if not objection_ids.is_empty():
		n += 1
	if not replies_to.is_empty():
		n += 1
	return n
