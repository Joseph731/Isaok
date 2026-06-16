extends Sprite2D
class_name Stone

@export var texture_bank: Array[Texture2D]
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var texture_index: int = 0:
	set(value):
		texture_index = value
		_update_texture()

func _update_texture() -> void:
	if texture_index >= 0 and texture_index < texture_bank.size():
		texture = texture_bank[texture_index]
