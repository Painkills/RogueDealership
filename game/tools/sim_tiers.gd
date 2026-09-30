extends SceneTree
## Balance probe: plays the standard shifts - morning, midday, night - many
## times each with one fixed, reasonably sharp policy, and prints how they
## come out, day by day of the week.
##
##     godot --headless --path game --script res://tools/sim_tiers.gd
##
## What-ifs, without touching the data: tier.field=value after a `--`, on a
## copy of the profile - e.g.
##
##     ... --script res://tools/sim_tiers.gd -- midday.patience_scale=0.85
##
## Every shift starts from the STARTER deck with full standing, so the tier and
## the day are the only differences between them - the numbers compare tiers,
## they do not predict a real run (where the deck grows in the store).
##
## The player here knows every customer's true priorities and Line - a sharp
## human reads most of that from bands and Read the Room, at a cost this
## skips - so absolute results run optimistic. It answers demands it can,
## signs anyone about to walk, and leaves Family First alone when asked.

const SEEDS := 300
const TIERS: Array[StringName] = [&"morning", &"midday", &"night"]

var _cfg: ShiftConfig
var _pool: ShiftProfilePool

func _init() -> void:
	_cfg = load("res://data/shift_config.tres")
	_pool = load("res://data/shift_profile_pool.tres")
	var days: int = _cfg.shifts_in_run
	var profiles := {}
	for tier in TIERS:
		profiles[tier] = _pool.by_id(tier).duplicate()
	for arg in OS.get_cmdline_user_args():
		var parts: PackedStringArray = arg.split("=")
		var path: PackedStringArray = parts[0].split(".")
		if parts.size() != 2 or path.size() != 2 or not profiles.has(StringName(path[0])):
			print("ignoring %s - expected tier.field=value" % arg)
			continue
		var p: ShiftProfile = profiles[StringName(path[0])]
		p.set(path[1], str_to_var(parts[1]))
		print("what-if: %s.%s = %s" % [path[0], path[1], p.get(path[1])])
	var rows := []
	for tier in TIERS:
		var profile: ShiftProfile = profiles[tier]
		for day in range(1, days + 1):
			if day >= profile.from_day:     # only the days the calendar offers it
				rows.append(_cell(profile, day))
	_print(rows)
	quit(0)

## SEEDS shifts of one tier on one day of the week, summed up.
func _cell(profile: ShiftProfile, day: int) -> Dictionary:
	var sum := {"margin": 0.0, "made": 0.0, "walked": 0.0, "signed": 0.0, "seen": 0.0,
		"standing": 0.0, "bonus": 0.0, "missed": 0.0, "met": 0.0, "lost_bell": 0.0,
		"quota": 0.0}
	for seed_value in range(SEEDS):
		var run := RunState.new(_cfg, load("res://data/interests/interest_pool.tres"),
			load("res://data/card_pool.tres"), load("res://data/archetype_pool.tres"),
			seed_value * 7919 + day)
		run.shift_number = day
		var s := run.start_shift(profile)
		_play(s)
		var r := s.report()
		sum["margin"] += r["margin_banked"]
		sum["quota"] += r["quota"]
		sum["made"] += 1.0 if r["made_quota"] else 0.0
		sum["walked"] += r["customers_walked"]
		sum["signed"] += r["customers_signed"]
		sum["seen"] += r["customers_seen"]
		sum["standing"] += r["standing_delta"]
		sum["bonus"] += RunState.bonus_from(r)
		sum["missed"] += r["demands_missed"]
		sum["met"] += r["demands_met"]
		sum["lost_bell"] += r["margin_lost_to_closing"]
	for k in sum:
		sum[k] /= SEEDS
	sum["tier"] = profile.id
	sum["day"] = day
	return sum

# --- the player --------------------------------------------------------------

func _play(s: Shift) -> void:
	var guard := 0
	while not s.is_over() and guard < 600:
		guard += 1
		if s.pending_pull != null:
			s.choose_pull(0)
			continue
		if s.seated().is_empty():
			if not s.wait().ok:
				break
			continue
		var target := _pick_target(s)
		if target < 0:
			# Only someone asking to be left alone: step away and cycle a card.
			if s.at != null:
				s.leave()
			if not _dig(s):
				break
			continue
		if s.at == null or int(s.at) != target:
			s.approach(target)
		if not _act(s, s.chairs[target]):
			if not _dig(s):
				break

## Who to work next: whoever has a demand you can answer, soonest due; then
## anyone with a deal unsigned and about to walk; then who you are with, if
## there is still a sale in hand for them; then the best sale on the floor.
func _pick_target(s: Shift) -> int:
	var best := -1
	var best_score := -INF
	for i in range(s.chairs.size()):
		var c: Customer = s.chairs[i]
		if c == null:
			continue
		if c.demand != null and c.demand.resolve is LeaveThemAlone:
			continue
		var score := 0.0
		if c.demand != null and _can_answer(s, c):
			score = 1000.0 - float(c.demand_due_tick - s.tick)
		elif not c.unsigned.is_empty() and c.patience <= 3:
			score = 900.0 - float(c.patience)
		else:
			var p := _best_product(s, c)
			if p >= 0:
				score = float(_margin_of(s, p)) / 100.0 + (5.0 if s.at != null and int(s.at) == i else 0.0)
			elif not c.unsigned.is_empty():
				score = 1.0
			else:
				score = -10.0 + float(c.patience) * -0.1
		if score > best_score:
			best_score = score
			best = i
	return best

func _can_answer(s: Shift, c: Customer) -> bool:
	var r := c.demand.resolve
	if r is IncreasePatience:
		return _find(s, "patience") >= 0
	if r is MakeAnOffer:
		return c.offer != null or _best_product(s, c, true) >= 0
	if r is OfferSomethingGood:
		return (c.offer != null and int(c.ranks[c.offer.product.interest.id]) <= 3) \
			or _top3_product(s, c) >= 0
	if r is PlayConcession:
		return c.offer != null and _find(s, "concession") >= 0
	if r is PlayAnySupport:
		return _any_support(s, c) >= 0
	return false

## One move with customer `c`. False when there was nothing worth doing.
func _act(s: Shift, c: Customer) -> bool:
	if c.demand != null and _can_answer(s, c):
		var r := c.demand.resolve
		if r is IncreasePatience:
			return s.play_card(_find(s, "patience")).ok
		if r is MakeAnOffer:
			if c.offer == null:
				return s.place(_best_product(s, c, true)).ok
			return s.offer().ok
		if r is OfferSomethingGood:
			if c.offer != null and int(c.ranks[c.offer.product.interest.id]) <= 3:
				return s.offer().ok
			if c.offer != null:
				s.drop_offer()
			return s.place(_top3_product(s, c)).ok
		if r is PlayConcession:
			return s.play_card(_find(s, "concession")).ok
		if r is PlayAnySupport:
			return s.play_card(_any_support(s, c)).ok
	if not c.unsigned.is_empty() and _should_close(s, c):
		if s.close().ok:
			return true
	if c.offer != null:
		var gap: int = c.line - c.offer.appeal
		if gap <= 0:
			return s.offer().ok
		var card := _appeal_card_for(s, gap)
		if card >= 0:
			return s.play_card(card).ok
		s.drop_offer()
	var p := _best_product(s, c)
	if p >= 0:
		return s.place(p).ok
	if c.patience <= 4:
		var calm := _find(s, "patience")
		if calm >= 0:
			return s.play_card(calm).ok
	if not c.unsigned.is_empty():
		return s.close().ok
	return false

func _should_close(s: Shift, c: Customer) -> bool:
	return c.patience <= 3 or (s.tick_budget - s.tick) <= 2 \
		or (c.offer == null and _best_product(s, c) < 0)

## The product in hand that sells best to `c`: outright sales first, by margin;
## then the smallest gap the appeal cards in hand can close. -1 if none can.
## `any_offer`: any product at all will do (a Kicker only wants to be asked).
func _best_product(s: Shift, c: Customer, any_offer: bool = false) -> int:
	var boost := _appeal_in_hand(s)
	var best := -1
	var best_key := -INF
	for i in range(s.hand.size()):
		var inst: CardInstance = s.hand[i]
		if not inst.is_product() or c.owns(inst.card.id):
			continue
		var appeal: int = c.appeal_for((inst.card as ProductCardDef).interest.id)
		var gap: int = c.line - appeal
		if gap > boost and not any_offer:
			continue
		var key: float = (100000.0 if gap <= 0 else -1000.0 * gap) + inst.margin()
		if key > best_key:
			best_key = key
			best = i
	return best

func _top3_product(s: Shift, c: Customer) -> int:
	var best := -1
	var best_rank := 99
	for i in range(s.hand.size()):
		var inst: CardInstance = s.hand[i]
		if not inst.is_product() or c.owns(inst.card.id):
			continue
		var rank: int = int(c.ranks[(inst.card as ProductCardDef).interest.id])
		if rank <= 3 and rank < best_rank:
			best_rank = rank
			best = i
	return best

func _margin_of(s: Shift, i: int) -> int:
	return (s.hand[i] as CardInstance).margin()

func _appeal_of(inst: CardInstance) -> int:
	if inst.is_product():
		return 0
	var def := inst.card as SupportCardDef
	var total := 0
	for e in def.effects:
		if e is ChangeAppeal:
			total += e.amount
	return total

func _appeal_in_hand(s: Shift) -> int:
	var total := 0
	for inst in s.hand:
		total += maxi(0, _appeal_of(inst))
	return total

## The smallest appeal card that closes `gap` on its own, or else the biggest.
func _appeal_card_for(s: Shift, gap: int) -> int:
	var covering := -1
	var biggest := -1
	for i in range(s.hand.size()):
		var a := _appeal_of(s.hand[i])
		if a <= 0:
			continue
		if a >= gap and (covering < 0 or a < _appeal_of(s.hand[covering])):
			covering = i
		if biggest < 0 or a > _appeal_of(s.hand[biggest]):
			biggest = i
	return covering if covering >= 0 else biggest

func _find(s: Shift, what: String) -> int:
	for i in range(s.hand.size()):
		var inst: CardInstance = s.hand[i]
		if inst.is_product():
			continue
		var def := inst.card as SupportCardDef
		for e in def.effects:
			if what == "patience" and (e is ChangePatience or e is ChangePatienceFloor) \
					and e.amount > 0:
				return i
			if what == "concession" and e is ChangeMargin and e.amount < 0:
				return i
	return -1

func _any_support(s: Shift, c: Customer) -> int:
	for i in range(s.hand.size()):
		var inst: CardInstance = s.hand[i]
		if not inst.is_product() and (c.offer != null or not (inst.card as SupportCardDef).needs_offer):
			return i
	return -1

## Cycle the least useful card: a product nobody on the floor wants much, or
## else the first support card.
func _dig(s: Shift) -> bool:
	if s.hand.is_empty():
		return false
	var worst := 0
	var worst_value := INF
	for i in range(s.hand.size()):
		var inst: CardInstance = s.hand[i]
		var value := 20.0
		if inst.is_product():
			value = 0.0
			for c in s.seated():
				value = maxf(value, float(c.appeal_for((inst.card as ProductCardDef).interest.id)))
		if value < worst_value:
			worst_value = value
			worst = i
	return s.dig(worst).ok

# --- the table ----------------------------------------------------------------

func _print(rows: Array) -> void:
	print("tier     day  quota   banked  made%  bonus   stand  seen  signed walked  dem_met dem_miss lost@bell")
	for r in rows:
		print("%-8s %3d  %5d  %6d  %4.0f%%  %5d  %+5.1f  %4.1f  %4.1f  %4.2f   %4.2f    %4.2f    %5d" % [
			r["tier"], r["day"], r["quota"], r["margin"], r["made"] * 100.0, r["bonus"],
			r["standing"], r["seen"], r["signed"], r["walked"], r["met"], r["missed"],
			r["lost_bell"]])
	print("")
	print("tier     banked  made%  bonus   stand  seen  signed walked  (averaged over the days it is offered)")
	for tier in TIERS:
		var n := 0
		var t := {"margin": 0.0, "made": 0.0, "bonus": 0.0, "standing": 0.0, "seen": 0.0,
			"signed": 0.0, "walked": 0.0}
		for r in rows:
			if r["tier"] != tier:
				continue
			n += 1
			for k in t:
				t[k] += r[k]
		for k in t:
			t[k] /= n
		print("%-8s %6d  %4.0f%%  %5d  %+5.1f  %4.1f  %4.1f  %4.2f" % [tier, t["margin"],
			t["made"] * 100.0, t["bonus"], t["standing"], t["seen"], t["signed"], t["walked"]])
