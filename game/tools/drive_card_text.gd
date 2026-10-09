extends SceneTree
## Every card in the pool, plain and upgraded, drawn on the real card face - and
## whether its words fit on it. The face is a fixed 500 x 700, and the wordiest
## card is what sets how big its type can be: a card added or reworded with more
## to say than the face can hold would otherwise just run off the bottom.
##
##   godot --headless --path game --script res://tools/drive_card_text.gd
##
## A live driver like the others, for the same reason: a label only knows how
## tall its wrapped text is once a real layout pass has given it its width.

const SCENE := "res://scenes/cards/card_face_3d.tscn"
const EXPECTED_MIN := 40

var _failures: Array[String] = []
var _checks := 0

func _init() -> void:
	_drive.call_deferred()

func _drive() -> void:
	var pool: CardPool = load("res://data/card_pool.tres")
	var scene := load(SCENE) as PackedScene
	var faces: Array = []
	var uid := 1
	for def in pool.cards:
		for upgraded in [false, true]:
			if upgraded and not _can_upgrade(def):
				continue
			var inst := CardInstance.new(def, uid)
			uid += 1
			inst.upgraded = upgraded
			var face := scene.instantiate() as CardFace3D
			face.setup(inst)
			get_root().add_child(face)
			faces.append([face, "%s%s" % [def.display_name, " (upgraded)" if upgraded else ""]])
	# One pass for the viewports to size themselves, one for the labels to wrap.
	for _i in 3:
		await process_frame

	var tallest := 0.0
	var worst := ""
	for entry in faces:
		var face: CardFace3D = entry[0]
		var front := face.get_node(^"FrontViewport/CardFront") as Control
		var margin := front.get_node(^"Margin") as Control
		var column := margin.get_node(^"Column") as Control
		var room: float = front.size.y \
			- margin.get_theme_constant("margin_top") - margin.get_theme_constant("margin_bottom")
		var need := column.get_combined_minimum_size().y
		if need > tallest:
			tallest = need
			worst = entry[1]
		_check("%s fits on its face (needs %d of %d px)" % [entry[1], int(need), int(room)],
			need <= room)
		face.queue_free()
	print("the tallest is %s, needing %d px" % [worst, int(tallest)])
	_report()

func _can_upgrade(def: CardDef) -> bool:
	if def is ProductCardDef:
		return (def as ProductCardDef).upgraded_margin > 0
	var s := def as SupportCardDef
	return s != null and (not s.upgraded_effects.is_empty() or s.upgraded_ticks >= 0)

func _report() -> void:
	print("")
	if _checks < EXPECTED_MIN:
		print("FAIL  only %d checks ran, expected at least %d - something aborted"
			% [_checks, EXPECTED_MIN])
		_failures.append("check count collapsed")
	if _failures.is_empty():
		print("%d checks, all passed" % _checks)
		quit(0)
	else:
		for f in _failures:
			print("FAIL  " + f)
		print("%d checks, %d FAILED" % [_checks, _failures.size()])
		quit(1)

func _check(label: String, ok: bool) -> void:
	_checks += 1
	if not ok:
		_failures.append(label)
