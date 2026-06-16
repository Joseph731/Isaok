extends Control
class_name StoneSelectionPrompt

signal stone_selected(stone_type: GridManager.StoneType)

@onready var black_button: Button = $PanelContainer/VBoxContainer/HBoxContainer/BlackButton
@onready var white_button: Button = $PanelContainer/VBoxContainer/HBoxContainer/WhiteButton

func _ready() -> void:
	black_button.pressed.connect(_on_black_button_pressed)
	white_button.pressed.connect(_on_white_button_pressed)

func _on_black_button_pressed() -> void:
	stone_selected.emit(GridManager.StoneType.BLACK)
	queue_free()

func _on_white_button_pressed() -> void:
	stone_selected.emit(GridManager.StoneType.WHITE)
	queue_free()
