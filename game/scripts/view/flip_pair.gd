class_name FlipPair extends Node3D
## Two stacked cards that turn over together, so they read as one card with a
## front and a back.
##
## The trick is that the pair is flipped, not the cards. The front card sits a
## hair towards the camera facing you; the detail card sits a hair away, turned
## through 180 degrees so it faces the other way. Rotating THIS node by 180
## degrees swaps which one is nearer and turns each to face the other way -
## which is exactly what happens when you turn a real card over.
##
## Doing it card-by-card cannot work: flipping each in place leaves the front
## card still in front, so all you would see is the back of the card you already
## had. The z-order has to come along, and that is what rotating the parent does.
##
## On the floor this is what a hover does - it replaced a HUD tooltip panel,
## which had to be positioned, kept out of the way of everything else, and kept
## from swallowing the click that summoned it.

## Shorter than the detail card's slide, and DetailCard3D.SLIDE_DELAY is set to
## outlast it, so a pair you flipped by hovering has finished turning back to
## face front before the detail card starts sliding out from behind it.
const FLIP_TWEEN := 0.3

var _tween: Tween
var _back := false

func show_back(want: bool) -> void:
	if _back == want:
		return
	_back = want
	if _tween != null and _tween.is_valid() and _tween.is_running():
		_tween.kill()
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_OUT)
	_tween.set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(self, "rotation:y", PI if want else 0.0, FLIP_TWEEN)

func showing_back() -> bool:
	return _back
