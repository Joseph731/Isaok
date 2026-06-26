extends Control
class_name StoneSelectionPrompt

signal stone_selected(stone_type: GridManager.StoneType, myself: StoneSelectionPrompt)

@onready var black_button: Button = $PanelContainer/VBoxContainer/HBoxContainer/BlackButton
@onready var white_button: Button = $PanelContainer/VBoxContainer/HBoxContainer/WhiteButton

var _is_for_server: bool = true
var is_for_server: bool:
	get:
		return _is_for_server
	set(value):
		_is_for_server = value
		_update_visibility()

func _ready() -> void:
	black_button.pressed.connect(_on_black_button_pressed)
	white_button.pressed.connect(_on_white_button_pressed)
	
	UIAudioManager.register_buttons([
		black_button,
		white_button
	])

func _on_black_button_pressed() -> void:
	stone_selected.emit(GridManager.StoneType.BLACK, self)

func _on_white_button_pressed() -> void:
	stone_selected.emit(GridManager.StoneType.WHITE, self)

func _update_visibility() -> void:
	if multiplayer.is_server() && is_for_server:
		visible = true
	elif !multiplayer.is_server() && !is_for_server:
		visible = true
