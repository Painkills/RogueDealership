class_name Category extends Resource
## One of the three thirds of the board. Categories exist so a read can hand
## you PARTIAL information: "they are a Vehicle person" narrows nine to three.

@export var id: StringName
@export var display_name: String
@export_multiline var blurb: String
