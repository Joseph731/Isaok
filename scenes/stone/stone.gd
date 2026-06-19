extends Sprite2D
class_name Stone

@export var texture_bank: Array[Texture2D]
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var texture_index: int = 0:
	set(value):
		texture_index = value
		_update_texture()

func _update_texture() -> void:
	if texture_index < 2:
		texture = texture_bank[texture_index]
	else:
		texture = texture_bank[0]
		if texture_index == 2:
			modulate = Color.GREEN
		else:
			modulate = Color.RED
