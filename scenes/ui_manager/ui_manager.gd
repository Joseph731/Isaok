extends Node
class_name UIManager

signal stone_selection_prompt_created(stone_selection_prompt: StoneSelectionPrompt)
signal fifth_moves_count_prompt_created(fifth_moves_count_prompt: FifthMovesCountPrompt)

@export var grid_manager: GridManager

@onready var stones: Node = $Stones
@onready var fifth_moves_count_label: Label = $MarginContainer/FifthMovesCountLabel

const STONE: PackedScene = preload("uid://dyrih8v8f0hie")
const STONE_SELECTION_PROMPT: PackedScene = preload("uid://dly5k3xygv7tn")
const FIFTH_MOVES_COUNT_PROMPT: PackedScene = preload("uid://cghnoly1psgtq")

var newest_stone: Stone

func _ready() -> void:
	grid_manager.stone_placed.connect(_on_stone_placed)
	grid_manager.third_move_finished.connect(_on_third_move_finished)
	grid_manager.fourth_move_finished.connect(_on_fourth_move_finished)
	if is_multiplayer_authority():
		create_stone_selection_prompt()

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

func _on_third_move_finished() -> void:
	if grid_manager.servers_stone == GridManager.StoneType.WHITE:
		create_stone_selection_prompt()
	else:
		create_stone_selection_prompt.rpc_id(multiplayer.get_peers()[0])

@rpc("authority", "call_local", "reliable")
func create_stone_selection_prompt() -> void:
	var stone_selection_prompt: StoneSelectionPrompt = STONE_SELECTION_PROMPT.instantiate()
	stone_selection_prompt_created.emit.call_deferred(stone_selection_prompt)
	add_child(stone_selection_prompt)

func _on_fourth_move_finished() -> void:
	if grid_manager.servers_stone == GridManager.StoneType.WHITE:
		create_fifth_moves_count_prompt()
	else:
		create_fifth_moves_count_prompt.rpc_id(multiplayer.get_peers()[0])

@rpc("authority", "call_local", "reliable")
func create_fifth_moves_count_prompt() -> void:
	var fifth_moves_count_prompt: FifthMovesCountPrompt = FIFTH_MOVES_COUNT_PROMPT.instantiate()
	fifth_moves_count_prompt_created.emit(fifth_moves_count_prompt)
	fifth_moves_count_prompt.fifth_moves_count_selected.connect(_on_fifth_moves_count_selected)
	add_child(fifth_moves_count_prompt)

func _on_fifth_moves_count_selected(moves_count: int) -> void:
	set_fifth_moves_count_text.rpc(moves_count)

@rpc("any_peer", "call_local", "reliable")
func set_fifth_moves_count_text(moves_count: int) -> void:
	fifth_moves_count_label.visible = true
	fifth_moves_count_label.text = "There will be " + str(moves_count) + " fifth moves."
