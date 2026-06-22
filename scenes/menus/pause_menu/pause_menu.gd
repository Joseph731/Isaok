class_name PauseMenu
extends CanvasLayer

signal quit_requested

@onready var resume_button: Button = %ResumeButton
@onready var quit_button: Button = %QuitButton
@onready var options_button: Button = %OptionsButton
@onready var pause_button: Button = $MarginContainer/VBoxContainer/PauseButton
@onready var rematch_button: Button = $MarginContainer/VBoxContainer/RematchButton


var options_menu_scene: PackedScene = preload("uid://ckqrgh0lepopt")

func _ready():
	resume_button.pressed.connect(_on_resume_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	options_button.pressed.connect(_on_options_pressed)
	
	UIAudioManager.register_buttons([
		resume_button,
		quit_button,
		options_button,
		pause_button,
		rematch_button
	])


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		pause()
		get_viewport().set_input_as_handled()

func pause():
	visible = !visible

func _on_resume_pressed():
	visible = false

func _on_quit_pressed():
	quit_requested.emit()

func _on_options_pressed():
	var options_menu := options_menu_scene.instantiate()
	add_child(options_menu)
