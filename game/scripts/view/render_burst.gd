class_name RenderBurst extends Node
## Renders a card's SubViewports for a few frames after what is on them changes,
## then stops, so a card nobody is changing costs nothing to draw.
##
## A few frames rather than one (UPDATE_ONCE): a single render raced a card being
## made during play on the Web export and left it blank. A few frames in a row,
## counted from when the card is actually in the tree, cover that - and its
## labels settling their size - and then the texture keeps the last picture.
##
## Every card used to render every frame: thirty-odd 500 x 700 viewports, some
## fifteen megapixels a frame for pictures that had not changed - fine on a
## desktop, the whole frame budget on a phone.

## How many frames a change is rendered for.
const FRAMES := 6

var _viewports: Array[SubViewport] = []
var _left := 0

## Renders `viewports` - `host`'s own - for the next FRAMES frames, then stops.
## Call it whenever what is on them changes.
static func kick(host: Node, viewports: Array) -> void:
	var burst := host.get_node_or_null(^"RenderBurst") as RenderBurst
	if burst == null:
		burst = RenderBurst.new()
		burst.name = "RenderBurst"
		host.add_child(burst, false, Node.INTERNAL_MODE_BACK)
	burst._viewports.clear()
	for v in viewports:
		if v != null:
			burst._viewports.append(v)
			v.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	burst._left = FRAMES
	burst.set_process(true)

## Whether `host`'s viewports are still being rendered after a change.
static func busy(host: Node) -> bool:
	var burst := host.get_node_or_null(^"RenderBurst") as RenderBurst
	return burst != null and burst._left > 0

func _process(_delta: float) -> void:
	_left -= 1
	if _left > 0:
		return
	for v in _viewports:
		if is_instance_valid(v):
			v.render_target_update_mode = SubViewport.UPDATE_DISABLED
	set_process(false)
