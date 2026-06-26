extends Control

const GREED_MUSIC = preload("uid://3xefjdj83tsf")

@onready var single_player_button: Button = $VBoxContainer/SinglePlayerButton
@onready var multiplayer_button: Button = $VBoxContainer/MultiplayerButton
@onready var quit_button: Button = $VBoxContainer/QuitButton
@onready var options_button: Button = $VBoxContainer/OptionsButton

@onready var multiplayer_menu_scene: PackedScene = load("uid://cx4fmserm6kig")

var options_menu_scene: PackedScene = preload("uid://ckqrgh0lepopt")

func _ready() -> void:
	if MusicPlayer.stream != GREED_MUSIC:
		MusicPlayer.stream = GREED_MUSIC
	if !MusicPlayer.playing:
		MusicPlayer.play()
	
	single_player_button.pressed.connect(_on_single_player_button_pressed)
	multiplayer_button.pressed.connect(_on_multiplayer_button_pressed)
	quit_button.pressed.connect(_on_quit_button_pressed)
	options_button.pressed.connect(_on_options_pressed)
	
	UIAudioManager.register_buttons([
		single_player_button,
		multiplayer_button,
		quit_button,
		options_button
	])


func _on_single_player_button_pressed():
	pass

func _on_multiplayer_button_pressed():
	get_tree().change_scene_to_packed(multiplayer_menu_scene)
	

func _on_quit_button_pressed():
	get_tree().quit()


func _on_options_pressed():
	var options_menu := options_menu_scene.instantiate()
	add_child(options_menu)
