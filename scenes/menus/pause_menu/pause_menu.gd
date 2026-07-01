class_name PauseMenu
extends CanvasLayer

signal quit_requested

@onready var resume_button: Button = %ResumeButton
@onready var quit_button: Button = %QuitButton
@onready var options_button: Button = %OptionsButton
@onready var pause_button: Button = $MarginContainer/VBoxContainer/PauseButton
@onready var rematch_button: Button = $MarginContainer/VBoxContainer/RematchButton
@onready var host_wins_label: Label = $MarginContainer/VBoxContainer2/HostWinsLabel
@onready var host_loses_label: Label = $MarginContainer/VBoxContainer2/HostLosesLabel
@onready var host_ties_label: Label = $MarginContainer/VBoxContainer2/HostTiesLabel
@onready var room_code_label: Label = $MarginContainer/RoomCodeLabel


var options_menu_scene: PackedScene = preload("uid://ckqrgh0lepopt")

func _ready():
	room_code_label.text += MultiplayerConfig.current_room
	if is_multiplayer_authority():
		room_code_label.visible = true
	
	update_host_stats_labels()
	
	resume_button.pressed.connect(_on_resume_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	options_button.pressed.connect(_on_options_pressed)
	pause_button.pressed.connect(_on_pause_button_pressed)
	rematch_button.pressed.connect(_on_rematch_button_pressed)
	
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

func pause() -> void:
	visible = !visible

func _on_resume_pressed() -> void:
	visible = false

func _on_quit_pressed() -> void:
	quit_requested.emit()

func _on_options_pressed() -> void:
	var options_menu := options_menu_scene.instantiate()
	add_child(options_menu)

func _on_pause_button_pressed() -> void:
	visible = false

func _on_rematch_button_pressed() -> void:
	visible = false

func update_host_stats_labels() -> void:
	host_wins_label.text = "Wins: " + str(HostStats.host_wins)
	host_loses_label.text = "Loses: " + str(HostStats.host_loses)
	host_ties_label.text = "Ties: " + str(HostStats.host_ties)
