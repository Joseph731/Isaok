extends Node
class_name UIManager

signal stone_selection_prompt_created(stone_selection_prompt: StoneSelectionPrompt)

@export var grid_manager: GridManager

@onready var stones: Node = $Stones

const STONE: PackedScene = preload("uid://dyrih8v8f0hie")
const STONE_SELECTION_PROMPT: PackedScene = preload("uid://dly5k3xygv7tn")

var newest_stone: Stone

func _ready() -> void:
	grid_manager.stone_placed.connect(_on_stone_placed)
	
	if is_multiplayer_authority():
		var stone_selection_prompt: StoneSelectionPrompt = STONE_SELECTION_PROMPT.instantiate()
		add_child(stone_selection_prompt)
		stone_selection_prompt_created.emit.call_deferred(stone_selection_prompt)

func _on_stone_placed(cell: Button, stone_type: GridManager.StoneType) -> void:
	var stone: Stone = STONE.instantiate()
	stone.global_position = cell.global_position + cell.size / 2
	if stone_type == GridManager.StoneType.BLACK:
		stone.texture_index = 0
	else:
		stone.texture_index = 1
	stones.add_child(stone, true)
	
	if newest_stone != null:
		newest_stone.animation_player.play("RESET")
	newest_stone = stone
	newest_stone.animation_player.play("recently_placed")
