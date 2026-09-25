class_name TutorialCoach extends CanvasLayer
## The practice shift's teacher: a training memo pinned over the shift log,
## and a highlighter frame around whatever it is talking about.
##
## It teaches by WATCHING rather than by being wired into every command. Each
## step either waits for NEXT, or waits for something to have happened on the
## table - read straight off the model's own counters (a dig, a placement, a
## sale, a signature) or the view's state (their card turned over). So the
## lesson runs on the real rules, and nothing about how a card is played has to
## know a tutorial exists.
##
## Counts are cumulative from the START of the tutorial, not from the start of
## each step. Someone who digs a card while still reading about their hand has
## dug a card: when the dig step comes round it is already done, and the memo
## moves straight past it rather than asking them to do it again.

signal finished(completed: bool)

## One entry per memo. "wait" is &"next" for a memo you read and dismiss, or
## the thing that has to happen on the table before it moves on. "targets" are
## what the highlighter frames - see ShiftController.screen_rect_of().
const STEPS := [
	{"id": &"welcome", "title": "Welcome to the F&I office",
		"body": "The car's already sold. Your job is everything that goes with it - warranties, GAP, protection plans. This practice shift walks you through one customer.",
		"wait": &"next", "button": "LET'S GO", "targets": []},
	{"id": &"customer", "title": "This is your customer",
		"body": "Their file: who they are, what kind of buyer they are, and their patience. When patience runs out they walk - and a walkout costs you standing.",
		"wait": &"next", "targets": [&"customer"]},
	{"id": &"details", "title": "Read their file",
		"body": "Hover over their card to turn it over - on a phone, tap it once. The back tells you how this kind of buyer behaves.",
		"wait": &"flipped", "prompt": "Turn their card over to carry on.",
		"targets": [&"customer"]},
	{"id": &"sit", "title": "Sit down with them",
		"body": "Click their card to sit at their desk - on a phone, tap it again. Walking between desks is free, and your cards come up when you sit.",
		"wait": &"seated", "prompt": "Sit down with them to carry on.",
		"targets": [&"customer"]},
	{"id": &"hand", "title": "Your hand",
		"body": "Products (orange) are what you sell. Support cards (purple) help you sell them. Almost every card you play costs a tick.",
		"wait": &"next", "targets": [&"hand"]},
	{"id": &"dig", "title": "Dig for something better",
		"body": "Don't want a card? Drag it onto the DISCARD pile - Small Talk, say. You draw a fresh one, but digging burns a tick.",
		"wait": &"dug", "prompt": "Dig a card to carry on.", "targets": [&"discard"]},
	{"id": &"clock", "title": "The clock is everyone's",
		"body": "See the tick counter go up? That clock runs the whole floor. Every tick you spend here, every customer waiting loses patience too - so spend them where they count.",
		"wait": &"next", "targets": [&"clock"]},
	{"id": &"place", "title": "Put a product in front of them",
		"body": "Drag a product (orange) onto the table in front of them. Its sheet slides out beside it. Placing costs a tick.",
		"wait": &"placed", "prompt": "Place a product to carry on.", "targets": [&"table"]},
	{"id": &"meter", "title": "Read the offer",
		"body": "The bar is the product's Appeal; the mark is their Line. Appeal has to reach the Line before they'll buy. Their Line is normally hidden until you work it out - this time you can see it.",
		"wait": &"next", "targets": [&"offer_detail"]},
	{"id": &"support", "title": "Sweeten the deal",
		"body": "Drag Explain the Product onto the table. Support cards push Appeal up - and they cost a tick too.",
		"wait": &"supported", "prompt": "Play a support card to carry on.",
		"targets": [&"hand", &"table"]},
	{"id": &"offer", "title": "Make the offer",
		"body": "That clears their Line. Drag the product onto them, or press OFFER. Offering is free - but an offer that falls short costs them patience.",
		"wait": &"sold", "prompt": "Make the offer to carry on.",
		"hint": "Not enough Appeal yet - play Explain the Product, then offer again.",
		"targets": [&"customer", &"offer_button"]},
	{"id": &"close", "title": "Get it signed",
		"body": "They said yes - but it isn't money until they sign. Press CLOSE, or double-click their empty table. Anything unsigned when the shift ends is lost.",
		"wait": &"signed", "prompt": "Close the deal to carry on.",
		"targets": [&"close_button", &"table"]},
	{"id": &"done", "title": "That's the job",
		"body": "Real shifts have three desks, a quota, and customers who push back. Watch the clock - it's everyone's.",
		"wait": &"next", "button": "START MY FIRST SHIFT", "targets": []},
]

@onready var _highlight: TutorialHighlight = %Highlight
@onready var _memo: Control = %Memo
@onready var _step_label: Label = %StepLabel
@onready var _title: Label = %TitleLabel
@onready var _body: Label = %BodyLabel
@onready var _hint: Label = %HintLabel
@onready var _prompt: Label = %PromptLabel
@onready var _next: Button = %NextButton
@onready var _skip: Button = %SkipButton

var _floor = null            ## the ShiftController being taught on
var _step := -1
var _start_stat := {}        ## the shift's counters when the tutorial began
var _step_stat := {}         ## and when the current memo went up
## The product whose Line was last tuned - see Tutorial.tune_line(). Re-tuned
## for a fresh product until the first sale, so swapping products mid-lesson
## still leaves exactly one support card between them and a yes.
var _tuned_uid := -1

func _ready() -> void:
	visible = false
	set_process(false)
	_next.pressed.connect(_on_next)
	_skip.pressed.connect(func(): _finish(false))

func start(floor_view) -> void:
	_floor = floor_view
	_tuned_uid = -1
	var shift: Shift = _floor.current_shift()
	_start_stat = shift.stat.duplicate() if shift != null else {}
	visible = true
	set_process(true)
	_go(0)

func stop() -> void:
	visible = false
	set_process(false)
	_floor = null
	_step = -1
	_highlight.set_rects([])

func is_running() -> bool:
	return _floor != null and _step >= 0

func step_id() -> StringName:
	return STEPS[_step]["id"] if _step >= 0 and _step < STEPS.size() else &""

func _go(i: int) -> void:
	_step = i
	var s: Dictionary = STEPS[i]
	var shift: Shift = _floor.current_shift()
	_step_stat = shift.stat.duplicate() if shift != null else {}
	_step_label.text = "%d / %d" % [i + 1, STEPS.size()]
	_title.text = s["title"]
	_body.text = s["body"]
	_hint.visible = false
	var waits: bool = s["wait"] != &"next"
	_next.visible = not waits
	_next.text = s.get("button", "NEXT")
	# Nothing left to skip on the last memo - and its wider button would push
	# the memo out over the nearest desk.
	_skip.visible = i < STEPS.size() - 1
	_prompt.visible = waits
	_prompt.text = s.get("prompt", "")
	_update_highlight()

func _on_next() -> void:
	if _step < 0:
		return
	if _step >= STEPS.size() - 1:
		_finish(true)
	else:
		_go(_step + 1)

func _finish(completed: bool) -> void:
	stop()
	finished.emit(completed)

func _process(_delta: float) -> void:
	if not is_running():
		return
	var shift: Shift = _floor.current_shift()
	if shift == null:
		return
	# The deck viewer covers the floor, and a highlight pointing through it at
	# something you cannot see is worse than no highlight at all.
	visible = not _floor.hud_dimmed()
	_tune_the_line(shift)
	_update_highlight()
	var s: Dictionary = STEPS[_step]
	if s["wait"] == &"next":
		return
	if s.has("hint") and _since_step(shift, "failed_offers") > 0:
		_hint.text = s["hint"]
		_hint.visible = true
	if _met(s["wait"], shift):
		_go(_step + 1)

## Checked every frame, not only on its own step, so it holds whenever the
## first product actually lands - a player is free to put one down early.
func _tune_the_line(shift: Shift) -> void:
	if int(shift.stat.get("sales", 0)) > int(_start_stat.get("sales", 0)):
		return
	var c = shift.chairs[0] if not shift.chairs.is_empty() else null
	if c == null or c.offer == null or c.offer.instance.uid == _tuned_uid:
		return
	if Tutorial.tune_line(c):
		_tuned_uid = c.offer.instance.uid
		_floor.refresh()

func _met(wait: StringName, shift: Shift) -> bool:
	match wait:
		&"flipped": return _floor.customer_showing_back(0)
		&"seated": return shift.at != null and int(shift.at) == 0
		&"dug": return _since_start(shift, "digs") > 0
		&"placed": return _since_start(shift, "places") > 0
		&"supported": return _since_start(shift, "cards_played") > 0
		&"sold": return _since_start(shift, "sales") > 0
		&"signed": return _since_start(shift, "customers_signed") > 0
	return false

func _since_start(shift: Shift, key: String) -> int:
	return int(shift.stat.get(key, 0)) - int(_start_stat.get(key, 0))

func _since_step(shift: Shift, key: String) -> int:
	return int(shift.stat.get(key, 0)) - int(_step_stat.get(key, 0))

func _update_highlight() -> void:
	if _floor == null or _step < 0:
		return
	var rects: Array[Rect2] = []
	for t in STEPS[_step]["targets"]:
		var r: Rect2 = _floor.screen_rect_of(t)
		if r.size.x > 0.0 and r.size.y > 0.0:
			rects.append(r)
	_highlight.set_rects(rects)

## Where the memo sits - the drivers check that nothing it points at is under it.
func memo_rect() -> Rect2:
	return _memo.get_global_rect()
