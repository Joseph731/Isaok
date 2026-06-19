extends Node

@onready var grid_manager: GridManager = $GridManager
@onready var ui_manager: UIManager = $UIManager

func _ready() -> void:
	ui_manager.stone_selection_prompt_created.connect(_on_stone_selection_prompt_created)
	ui_manager.fifth_moves_count_prompt_created.connect(_on_fifth_moves_count_prompt_created)

func _on_stone_selection_prompt_created(stone_selection_prompt: StoneSelectionPrompt) -> void:
	stone_selection_prompt.stone_selected.connect(_on_stone_selection_prompt_stone_selected)

func _on_stone_selection_prompt_stone_selected(stone_type: GridManager.StoneType) -> void:
	grid_manager.set_peers_stone_types.rpc_id(1, stone_type)

func _on_fifth_moves_count_prompt_created(fifth_moves_count_prompt: FifthMovesCountPrompt) -> void:
	fifth_moves_count_prompt.fifth_moves_count_selected.connect(_on_fifth_moves_count_prompt_count_selected)

func _on_fifth_moves_count_prompt_count_selected(moves_count: int) -> void:
	grid_manager.switch_whose_turn_it_is.rpc_id(1)
	grid_manager.set_fifth_moves_count.rpc_id(1, moves_count)
