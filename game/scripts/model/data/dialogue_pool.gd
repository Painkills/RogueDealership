class_name DialoguePool extends Resource
## Every line anybody can say, in one library, divided by TAG rather than by
## file. Same shape as InterestPool and CardPool: a design_rule, one array,
## and lookups that build a fresh filtered array and never mutate this one.

@export_multiline var design_rule: String
## The declared vocabulary. Nothing enforces a tag at runtime - an undeclared
## tag is not an error, it is a line that quietly never appears - so the suite
## enforces it instead, on both the lines and the cards that ask for them.
@export var known_tags: Array[StringName] = []
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
		product_id: StringName, band: StringName) -> Array[DialogueLine]:
	## Deterministic and rng-free on purpose: every filtering rule in this
	## system is testable through here without a seed anywhere in the test.
	var out: Array[DialogueLine] = []
	for l in lines:
		if l.carries(tags) and l.fits(archetype_id, product_id, band):
			out.append(l)
	return out


func weight_of(l: DialogueLine) -> int:
	var w := 1
	for _i in range(l.specificity()):
		w *= specificity_bias
	return w


func pick(rng: RandomNumberGenerator, tags: Array[StringName],
		archetype_id: StringName, product_id: StringName,
		band: StringName) -> String:
	## Returns "" when nothing fits, which every caller already treats as
	## "they said nothing" - SpeechBubble.say() no-ops on an empty string and
	## _drain_log() skips the line.
	var pool := candidates(tags, archetype_id, product_id, band)
	if pool.is_empty():
		return ""
	var total := 0
	for l in pool:
		total += weight_of(l)
	var roll := rng.randi_range(0, total - 1)
	for l in pool:
		roll -= weight_of(l)
		if roll < 0:
			return l.text
	return pool[pool.size() - 1].text
