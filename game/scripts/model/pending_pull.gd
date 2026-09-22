class_name PendingPull extends RefCounted
## The reveal PullCards.apply() stages and Shift.choose_pull()/cancel_pull()
## resolve - a pause between two player commands, the same shape every other
## multi-step interaction in this game already takes (approach then offer,
## approach then close). Unlike those, nothing else can happen in between:
## the view locks dragging while this is set (see shift_controller.gd).
##
## revealed[i] came out of draw at original_indices[i] - parallel arrays, in
## ascending index order (the order they were found scanning down from the
## top), so Shift._return_pull() can restore each unchosen card to its own
## exact slot rather than just to the group's relative order.

var revealed: Array[CardInstance] = []
var original_indices: Array[int] = []
