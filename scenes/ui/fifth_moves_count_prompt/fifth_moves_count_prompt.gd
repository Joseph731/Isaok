extends Control
class_name FifthMovesCountPrompt

signal fifth_moves_count_selected(moves_count: int, myself: FifthMovesCountPrompt)

@onready var one_button: Button = $PanelContainer/VBoxContainer/HBoxContainer/OneButton
@onready var two_button: Button = $PanelContainer/VBoxContainer/HBoxContainer/TwoButton
@onready var three_button: Button = $PanelContainer/VBoxContainer/HBoxContainer/ThreeButton
@onready var four_button: Button = $PanelContainer/VBoxContainer/HBoxContainer/FourButton
@onready var five_button: Button = $PanelContainer/VBoxContainer/HBoxContainer/FiveButton
@onready var six_button: Button = $PanelContainer/VBoxContainer/HBoxContainer/SixButton
@onready var seven_button: Button = $PanelContainer/VBoxContainer/HBoxContainer/SevenButton
@onready var eight_button: Button = $PanelContainer/VBoxContainer/HBoxContainer/EightButton

var _is_for_server: bool = true
var is_for_server: bool:
	get:
		return _is_for_server
	set(value):
		_is_for_server = value
		_update_visibility()

func _ready() -> void:
	one_button.pressed.connect(_on_one_button_pressed)
	two_button.pressed.connect(_on_two_button_pressed)
	three_button.pressed.connect(_on_three_button_pressed)
	four_button.pressed.connect(_on_four_button_pressed)
	five_button.pressed.connect(_on_five_button_pressed)
	six_button.pressed.connect(_on_six_button_pressed)
	seven_button.pressed.connect(_on_seven_button_pressed)
	eight_button.pressed.connect(_on_eight_button_pressed)
	
	UIAudioManager.register_buttons([
		one_button,
		two_button,
		three_button,
		four_button,
		five_button,
		six_button,
		seven_button,
		eight_button
	])

func _on_one_button_pressed() -> void:
	fifth_moves_count_selected.emit(1, self)

func _on_two_button_pressed() -> void:
	fifth_moves_count_selected.emit(2, self)

func _on_three_button_pressed() -> void:
	fifth_moves_count_selected.emit(3, self)

func _on_four_button_pressed() -> void:
	fifth_moves_count_selected.emit(4, self)

func _on_five_button_pressed() -> void:
	fifth_moves_count_selected.emit(5, self)

func _on_six_button_pressed() -> void:
	fifth_moves_count_selected.emit(6, self)

func _on_seven_button_pressed() -> void:
	fifth_moves_count_selected.emit(7, self)

func _on_eight_button_pressed() -> void:
	fifth_moves_count_selected.emit(8, self)

func _update_visibility() -> void:
	if multiplayer.is_server() && is_for_server:
		visible = true
	elif !multiplayer.is_server() && !is_for_server:
		visible = true
