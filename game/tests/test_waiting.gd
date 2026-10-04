extends RefCounted
## An empty floor used to be the end of the shift, whatever the clock said.
##
## Every command that moves the clock needs a customer - approach, place,
## support, offer, close - except dig, and dig is only reachable through the
## hand, which the view stows off screen while you are out on the floor. So the
## last customer walking out with chairs still empty left nothing to press and
## nothing to wait for: the tick counter stopped and the shift never ended.
##
## wait() is the way out. It exists ONLY for that state, which is why it refuses
## while anyone is still sitting down: a shift where you can skip time at will is
## a different game, and the Karen draining the floor is supposed to cost you.
var h: Harness

func _cfg() -> ShiftConfig:
	return load("res://data/shift_config.tres")

func _shift(seed_value: int = 7) -> Shift:
	return Shift.new(_cfg(), load("res://data/interests/interest_pool.tres"),
		load("res://data/card_pool.tres"), load("res://data/archetype_pool.tres"),
		seed_value, [])

## Empty every chair the way the game does - by running them out of patience -
## so the door's clock is in the state a real deadlock would leave it.
func _empty_the_floor(s: Shift) -> void:
	for i in range(s.chairs.size()):
		if s.chairs[i] != null:
			s.chairs[i].patience = 0
	s._settle_patience()

func test_the_floor_can_actually_end_up_empty() -> void:
	## If this ever stops being possible the rest of the file is theatre.
	var s := _shift()
	h.check("a shift starts with people in it", not s.seated().is_empty())
	_empty_the_floor(s)
	h.check("and they can all be gone at once", s.seated().is_empty())
	h.check("with the clock still running", not s.is_over())
	s = null

func test_waiting_moves_the_clock_when_nothing_else_can() -> void:
	var s := _shift()
	_empty_the_floor(s)
	var before: int = s.tick
	var res := s.wait()
	h.check("waiting is allowed on an empty floor (%s)" % res.msg, res.ok)
	h.check("and time actually passed (%d -> %d)" % [before, s.tick], s.tick > before)
	h.eq("it says how long it took", res.data.get("ticks", 0), s.tick - before)
	s = null

func test_waiting_is_refused_while_anyone_is_still_sitting_there() -> void:
	## Not a general skip-time button. Time pressure IS the game.
	var s := _shift()
	var res := s.wait()
	h.check("refused while the floor has people on it", not res.ok)
	h.check("and says why (%s)" % res.msg, res.msg.length() > 0)
	h.eq("costing nothing", s.tick, 0)
	s = null

func test_waiting_is_refused_once_the_floor_is_closed() -> void:
	var s := _shift()
	s.tick = s.tick_budget
	_empty_the_floor(s)
	var res := s.wait()
	h.check("the floor is closed, so there is nothing to wait for", not res.ok)
	s = null

func test_a_wait_never_returns_without_moving_the_clock() -> void:
	## The floor of one tick inside _ticks_until_the_door_opens cannot be reached
	## by playing: _burn lets in anybody whose time has come, so the door always
	## has time left on its clock. Which means the test above walks right past
	## the clamp without touching it - it was passing with the clamp removed.
	##
	## The clamp still has to hold, because the VIEW waits in a loop: a wait that
	## returns ok having moved nothing is not a wrong number on screen, it is the
	## game hanging inside a UI callback. So force the state instead of hoping to
	## meet it.
	var s := _shift()
	_empty_the_floor(s)
	s.next_arrival = 0
	var before: int = s.tick
	var res := s.wait()
	h.check("with the door's clock already at zero, waiting still moves the "
		+ "clock (%d -> %d)" % [before, s.tick], s.tick > before)
	h.check("and says so honestly (%s)" % res.data,
		int(res.data.get("ticks", 0)) == s.tick - before)
	s = null
