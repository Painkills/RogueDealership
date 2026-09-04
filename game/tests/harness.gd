class_name Harness extends RefCounted
## Zero-dependency assert collector, in the style m0/m1/m2 have used for three
## milestones. Output is exactly "N checks, N passed, N failed".

var _passed: int = 0
var _failures: Array[String] = []

func check(label: String, cond: bool) -> void:
	if cond:
		_passed += 1
	else:
		_failures.append(label)

func eq(label: String, got, want) -> void:
	check("%s (got %s, want %s)" % [label, str(got), str(want)], got == want)

func results() -> Dictionary:
	return {"passed": _passed, "failed": _failures.size(), "failures": _failures}

## How many checks have been recorded at all. The runner watches this across each
## test function, because a function that runs ZERO checks has either been left
## empty or has aborted on a runtime error - and an abort otherwise counts as
## nothing at all, which reads as a pass.
func total() -> int:
	return _passed + _failures.size()
