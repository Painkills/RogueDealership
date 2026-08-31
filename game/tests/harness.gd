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
