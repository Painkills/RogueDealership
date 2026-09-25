class_name ScreenTag extends PanelContainer
## A flat 2D hint pinned to a point on the 3D table.
##
## The table's hints used to be Label3D, which renders INTO the scene: shrunk
## by distance, drawn at whatever angle the card was at, and sorted against the
## very cards it was naming, so a growing discard pile could bury its own label.
## This draws on the HUD instead. It is always full size and always on top, and
## it follows its anchor wherever the carousel or a rising pile takes it.
##
## A tag hangs from its TOP-CENTRE. Every anchor is the top edge of the card it
## names (see build_shift_scene.gd's TagAnchor markers), and the tag sits
## drop_px inside that edge. That one rule is what "aligned with the top of the
## card, with some margin" means for every card at once, at any distance.

## Path from the scene root to the Marker3D this follows. The shift controller
## resolves it: the tag lives in the HUD's CanvasLayer and the anchor lives in
## the 3D tree, and the root is the one node that owns both.
@export var anchor_path: NodePath
## How far below the anchor the tag's top edge sits, in design pixels.
@export var drop_px: float = 14.0
## How much of the tag's width hangs to the LEFT of its anchor: 0.5 centres it
## on the anchor, 1.0 puts its right edge there. A corner tag (CLOSE SOON, on
## a folder's top-right corner) hangs from the corner rather than a midpoint,
## so it stays tucked into that corner at whatever size perspective draws the
## folder.
@export var hang: float = 0.5

var anchor: Node3D
## The caller's own condition, on top of the anchor's. The empty-table note's
## anchor is showing whenever the product slot is, product or no product, so
## only the controller knows when there is actually nothing on the table.
var wanted := true

## Put the tag where its anchor lands on screen this frame. An anchor that is
## hidden, behind the camera or off screen hides the tag: a pile stowed below
## the frame must not leave its label hanging off the bottom edge.
func follow(cam: Camera3D) -> void:
	var on := wanted and anchor != null and cam != null and anchor.is_visible_in_tree() \
		and not cam.is_position_behind(anchor.global_position)
	var p := Vector2.ZERO
	if on:
		p = cam.unproject_position(anchor.global_position)
		on = cam.get_viewport().get_visible_rect().has_point(p)
	visible = on
	if not on:
		return
	# Shrink-wrap first. A text change widens the tag, and centring on last
	# frame's width puts it off-centre by half the difference.
	reset_size()
	position = Vector2(roundf(p.x - size.x * hang), roundf(p.y + drop_px))
