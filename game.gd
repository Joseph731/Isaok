extends Node

@onready var grid_manager: GridManager = $GridManager
@onready var ui_manager: UIManager = $UIManager

func _ready() -> void:
	ui_manager.stone_selection_prompt_created.connect(_on_stone_selection_prompt_created)

func _on_stone_selection_prompt_created(stone_selection_prompt: StoneSelectionPrompt) -> void:
	stone_selection_prompt.stone_selected.connect(_on_stone_selection_prompt_stone_selected)

func _on_stone_selection_prompt_stone_selected(stone_type: GridManager.StoneType) -> void:
	grid_manager.set_peers_stone_types.rpc_id(1, stone_type)
