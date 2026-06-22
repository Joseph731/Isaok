extends Control
class_name PauseRequestPrompt

signal answered(answer_is_yes: bool, myself: PauseRequestPrompt)

@onready var label: Label = $PanelContainer/VBoxContainer/Label
@onready var yes_button: Button = $PanelContainer/VBoxContainer/HBoxContainer/YesButton
@onready var no_button: Button = $PanelContainer/VBoxContainer/HBoxContainer/NoButton

var _is_for_server: bool = true
var is_for_server: bool:
	get:
		return _is_for_server
	set(value):
		_is_for_server = value
		_update_visibility()

func _ready() -> void:
	yes_button.pressed.connect(_on_yes_button_pressed)
	no_button.pressed.connect(_on_no_button_pressed)

func _on_yes_button_pressed() -> void:
	answered.emit(true, self)

func _on_no_button_pressed() -> void:
	answered.emit(false, self)

func change_to_unpause_version() -> void:
	label.text = "Allow Unpause?"

func _update_visibility() -> void:
	if multiplayer.is_server() && is_for_server:
		visible = true
	elif !multiplayer.is_server() && !is_for_server:
		visible = true
