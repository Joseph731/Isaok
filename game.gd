extends Node

@onready var ui_manager: UIManager = $UIManager
@onready var grid_manager: GridManager = $GridManager

func _ready() -> void:
	ui_manager.stone_selection_prompt_created.connect(_on_stone_selection_prompt_created)

func _on_stone_selection_prompt_created(stone_selection_prompt: StoneSelectionPrompt) -> void:
	stone_selection_prompt.stone_selected.connect(grid_manager._on_stone_selection_prompt_stone_selected)
