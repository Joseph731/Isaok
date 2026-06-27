extends Control
class_name GameOverPrompt

enum GameOverOutcome{VICTORY, DEFEAT, TIE}

signal rematch_selected
signal quit_to_main_menu_selected

const BLUE_VICTORY = preload("uid://dky7llcj5ovfs")
const ISAAC_VICTORY = preload("uid://dcsaeijftlenj")
const BLUE_DEFEAT = preload("uid://18a4avt18grr")
const ISAAC_DEFEAT = preload("uid://djstctboekbmb")
const DRAW = preload("uid://bhyy7mnllq00h")

@onready var rematch_button: Button = $VBoxContainer/PanelContainer/VBoxContainer/HBoxContainer/RematchButton
@onready var quit_button: Button = $VBoxContainer/PanelContainer/VBoxContainer/HBoxContainer/QuitButton
@onready var background_button: Button = $BackgroundButton
@onready var label: Label = $VBoxContainer/PanelContainer/VBoxContainer/Label
@onready var texture_rect: TextureRect = $VBoxContainer/TextureRect

var _is_for_server: bool = true
var is_for_server: bool:
	get:
		return _is_for_server
	set(value):
		_is_for_server = value
		_update_visibility()

var _outcome_version: GameOverOutcome = GameOverOutcome.VICTORY
var outcome_version: GameOverOutcome:
	get:
		return _outcome_version
	set(value):
		_outcome_version = value
		change_version()

var is_black_version: bool = true

func _ready() -> void:
	rematch_button.pressed.connect(_on_rematch_button_pressed)
	quit_button.pressed.connect(_on_quit_button_pressed)
	
	UIAudioManager.register_buttons([
		rematch_button,
		quit_button
	])

func _on_rematch_button_pressed() -> void:
	rematch_selected.emit()

func _on_quit_button_pressed() -> void:
	quit_to_main_menu_selected.emit()

func _update_visibility() -> void:
	if multiplayer.is_server() && is_for_server:
		visible = true
	elif !multiplayer.is_server() && !is_for_server:
		visible = true

func change_version() -> void:
	if outcome_version == GameOverOutcome.VICTORY:
		label.text = "Victory"
		if is_black_version:
			texture_rect.texture = BLUE_VICTORY
		else:
			texture_rect.texture = ISAAC_VICTORY
	elif outcome_version == GameOverOutcome.DEFEAT:
		label.text = "Defeat"
		if is_black_version:
			texture_rect.texture = BLUE_DEFEAT
		else:
			texture_rect.texture = ISAAC_DEFEAT
	else:
		label.text = "Tie"
		texture_rect.texture = DRAW
