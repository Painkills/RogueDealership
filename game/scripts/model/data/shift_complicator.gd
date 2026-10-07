class_name ShiftComplicator extends Resource
## A twist the calendar can add to a premade shift that scales - one without a
## lineup of its own (see ShiftProfile.difficulty) - to bring it up to a harder
## slot's difficulty target alongside tougher customers. Short Staffed in week 2
## is still a hand of 4, plus, say, a tougher crowd. Pure data: each field is a
## change to the shift's own rules, combined with them in ShiftProfile's
## ticks_on(), hand_on() and total_*(). See ShiftGenerator for how they are
## picked, and ShiftProfilePool.complicators for where they live.

@export var id: StringName
## What the calendar's rules line says about it - "Line +2".
@export var display_text: String
## How much harder it makes a shift, in CustomerArchetype.difficulty points -
## see tools/rate_shifts.gd.
@export var points: int = 1
## The first day of the run it may be added on.
@export var from_day: int = 1

@export_group("What it changes")
## Added to every customer's Line as they sit down.
@export var line_offset: int = 0
## Added to the shift's ticks - negative is a shorter day.
@export var ticks_delta: int = 0
## Multiplies every customer's patience.
@export var patience_scale: float = 1.0
## Added to the hand you draw to - negative is a smaller hand.
@export var hand_size_delta: int = 0
## Multiplies every customer's combo step.
@export var combo_scale: float = 1.0
## Multiplies the shift's quota - 1.2 asks 20% more of the day's.
@export var quota_scale: float = 1.0
@export_group("")

## May also be dealt onto a regular shift, not only a premade one that scales -
## how a slot's difficulty target can be spent on a harder quota.
@export var on_regular_shifts: bool = false

## Which of the rules it changes - &"line", &"ticks", &"patience", &"hand",
## &"combo", &"quota". Never added to a shift that sets one of them itself, or alongside
## another complicator that changes the same one.
func touches() -> Array[StringName]:
	var out: Array[StringName] = []
	if line_offset != 0:
		out.append(&"line")
	if ticks_delta != 0:
		out.append(&"ticks")
	if patience_scale != 1.0:
		out.append(&"patience")
	if hand_size_delta != 0:
		out.append(&"hand")
	if combo_scale != 1.0:
		out.append(&"combo")
	if quota_scale != 1.0:
		out.append(&"quota")
	return out
