extends PanelContainer

@onready var back_button: Button = $MarginContainer/BackButton
@onready var main_menu_scene: PackedScene = load("uid://cb0o2ptu41xif")

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	
	UIAudioManager.register_buttons([
		back_button
	])

func _on_back_pressed():
	get_tree().change_scene_to_packed(main_menu_scene)
