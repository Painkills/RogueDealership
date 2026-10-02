class_name DialoguePool extends Resource
## Every line anybody can say, in one library, divided by TAG rather than by
## file. Same shape as InterestPool and CardPool: a design_rule, one array,
## and lookups that build a fresh filtered array and never mutate this one.

@export_multiline var design_rule: String
## The declared vocabulary. Nothing enforces a tag at runtime - an undeclared
## tag is not an error, it is a line that quietly never appears - so the suite
## enforces it instead, on both the lines and the cards that ask for them.
@export var known_tags: Array[StringName] = []
## The same, for objections: every objection a line answers (objection_ids) or
## opens (becomes) has to be declared here, or a typo is a conversation that
## goes quiet halfway through.
@export var known_objections: Array[StringName] = []
## How hard a specific line outweighs a generic one: weight is this raised to
## the line's specificity, so at 3 a generic line weighs 1, an archetype line
## 3, archetype+band 9, all three 27.
##
## NOT a strict override. One karen-specific line must not make ten generic
## ones unreachable, or every karen in the game says the same sentence for the
## rest of the run - which is the opposite of the point. Turn this up for a
## tighter voice, down for more variety. It shapes the LIBRARY, not the rules,
## which is why it lives here and not in ShiftConfig with the game's numbers.
@export var specificity_bias: int = 3
@export var lines: Array[DialogueLine]


func count() -> int:
	return lines.size()


func candidates(tags: Array[StringName], archetype_id: StringName,
		product_id: StringName, band: StringName,
		objection: StringName = &"", answering: StringName = &"") -> Array[DialogueLine]:
	## Deterministic and rng-free on purpose: every filtering rule in this
	## system is testable through here without a seed anywhere in the test.
	##
	## Where lines answer the open objection, ONLY they are candidates - the one
	## place this library overrides rather than weights. An objection being
	## worked through is a conversation, and the answer written for it is THE
	## answer, not one option among the generic ones; those are what is left
	## where nothing was written for it.
	var out: Array[DialogueLine] = []
	var on_point: Array[DialogueLine] = []
	for l in lines:
		if l.carries(tags) and l.fits(archetype_id, product_id, band, objection, answering):
			out.append(l)
			if l.answers_an_objection():
				on_point.append(l)
	return on_point if not on_point.is_empty() else out


func weight_of(l: DialogueLine) -> int:
	var w := 1
	for _i in range(l.specificity()):
		w *= specificity_bias
	return w


func pick_line(rng: RandomNumberGenerator, tags: Array[StringName],
		archetype_id: StringName, product_id: StringName,
		band: StringName, objection: StringName = &"",
		avoid: Array = [], answering: StringName = &"") -> DialogueLine:
	## The line itself, for a caller that needs more than its words - what it
	## becomes, say. null when nothing fits.
	##
	## `avoid` is what the speaker said lately: skipped while anything else
	## fits, so playing the same card three times is three different sentences
	## rather than one sentence three times. `avoid` runs oldest first: when
	## everything that fits was said lately, the oldest of it is let back in
	## first, so the line just said is the last to repeat. Never silence - with
	## nothing else left, a repeat beats saying nothing.
	var pool := candidates(tags, archetype_id, product_id, band, objection, answering)
	var skip := avoid.duplicate()
	while not skip.is_empty():
		var fresh: Array[DialogueLine] = []
		for l in pool:
			if not skip.has(l.text):
				fresh.append(l)
		if not fresh.is_empty():
			pool = fresh
			break
		skip.pop_front()
	if pool.is_empty():
		return null
	var total := 0
	for l in pool:
		total += weight_of(l)
	var roll := rng.randi_range(0, total - 1)
	for l in pool:
		roll -= weight_of(l)
		if roll < 0:
			return l
	return pool[pool.size() - 1]


func pick(rng: RandomNumberGenerator, tags: Array[StringName],
		archetype_id: StringName, product_id: StringName,
		band: StringName, objection: StringName = &"", avoid: Array = []) -> String:
	## Returns "" when nothing fits, which every caller already treats as
	## "they said nothing" - SpeechBubble.say() no-ops on an empty string and
	## _drain_log() skips the line.
	var l := pick_line(rng, tags, archetype_id, product_id, band, objection, avoid)
	return l.text if l != null else ""
