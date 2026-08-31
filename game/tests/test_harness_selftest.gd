extends RefCounted
var h: Harness

func test_harness_counts_a_pass_and_a_failure() -> void:
	var probe := Harness.new()
	probe.check("this passes", true)
	probe.eq("this also passes", 2 + 2, 4)
	var r: Dictionary = probe.results()
	h.eq("harness counted two passes", r.passed, 2)
	h.eq("and no failures", r.failed, 0)

func test_harness_records_a_failing_label() -> void:
	var probe := Harness.new()
	probe.eq("deliberate miss", 1, 2)
	var r: Dictionary = probe.results()
	h.eq("harness counted one failure", r.failed, 1)
	h.check("and kept the label", str(r.failures[0]).contains("deliberate miss"))
