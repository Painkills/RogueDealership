extends RefCounted
## What a boss fight says on the folders either side of the boss - BossPanels -
## from made-up bosses and moves, so it is the words that are checked and not
## the Whale's tuning.
var h: Harness

func _cfg() -> ShiftConfig:
	var cfg: ShiftConfig = (load("res://data/shift_config.tres") as ShiftConfig).duplicate()
	cfg.patience_jitter = 0
	cfg.arrival_patience_min_fraction = 1.0
	return cfg

func _move(id: StringName, hit: int, fuse: int, resolve: DemandResolve = null,
		pierce: bool = false, line: int = 0) -> Demand:
	var d := Demand.new()
	d.id = id
	d.display_name = String(id).capitalize()
	d.telegraph = String(id).to_upper()
	d.ticks = fuse
	d.resolve = resolve
	if hit > 0:
		var e := Hit.new()
		e.amount = hit
		e.through_patience = pierce
		d.effects.append(e)
	if line != 0:
		var l := ChangeLine.new()
		l.amount = line
		d.effects.append(l)
	return d

func _boss_with(moves: Array, budget_moves: Array = []) -> Customer:
	var a := CustomerArchetype.new()
	a.id = &"made_up_boss"
	a.display_name = "Made-up Boss"
	a.patience = 20
	a.patience_is_shield = true
	a.budget_share = 1.0
	a.moves.assign(moves)
	a.budget_moves.assign(budget_moves)
	var interests: InterestPool = load("res://data/interests/interest_pool.tres")
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var c := Customer.new("A", "Test Boss", a, Customer.make_ranks(interests, rng), 20, 20,
		{"appeal_step": 4, "line_per_sale": 3, "leaving_soon_at": 4}, interests)
	c.budget = 7000
	return c

func _all_text(note: Dictionary) -> String:
	var parts: Array[String] = []
	for k in ["tab", "title", "bar_text", "headline", "body"]:
		parts.append(str(note.get(k, "")))
	return " | ".join(parts)

# ------------------------------------------------------------------- the seats
func test_the_budget_is_on_the_left_and_the_move_on_the_right_of_whoever_is_in_front() -> void:
	var c := _boss_with([_move(&"m", 6, 3)])
	for front in range(3):
		var notes := BossPanels.side_notes(c, front, 0)
		h.eq("front %d: two notes" % front, notes.size(), 2)
		h.eq("front %d: the budget on the left" % front,
			notes[(front + 2) % 3]["tab"], "BUDGET")
		h.eq("front %d: the move on the right" % front,
			notes[(front + 1) % 3]["tab"], "NEXT MOVE")
		h.check("front %d: nothing on the front seat itself" % front, not notes.has(front))
	h.check("and nothing at all without a boss", BossPanels.side_notes(null, 0, 0).is_empty())

# ---------------------------------------------------------------- the budget
func test_the_budget_folder_says_what_is_left_and_what_is_coming() -> void:
	var truck := _move(&"truck", 20, 2, ClearTheTable.new(), true)
	var bm := BudgetMove.new()
	bm.at_share = 0.75
	bm.move = truck
	var c := _boss_with([], [bm])
	var note := BossPanels.budget_note(c)
	h.eq("the title is what is left", note["title"], "$7,000 left")
	h.eq("the bar is full", [note["bar_value"], note["bar_max"]], [7000, 7000])
	h.check("it says they will not sign yet (%s)" % note["body"],
		note["body"].contains("will not sign until it is all spent"))
	h.check("and when the big move comes, and what it hits for (%s)" % note["body"],
		note["body"].contains("TRUCK") and note["body"].contains("$5,250")
			and note["body"].contains("hits for 20"))
	c.unsigned.append({"product": null, "margin": 7000})
	var done := BossPanels.budget_note(c)
	h.check("spent out, it says to sign them (%s)" % done["body"],
		done["body"].begins_with("All spent. Sign them."))
	h.eq("and the bar is empty", done["bar_value"], 0)

# ---------------------------------------------------------------- the move
func test_the_move_folder_says_what_it_is_how_long_you_have_and_what_to_do() -> void:
	var impatient := _move(&"impatient", 6, 3, IncreasePatience.new())
	var c := _boss_with([impatient])
	c.demand = impatient
	c.demand_due_tick = 3
	var note := BossPanels.move_note(c, 1)
	h.eq("it is what is incoming", note["tab"], "INCOMING")
	h.eq("named", note["title"], impatient.display_name)
	h.eq("with the ticks left on its bar", [note["bar_value"], note["bar_max"]], [2, 3])
	h.eq("and in words", note["bar_text"], "2 ticks to answer")
	h.eq("what it hits for", note["headline"], "HITS FOR 6")
	h.check("how to stop it (%s)" % note["body"],
		note["body"].contains(IncreasePatience.new().how_to_answer()))
	h.check("and where the hit lands if you do not: their patience first",
		note["body"].contains("comes off their patience first (20)"))

func test_a_hit_that_goes_through_patience_says_so_instead() -> void:
	var truck := _move(&"truck", 20, 2, ClearTheTable.new(), true)
	var c := _boss_with([truck])
	c.demand = truck
	c.demand_due_tick = 2
	var note := BossPanels.move_note(c, 1)
	h.check("it cannot be soaked up (%s)" % note["body"],
		note["body"].contains("cannot soften it") and not note["body"].contains("comes off their patience"))
	h.eq("and a tick left is a tick", note["bar_text"], "1 tick to answer")

func test_harder_rounds_show_their_harder_numbers() -> void:
	var m := _move(&"m", 6, 4, IncreasePatience.new())
	var c := _boss_with([m])
	c.archetype.escalate_damage = 2
	c.archetype.escalate_fuse = 1
	c.move_round = 2
	c.demand = m
	c.demand_due_tick = c.move_fuse(m)
	var note := BossPanels.move_note(c, 0)
	h.eq("the hit, two rounds on", note["headline"], "HITS FOR 10")
	h.eq("and the fuse two ticks shorter", note["bar_max"], 2)

func test_a_move_without_a_hit_says_what_it_does_and_that_nothing_stops_it() -> void:
	var stakes := _move(&"stakes", 0, 3, null, false, 3)
	var c := _boss_with([stakes])
	c.demand = stakes
	c.demand_due_tick = 3
	var note := BossPanels.move_note(c, 0)
	h.check("what it does (%s)" % note["headline"], note["headline"].contains("LINE"))
	h.check("and that you cannot stop it (%s)" % note["body"],
		note["body"].contains("Nothing stops this one"))

func test_with_nothing_live_it_says_when_the_next_comes_and_warns_of_a_waiting_one() -> void:
	var m := _move(&"m", 6, 3)
	var c := _boss_with([m])
	c.next_move_tick = 5
	var quiet := BossPanels.move_note(c, 3)
	h.eq("quiet", quiet["tab"], "NEXT MOVE")
	h.eq("and when", quiet["bar_text"], "next move in 2 ticks")
	var truck := _move(&"truck", 20, 2, ClearTheTable.new(), true)
	truck.needs_offer_on_table = true
	var bm := BudgetMove.new()
	bm.at_share = 1.0
	bm.move = truck
	var waiting := _boss_with([], [bm])
	var note := BossPanels.move_note(waiting, 0)
	h.eq("a due budget move is named before it comes", note["title"], truck.display_name)
	h.check("with what it hits for (%s)" % note["headline"], note["headline"] == "HITS FOR 20")
	h.check("and that it waits for a product on the table (%s)" % note["body"],
		note["body"].contains("the moment a product is on the table"))

# ----------------------------------------------------------- never a "shield"
func test_nothing_the_player_reads_calls_patience_a_shield() -> void:
	var truck := _move(&"truck", 20, 2, ClearTheTable.new(), true)
	var hit := _move(&"hit", 6, 3, IncreasePatience.new())
	var bm := BudgetMove.new()
	bm.at_share = 0.75
	bm.move = truck
	var c := _boss_with([hit], [bm])
	var seen: Array[String] = [BossPanels.fight_text(c), CustomerCard3D.behaviour_text(c),
		_all_text(BossPanels.budget_note(c)), _all_text(BossPanels.move_note(c, 0))]
	c.demand = hit
	c.demand_due_tick = 3
	seen.append(_all_text(BossPanels.move_note(c, 0)))
	c.demand = truck
	seen.append(_all_text(BossPanels.move_note(c, 0)))
	for text in seen:
		h.check("no shield in: %s" % text.left(50), not text.to_lower().contains("shield"))
	var card := (load("res://scenes/cards/customer_card_3d.tscn") as PackedScene).instantiate() as CustomerCard3D
	card._bind()
	card.setup(c, true, 0)
	h.check("the folder reads patience, not shield (%s)" % card._patience.text,
		card._patience.text.begins_with("patience"))
	card.free()

# -------------------------------------------------------------- the back note
func test_the_back_of_a_bosss_folder_is_short_and_points_at_the_side_folders() -> void:
	var c := _boss_with([_move(&"m", 6, 3)])
	var text := CustomerCard3D.behaviour_text(c)
	h.eq("it is the fight's note", text, BossPanels.fight_text(c))
	h.check("three short lines at most (%d)" % text.split("\n").size(), text.split("\n").size() <= 3)
	h.check("it points at the left and right folders", text.contains("Left folder")
		and text.contains("Right folder"))
	var plain := CustomerArchetype.new()
	h.check("an ordinary customer is not one", not plain.is_boss())

# ------------------------------------------------------------ on the card
func test_a_folder_shows_a_note_and_goes_back_to_a_customer() -> void:
	var scene := load("res://scenes/cards/customer_card_3d.tscn") as PackedScene
	var card := scene.instantiate() as CustomerCard3D
	card._bind()
	var note := {"tab": "BUDGET", "title": "$1,000 left", "bar_value": 400, "bar_max": 1000,
		"bar_color": Color.GREEN, "bar_text": "of $1,000", "headline": "HITS FOR 9",
		"body": "Words to read."}
	card.setup_note(note)
	h.eq("the tab", card._archetype.text, "BUDGET")
	h.eq("the title where their name goes", card._name.text, "$1,000 left")
	h.eq("the words under the bar", card._patience.text, "of $1,000")
	h.eq("the bar", [card._patience_bar.value, card._patience_bar.max_value], [400.0, 1000.0])
	h.eq("the red line", card._demand.text, "HITS FOR 9")
	h.eq("the body", card._note.text, "Words to read.")
	h.check("the note shows, and no interest grid or photo",
		card._note.visible and not card._grid.visible and not card._photo.visible)
	var c := _boss_with([])
	card.setup(c, false, 0)
	h.check("a customer sitting down brings the ordinary face back",
		not card._note.visible and card._grid.visible and card._photo.visible)
	card.setup_note(note)
	card.setup(null, false, 0)
	h.check("and an empty chair hides the note", not card._note.visible)
	card.free()
