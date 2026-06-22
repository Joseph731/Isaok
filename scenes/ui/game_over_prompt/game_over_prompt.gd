extends Control
class_name GameOverPrompt

signal rematch_selected
signal quit_to_main_menu_selected

@onready var rematch_button: Button = $PanelContainer/VBoxContainer/HBoxContainer/RematchButton
@onready var quit_button: Button = $PanelContainer/VBoxContainer/HBoxContainer/QuitButton
@onready var background_button: Button = $BackgroundButton
@onready var label: Label = $PanelContainer/VBoxContainer/Label

var _is_for_server: bool = true
var is_for_server: bool:
	get:
		return _is_for_server
	set(value):
		_is_for_server = value
		_update_visibility()

func _ready() -> void:
	rematch_button.pressed.connect(_on_rematch_button_pressed)
	quit_button.pressed.connect(_on_quit_button_pressed)

func _on_rematch_button_pressed() -> void:
	rematch_selected.emit()

func _on_quit_button_pressed() -> void:
	quit_to_main_menu_selected.emit()

func _update_visibility() -> void:
	if multiplayer.is_server() && is_for_server:
		visible = true
	elif !multiplayer.is_server() && !is_for_server:
		visible = true
