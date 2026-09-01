extends PanelContainer

signal pressed(chair_index: int)

var chair_index: int = -1

@onready var _name: Label = %NameLabel
@onready var _archetype: Label = %ArchetypeLabel
@onready var _patience_bar: ProgressBar = %PatienceBar
@onready var _patience_label: Label = %PatienceLabel
@onready var _unsigned: Label = %UnsignedLabel
@onready var _alert: Label = %AlertLabel
@onready var _clicker: Button = %Clicker
@onready var _hover: PanelContainer = %HoverPanel
@onready var _hover_body: Label = %HoverBody

func _ready() -> void:
	_clicker.pressed.connect(func(): pressed.emit(chair_index))
	_clicker.mouse_entered.connect(func(): _hover.visible = true)
	_clicker.mouse_exited.connect(func(): _hover.visible = false)
	_alert.add_theme_color_override("font_color", Palette.color(&"alert"))

func setup(customer, walk_up_remaining: int, index: int) -> void:
	chair_index = index
	if customer == null:
		_name.text = "--- empty ---"
		_archetype.text = "someone walks up in %d" % max(0, walk_up_remaining)
		_patience_bar.visible = false
		_patience_label.text = ""
		_unsigned.text = ""
		_alert.visible = false
		_hover_body.text = "Nothing. They just sit and listen."
		return

	_name.text = "[%s] %s" % [customer.key, customer.display_name]
	_archetype.text = customer.archetype.display_name
	_patience_bar.visible = true
	_patience_bar.max_value = customer.max_patience
	_patience_bar.value = customer.patience
	_patience_bar.modulate = Format.patience_color(customer.patience, customer.max_patience)
	_patience_label.text = "%d/%d" % [customer.patience, customer.max_patience]

	var unsigned: int = customer.unsigned_margin()
	_unsigned.text = "%s unsigned" % Format.money(unsigned) if unsigned > 0 else ""
	_unsigned.add_theme_color_override("font_color", Palette.color(&"margin"))

	_alert.visible = customer.leaving_soon()
	if _alert.visible:
		_alert.text = "! %d LEFT" % customer.patience

	var tells: Array[String] = []
	for act in customer.archetype.actions:
		tells.append("%s\n  %s" % [act.display_name, act.tell])
	_hover_body.text = "\n\n".join(tells) if not tells.is_empty() \
		else "Nothing. They just sit and listen."
