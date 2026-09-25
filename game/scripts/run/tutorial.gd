class_name Tutorial extends RefCounted
## The practice shift that opens the game: one chair, one easygoing customer,
## and a hand dealt so every step the coach asks for is possible from the first
## card. The coach (TutorialCoach, in the view layer) does the talking; this
## only sets the table.
##
## A REAL Shift, not a mock of one. Everything the tutorial teaches - that a dig
## burns a tick, that a support card moves Appeal, that an agreed product is not
## money until it is signed - is the actual rule running, so nothing learned
## here is something the real game does differently.
##
## Outside the run on purpose: it deals from a fresh starter deck, and the run
## never sees its result. Nothing done in practice costs standing or a shift.
##
## Pure like the rest of scripts/run - no Node, nothing loaded from disk. The
## run hands in the pools it already has.

const SEED := 20260924
## Plenty. The whole lesson takes four or five ticks, and running out of clock
## halfway through a tutorial would teach the wrong thing entirely.
const TICKS := 30
const ARCHETYPE := &"easygoing"
const CUSTOMER_NAME := "Dana Whitaker"
const PATIENCE := 20
## Left to right: something to dig, two products, and two of the support card
## the coach asks for, so digging either one of those still leaves the other.
const HAND := [&"smalltalk", &"vsc", &"explain", &"gap", &"explain"]
## Once a product is on the table, their Line sits this far above its Appeal.
## Short enough that the one support card the coach asks for next is exactly
## what tips it over - whichever product they happened to put down.
const LINE_GAP := 3
## Where the two scripted products sit on their list. Left to the shuffle, a
## product they rank last opens at 0 Appeal: the first meter anyone ever sees
## is an empty bar with the Line's mark crammed against its start, which
## teaches nothing about filling a bar up to a mark.
const RANKS := {&"vsc": 3, &"gap": 4}

static func build_shift(cfg: ShiftConfig, interests: InterestPool, cards: CardPool,
		archetypes: ArchetypePool, dialogue: DialoguePool = null) -> Shift:
	var practice := cfg.duplicate() as ShiftConfig
	practice.shift_ticks = TICKS
	# No quota to make in practice - "banked $0 / $3,600" on the top bar would
	# be a target nobody is asking you to hit.
	practice.quota = 0
	var s := Shift.new(practice, interests, cards, archetypes, SEED, [ARCHETYPE],
		Deck.build_starting(cards), 0, 1, 0, 0, dialogue, 1)
	var c: Customer = s.chairs[0]
	c.display_name = CUSTOMER_NAME
	c.max_patience = PATIENCE
	c.patience = PATIENCE
	# Normally the one thing you have to earn a look at. Shown here so the
	# meter has a mark to aim for the first time you see it.
	c.known_line = true
	for product in RANKS:
		_rank(c, cards, product, RANKS[product])
	_deal(s, HAND)
	return s

## Moves a product's interest to `rank` on their list by swapping with whatever
## was there, so the list stays a list - every rank still used exactly once.
static func _rank(c: Customer, cards: CardPool, product: StringName, rank: int) -> void:
	var def := cards.by_id(product) as ProductCardDef
	if def == null:
		return
	var iid: StringName = def.interest.id
	for other in c.ranks:
		if int(c.ranks[other]) == rank:
			c.ranks[other] = c.ranks[iid]
			break
	c.ranks[iid] = rank

## Swaps the shuffled opening hand for HAND, in order, taking each card from
## the pile the shift already dealt from - so every card is still one real
## instance of the starter deck, and nothing is conjured or duplicated.
static func _deal(s: Shift, ids: Array) -> void:
	s.draw.append_array(s.hand)
	s.hand.clear()
	for id in ids:
		for i in range(s.draw.size()):
			if s.draw[i].card.id == id:
				s.hand.append(s.draw.pop_at(i))
				break

## Called once the first product lands on the table: moves their Line to just
## above it, so the support card the coach asks for next is what clears it.
## Returns whether it changed anything - there is nothing to tune with an empty
## table.
static func tune_line(c: Customer) -> bool:
	if c == null or c.offer == null:
		return false
	c.line = c.offer.appeal + LINE_GAP
	return true
