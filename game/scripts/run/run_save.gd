class_name RunSave extends RefCounted
## A run in progress, as plain data: where the day began, and every move made
## since - enough to put the run back exactly where it was.
##
## The day begins on its calendar, with a snapshot of the run (RunState.snapshot()).
## After it comes the shift picked off that calendar, every command played on it
## (Shift.commands), and - once its report is read - every move in the store
## after it (Shop.commands). The store closing is the next day's beginning.
##
## Every die in a run is rolled from its seed, so playing those moves again from
## the snapshot lands where they did - on the same build. A newer build can play
## them out differently, and the fingerprint says so: resume() then reports it,
## and the day starts over from its calendar.
##
## Pure like the rest of scripts/run: writing it to disk is RunFile's job.

## Bumped whenever what is saved changes shape - an older save is not read.
const VERSION := 1

## Which build wrote it - for a person reading the file, never checked.
var build: String = ""
var checkpoint: Dictionary = {}
## Which of each worked day's shifts was picked, from day 1 - its place among
## that day's offers - for the calendar's history.
var picks: Array = []
## Which of today's shifts was picked, or -1 while today's calendar is still up.
var pick: int = -1
## A shift picked that is not one of today's offers - only ever a driver's or a
## test's - by where it is filed, in place of `pick`.
var pick_path: String = ""
var shift_commands: Array = []
## True once the shift's report is read and the store after it is open.
var shop_open: bool = false
var shop_commands: Array = []
## fingerprint_of() everything, as it was when this was written.
var fingerprint: int = 0

## A day beginning on its calendar: `run` as it stands, and the shifts picked on
## the days before.
static func start_of_day(run: RunState, history: Array) -> RunSave:
	var s := RunSave.new()
	s.checkpoint = run.snapshot()
	for entry in history:
		s.picks.append(_place_of(run, s.picks.size() + 1, entry["profile"]))
	s.fingerprint = fingerprint_of(run, null, null)
	return s

## Where `profile` sits among `day`'s offers, or -1.
static func _place_of(run: RunState, day: int, profile: ShiftProfile) -> int:
	return run.week.offers(day).find(profile) if run.week != null else -1

## Today's pick, from today's offers.
func picked(run: RunState, profile: ShiftProfile) -> void:
	pick = run.todays_shifts().find(profile)
	pick_path = profile.resource_path if pick < 0 else ""

## Whether today's shift has been picked - and can be found again.
func has_pick() -> bool:
	return pick >= 0 or pick_path != ""

func to_dict() -> Dictionary:
	return {"version": VERSION, "build": build, "checkpoint": checkpoint,
		"picks": picks, "pick": pick, "pick_path": pick_path,
		"shift_commands": shift_commands,
		"shop_open": shop_open, "shop_commands": shop_commands,
		"fingerprint": fingerprint}

## null for anything that is not a save this version wrote.
static func from_dict(d) -> RunSave:
	if not (d is Dictionary) or int(d.get("version", 0)) != VERSION:
		return null
	var s := RunSave.new()
	s.build = str(d.get("build", ""))
	s.checkpoint = d.get("checkpoint", {})
	s.picks = d.get("picks", [])
	s.pick = int(d.get("pick", -1))
	s.pick_path = str(d.get("pick_path", ""))
	s.shift_commands = d.get("shift_commands", [])
	s.shop_open = bool(d.get("shop_open", false))
	s.shop_commands = d.get("shop_commands", [])
	s.fingerprint = int(d.get("fingerprint", 0))
	if s.checkpoint.is_empty():
		return null
	return s

## The seed the run was dealt from - deal a RunState from it, then resume().
func seed_value() -> int:
	return int(checkpoint.get("seed", 0))

## The day being worked, from 1.
func day() -> int:
	return int(checkpoint.get("shift_number", 1))

## The day in progress, as far as `checkpoint` alone goes: back on its calendar.
func restart_day() -> void:
	pick = -1
	pick_path = ""
	shift_commands = []
	shop_open = false
	shop_commands = []

## Plays it all back onto `run` - freshly dealt from seed_value() - and says
## where that left things: {"ok", "history", "profile", "shift", "shop"}. The
## history is the calendar's, one {"profile", "report"} per day worked; profile
## and shift are today's once one is picked, and shop the store once it is open.
## "ok" is false when the moves played out differently this time (a newer
## build) - `check` false trusts them regardless.
func resume(run: RunState, check: bool = true) -> Dictionary:
	run.restore(checkpoint)
	var history: Array = []
	for i in range(mini(picks.size(), run.reports.size())):
		history.append({"profile": _offer(run, i + 1, int(picks[i])),
			"report": run.reports[i]})
	var out := {"ok": true, "history": history, "profile": null, "shift": null,
		"shop": null}
	var shift: Shift = null
	var shop: Shop = null
	if has_pick():
		var offers := run.todays_shifts()
		var profile: ShiftProfile = null
		if pick >= 0 and pick < offers.size():
			profile = offers[pick]
		elif pick < 0 and ResourceLoader.exists(pick_path):
			profile = load(pick_path) as ShiftProfile
		if profile == null:
			out["ok"] = false
			return out
		shift = run.start_shift(profile)
		for cmd in shift_commands:
			shift.replay(cmd)
		out["profile"] = profile
		out["shift"] = shift
		if shop_open:
			var report := shift.report()
			history.append({"profile": profile, "report": report})
			run.finish_shift(report)
			shop = Shop.new(run, profile)
			for cmd in shop_commands:
				shop.replay(cmd)
			out["shop"] = shop
	if check:
		out["ok"] = fingerprint_of(run, shift, shop) == fingerprint
	return out

## A worked day's shift: the one picked, where it can still be found - the day's
## first otherwise, so the calendar always has one to show.
static func _offer(run: RunState, day: int, at: int) -> ShiftProfile:
	var offers: Array[ShiftProfile] = run.week.offers(day) if run.week != null else []
	if at >= 0 and at < offers.size():
		return offers[at]
	return offers[0] if not offers.is_empty() else ShiftProfile.new()

## One number for where a run, the shift being worked and the store open after
## it stand - every die and everything the moves touched. Two runs that played
## out the same agree on it; one that went another way almost never does.
static func fingerprint_of(run: RunState, shift: Shift, shop: Shop) -> int:
	var parts: Array = [run.rng.state, run.shift_number, run.money, run.standing,
		run.banked_total, run.sale_streak, run.deck.snapshot(), run.dealership.map(
			func(u): return u.id)]
	if shift != null:
		var seats: Array = []
		for c in shift.chairs:
			seats.append(null if c == null else [c.archetype.id, c.display_name,
				c.patience, c.line])
		parts.append([shift.rng.state, shift.voice_rng.state, shift.tick,
			shift.margin_banked, shift.standing, shift.at, seats,
			shift.hand.map(func(i): return i.uid), shift.commands.size(),
			shift.action_log.size()])
	if shop != null:
		parts.append([shop.free_picks_left, shop.offers.map(func(d): return d.id),
			shop.dealership_picks_left, shop.commands.size()])
	return hash(parts)
