class_name BossPanels extends RefCounted
## What a boss fight puts on the table beyond the boss's own folder: their budget
## on the folder to the left, what they are about to do on the folder to the
## right (ShiftController._render() hangs them on the seats nobody sits in), and
## the short note on the back of the boss's own folder.
##
## Pure functions of a Customer and the tick, so the words can be checked without
## a floor. Each note is the Dictionary CustomerCard3D.setup_note() reads:
## `tab` (on the folder's tab), `title`, `bar_value` of `bar_max` in `bar_color`
## with `bar_text` under it, a red `headline`, and a `body`.

## The back of the boss's folder. Short on purpose: the fight explains itself,
## move by move, on the folders either side.
static func fight_text(_c = null) -> String:
	return "A FIGHT, NOT A SALE\nLeft folder: their budget. Spend it all and they sign.\nRight folder: their next move. Answer it in time, or it hits your standing."

## The notes for a floor with `front` at the front: seat -> note, for each of the
## two seats either side of it that nobody sits in. Empty when nobody on the
## floor is a boss.
static func side_notes(boss, front: int, tick: int) -> Dictionary:
	if boss == null:
		return {}
	# Seat (i+1)%3 is on the right of the front seat, (i+2)%3 on the left - see
	# ShiftController.station_for().
	return {
		(front + 2) % 3: budget_note(boss),
		(front + 1) % 3: move_note(boss, tick),
	}

## The left folder: how much they have left to spend, and the big move to come.
static func budget_note(c) -> Dictionary:
	var lines: Array[String] = []
	lines.append("All spent. Sign them." if c.spent_out()
		else "They will not sign until it is all spent.")
	var next: BudgetMove = c.next_budget_move()
	if next != null:
		var hit: int = c.move_damage(next.move)
		lines.append("%s comes when %s is left%s." % [next.move.display_name.to_upper(),
			Format.money(next.dollars_left(c.budget)),
			", and hits for %d" % hit if hit > 0 else ""])
	return {
		"tab": "BUDGET",
		"title": "%s left" % Format.money(c.budget_left()),
		"bar_value": c.budget_left(),
		"bar_max": maxi(1, c.budget),
		"bar_color": Palette.color(&"money"),
		"bar_text": "of %s" % Format.money(c.budget),
		"headline": "",
		"body": "\n".join(lines),
	}

## The right folder: the move they have telegraphed, how long you have, and what
## to do about it - or what is coming when nothing is live.
static func move_note(c, tick: int) -> Dictionary:
	var d: Demand = c.demand
	if d != null and c.is_a_move(d):
		return _live_move(c, d, tick)
	var due: BudgetMove = c.due_budget_move()
	if due != null:
		var hit: int = c.move_damage(due.move)
		return {
			"tab": "NEXT MOVE",
			"title": due.move.display_name,
			"bar_value": 0,
			"bar_max": 1,
			"bar_color": Palette.color(&"alert"),
			"bar_text": "waiting for a product on the table",
			"headline": "HITS FOR %d" % hit if hit > 0 else "",
			"body": "It comes the moment a product is on the table. %s" % \
				(due.move.resolve.how_to_answer() if due.move.resolve != null else ""),
		}
	var wait: int = maxi(0, c.next_move_tick - tick)
	return {
		"tab": "NEXT MOVE",
		"title": "Quiet" if not c.spent_out() else "All spent",
		"bar_value": 0,
		"bar_max": 1,
		"bar_color": Palette.color(&"neutral_1"),
		"bar_text": "next move in %d tick%s" % [wait, "" if wait == 1 else "s"]
			if not c.spent_out() else "nothing left to buy",
		"headline": "",
		"body": "Every move is telegraphed here before it lands." if not c.spent_out()
			else "Sign them to win.",
	}

static func _live_move(c, d: Demand, tick: int) -> Dictionary:
	var left: int = maxi(0, c.demand_due_tick - tick)
	var hits: int = c.move_damage(d)
	var lines: Array[String] = []
	if d.resolve != null:
		lines.append(d.resolve.how_to_answer())
	else:
		lines.append("Nothing stops this one." if hits > 0
			else "Nothing stops this one - sell before it lands.")
	if hits > 0:
		if d.pierces_patience():
			lines.append("Their patience cannot soften it.")
		else:
			lines.append("If not, it comes off their patience first (%d), then your standing."
				% c.patience)
	var headline := "HITS FOR %d" % hits if hits > 0 else ""
	if hits <= 0:
		var does := PackedStringArray()
		for e in d.effects:
			does.append(e.describe().to_upper())
		headline = ", ".join(does)
	return {
		"tab": "INCOMING",
		"title": d.display_name,
		"bar_value": left,
		"bar_max": maxi(1, c.move_fuse(d)),
		"bar_color": Palette.color(&"alert"),
		"bar_text": "%d tick%s to answer" % [left, "" if left == 1 else "s"],
		"headline": headline,
		"body": "\n".join(lines),
	}
